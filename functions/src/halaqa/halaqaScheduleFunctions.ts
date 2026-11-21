/**
 * P0-04 / D8 / D9 — Admin Halaqa creation and schedule-slot creation.
 *
 * Server final validation (UI checks are advisory only):
 * - D8: a production Halaqa is created with at least one Schedule Slot.
 * - D9: each slot carries a stable `slotId`; Sessions are materialized per
 *   slot by `materializeSession` (unchanged).
 * - Weekly hard conflicts (half-open, same weekday): same Halaqa, same
 *   Teacher, intersecting student rosters. Supervisor overlap is allowed.
 * - Concurrency: every create/add reads and writes
 *   `halaqaScheduleLocks/teacher_{teacherId}` in its transaction, so two
 *   concurrent schedules for one Teacher serialize and the second one sees
 *   the first.
 * - Slot times are Cairo wall-clock (`HH:mm`, 24h) like existing schedules;
 *   `materializeSession` converts them with the Cairo date contract.
 *
 * Halaqa membership stays with admitStudentToHalaqa / adminTransferStudent:
 * a new Halaqa always starts with an empty roster.
 */

import { randomUUID } from "node:crypto";

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  AUDIT_ACTION,
  AUDIT_LOGS_COLLECTION,
  AUDIT_TARGET_TYPE,
} from "../audit/auditLogContract";
import { adminActor, buildAuditLogEntry } from "../audit/auditLogWrite";
import {
  loadCallerRole,
  optionalText,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
import { appendRelationshipHistory, RELATIONSHIP_KIND } from "../relationships/relationshipHistory";
import { HALAQA_NAME_INDEX_COLLECTION, halaqaNameKey } from "./halaqaNameKey";
import { claimAcademyRefInTx, reserveAcademyRefInTx } from "../accounts/academyRefs";
import {
  HALAQA_MEETING_LINKS_COLLECTION,
  canonicalMeetingLinkData,
  optionalMeetingLink,
} from "./meetingLinkFunctions";
import {
  parseClockTime,
  weekdayFromSlotDayLabel,
} from "../sessions/sessionMaterialization";

export const HALAQA_SCHEDULE_LOCKS_COLLECTION = "halaqaScheduleLocks";
export const MAX_SLOTS_PER_HALAQA = 14;
export const MAX_HALAQA_NAME_LENGTH = 80;

/** Canonical Arabic day label per ISO weekday (Mon=1 … Sun=7). */
export const ARABIC_DAY_LABELS: Readonly<Record<number, string>> = Object.freeze({
  1: "الاثنين",
  2: "الثلاثاء",
  3: "الأربعاء",
  4: "الخميس",
  5: "الجمعة",
  6: "السبت",
  7: "الأحد",
});

export type WeeklySlot = {
  slotId: string;
  day: string;
  startTime: string;
  endTime: string;
};

type SlotWindow = { weekday: number; startMin: number; endMin: number };

export type WeeklyConflictReason =
  | "same_halaqa"
  | "same_teacher"
  | "student_roster_intersection";

export type WeeklyConflict = {
  reason: WeeklyConflictReason;
  conflictingHalaqaId: string;
  slot: string;
};

export type HalaqaScheduleSource = {
  id: string;
  teacherId: string;
  studentIds: string[];
  schedule: unknown;
};

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

/** Validates one client slot and returns its canonical stored form. */
export function parseSlotInput(raw: unknown): Omit<WeeklySlot, "slotId"> {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "موعد غير صالح");
  }
  const r = raw as Record<string, unknown>;
  const weekday = weekdayFromSlotDayLabel(text(r.day));
  if (weekday == null) {
    throw new HttpsError("invalid-argument", "يوم الموعد غير صالح");
  }
  const start = parseClockTime(text(r.startTime));
  const end = parseClockTime(text(r.endTime));
  if (!start || !end) {
    throw new HttpsError("invalid-argument", "وقت الموعد غير صالح");
  }
  const startMin = start.hour * 60 + start.minute;
  const endMin = end.hour * 60 + end.minute;
  if (endMin <= startMin) {
    throw new HttpsError("invalid-argument", "وقت نهاية الموعد يجب أن يكون بعد بدايته");
  }
  return {
    day: ARABIC_DAY_LABELS[weekday],
    startTime: `${pad2(start.hour)}:${pad2(start.minute)}`,
    endTime: `${pad2(end.hour)}:${pad2(end.minute)}`,
  };
}

/** Weekly window for a stored slot; null when the slot is unusable. */
export function slotWindow(raw: unknown): SlotWindow | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const weekday = weekdayFromSlotDayLabel(text(r.day));
  const start = parseClockTime(text(r.startTime));
  const end = parseClockTime(text(r.endTime));
  if (weekday == null || !start || !end) return null;
  const startMin = start.hour * 60 + start.minute;
  const endMin = end.hour * 60 + end.minute;
  if (endMin <= startMin) return null;
  return { weekday, startMin, endMin };
}

/** Same weekday and half-open overlap; adjacent slots do not conflict. */
export function weeklySlotsOverlap(a: SlotWindow, b: SlotWindow): boolean {
  return a.weekday === b.weekday && a.startMin < b.endMin && b.startMin < a.endMin;
}

function slotLabel(slot: { day: string; startTime: string; endTime: string }): string {
  return `${slot.day} ${slot.startTime}-${slot.endTime}`;
}

/**
 * Pure weekly conflict evaluation for [newSlots] added to Halaqa [halaqaId].
 * [existingSlots] are the Halaqa's current slots (empty on create).
 */
export function evaluateWeeklyConflicts(params: {
  halaqaId: string;
  teacherId: string;
  studentIds: readonly string[];
  existingSlots: readonly unknown[];
  newSlots: readonly Omit<WeeklySlot, "slotId">[];
  otherHalaqat: readonly HalaqaScheduleSource[];
}): WeeklyConflict[] {
  const conflicts: WeeklyConflict[] = [];
  const roster = new Set(params.studentIds);
  const accepted: SlotWindow[] = [];
  for (const raw of params.existingSlots) {
    const w = slotWindow(raw);
    if (w) accepted.push(w);
  }

  for (const slot of params.newSlots) {
    const window = slotWindow(slot);
    if (!window) continue;
    const label = slotLabel(slot);
    if (accepted.some((w) => weeklySlotsOverlap(w, window))) {
      conflicts.push({ reason: "same_halaqa", conflictingHalaqaId: params.halaqaId, slot: label });
    }
    accepted.push(window);

    for (const other of params.otherHalaqat) {
      if (other.id === params.halaqaId) continue;
      const otherSlots = Array.isArray(other.schedule) ? other.schedule : [];
      const overlaps = otherSlots.some((raw) => {
        const w = slotWindow(raw);
        return w != null && weeklySlotsOverlap(w, window);
      });
      if (!overlaps) continue;
      if (other.teacherId === params.teacherId) {
        conflicts.push({ reason: "same_teacher", conflictingHalaqaId: other.id, slot: label });
      }
      if (other.studentIds.some((id) => roster.has(id))) {
        conflicts.push({
          reason: "student_roster_intersection",
          conflictingHalaqaId: other.id,
          slot: label,
        });
      }
    }
  }
  return conflicts;
}

const CONFLICT_MESSAGES: Record<WeeklyConflictReason, string> = {
  same_halaqa: "يتداخل الموعد مع موعد آخر في نفس الحلقة",
  same_teacher: "يتداخل الموعد مع حلقة أخرى لنفس المعلم",
  student_roster_intersection: "يتداخل الموعد مع حلقة أخرى لطلاب من هذه الحلقة",
};

function throwOnConflicts(conflicts: WeeklyConflict[]): void {
  if (conflicts.length === 0) return;
  const top = conflicts[0];
  throw new HttpsError(
    "failed-precondition",
    `${CONFLICT_MESSAGES[top.reason]} (${top.slot})`,
    { code: "schedule_conflict", conflicts },
  );
}

async function requireAdmin(db: admin.firestore.Firestore, uid: string): Promise<void> {
  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "إدارة الحلقات والمواعيد متاحة للمسؤول فقط");
  }
}

function parseRoster(data: admin.firestore.DocumentData | undefined): string[] {
  return [...new Set(stringList(data?.studentIds))];
}

function sourceFromDoc(doc: admin.firestore.DocumentSnapshot): HalaqaScheduleSource {
  const d = doc.data() ?? {};
  return {
    id: doc.id,
    teacherId: text(d.teacherId),
    studentIds: parseRoster(d),
    schedule: d.schedule,
  };
}

export async function loadOtherHalaqat(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  teacherId: string,
  studentIds: readonly string[],
): Promise<HalaqaScheduleSource[]> {
  const byId = new Map<string, HalaqaScheduleSource>();
  const teacherSnap = await tx.get(
    db.collection("halaqat").where("teacherId", "==", teacherId),
  );
  for (const doc of teacherSnap.docs) byId.set(doc.id, sourceFromDoc(doc));
  for (let i = 0; i < studentIds.length; i += 30) {
    const chunk = studentIds.slice(i, i + 30);
    const snap = await tx.get(
      db.collection("halaqat").where("studentIds", "array-contains-any", chunk),
    );
    for (const doc of snap.docs) byId.set(doc.id, sourceFromDoc(doc));
  }
  return [...byId.values()];
}

const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;
export const HALAQA_DUPLICATE_NAME_MESSAGE =
  "يوجد حلقة بنفس الاسم بالفعل. اختر اسماً مختلفاً.";

export type CreateHalaqaResult = {
  halaqaId: string;
  slotIds: string[];
  alreadyExisted: boolean;
  academyRef: string;
};

/**
 * Creates an active Halaqa with ≥1 slot. `requestId` (optional, client
 * generated once per form) makes retries idempotent: it becomes the Halaqa id.
 *
 * The Halaqa receives the next free H-code in the same transaction, so a
 * failed or replayed request consumes no code. Bulk import passes the
 * roster's code in [options.academyRef] (server-side only, never from the
 * client payload) and keeps its own ledger entry for it.
 */
export async function adminCreateHalaqaCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
  generateId: () => string = () => randomUUID(),
  options: { academyRef?: string } = {},
): Promise<CreateHalaqaResult> {
  const uid = requireCallerUid(callerUid);
  const name = requireText(data.name, "name", MAX_HALAQA_NAME_LENGTH);
  const teacherId = requireText(data.teacherId, "teacherId");
  const supervisorId = optionalText(data.supervisorId, 128);
  const halaqaTextViolation = contactInfoViolation(name);
  if (halaqaTextViolation) {
    throw new HttpsError("invalid-argument", halaqaTextViolation);
  }
  const meetingLink = optionalMeetingLink(data.meetingLink);
  const requestId = optionalText(data.requestId, 64);
  if (requestId && !REQUEST_ID_PATTERN.test(requestId)) {
    throw new HttpsError("invalid-argument", "requestId غير صالح");
  }
  if (!Array.isArray(data.schedule) || data.schedule.length === 0) {
    throw new HttpsError("invalid-argument", "يجب إضافة موعد واحد على الأقل للحلقة (D8)");
  }
  if (data.schedule.length > MAX_SLOTS_PER_HALAQA) {
    throw new HttpsError("invalid-argument", "عدد المواعيد أكبر من المسموح");
  }
  const parsedSlots = data.schedule.map(parseSlotInput);
  await requireAdmin(db, uid);

  const nameKey = halaqaNameKey(name);
  if (nameKey === "") {
    throw new HttpsError("invalid-argument", "اسم الحلقة غير صالح");
  }
  const halaqaRef = requestId
    ? db.collection("halaqat").doc(requestId)
    : db.collection("halaqat").doc();
  const nameLockRef = db.collection(HALAQA_NAME_INDEX_COLLECTION).doc(nameKey);
  // Halaqat created before the name index existed have no lock document.
  const legacy = await db.collection("halaqat").select("name").get();
  if (legacy.docs.some((d) => d.id !== halaqaRef.id && halaqaNameKey(d.data()?.name) === nameKey)) {
    throw new HttpsError("already-exists", HALAQA_DUPLICATE_NAME_MESSAGE);
  }
  const lockRef = db
    .collection(HALAQA_SCHEDULE_LOCKS_COLLECTION)
    .doc(`teacher_${teacherId}`);
  const teacherUserRef = db.collection("users").doc(teacherId);
  const supervisorUserRef = supervisorId
    ? db.collection("users").doc(supervisorId)
    : null;

  return db.runTransaction(async (tx) => {
    await tx.get(lockRef);
    const existing = await tx.get(halaqaRef);
    if (existing.exists) {
      const d = existing.data() ?? {};
      if (requestId && text(d.createdBy) === uid) {
        const ids = (Array.isArray(d.schedule) ? d.schedule : [])
          .map((s: Record<string, unknown>) => text(s?.slotId))
          .filter((id: string) => id !== "");
        return {
          halaqaId: halaqaRef.id,
          slotIds: ids,
          alreadyExisted: true,
          academyRef: text(d.academyRef),
        };
      }
      throw new HttpsError("already-exists", "الحلقة موجودة مسبقاً");
    }
    const nameLock = await tx.get(nameLockRef);
    if (nameLock.exists && text(nameLock.data()?.halaqaId) !== halaqaRef.id) {
      throw new HttpsError("already-exists", HALAQA_DUPLICATE_NAME_MESSAGE);
    }

    const teacherUser = await tx.get(teacherUserRef);
    const teacherData = teacherUser.data();
    // Provisional teachers: isActive=false + pendingHalaqaAssignment=true +
    // empty staffStatus. Explicitly deactivated/archived/deleted staff must
    // not auto-reactivate via halaqa create even if a client forged pending.
    const staffStatus = text(teacherData?.staffStatus);
    if (
      !teacherUser.exists ||
      teacherData?.role !== "teacher" ||
      staffStatus === "deleted" ||
      staffStatus === "deactivated" ||
      staffStatus === "archived" ||
      (teacherData?.isActive === false && teacherData?.pendingHalaqaAssignment !== true)
    ) {
      throw new HttpsError("failed-precondition", "المعلم المحدد غير صالح أو غير متاح للإسناد");
    }
    if (supervisorUserRef) {
      const sup = await tx.get(supervisorUserRef);
      if (!sup.exists || sup.data()?.role !== "supervisor") {
        throw new HttpsError("failed-precondition", "المشرف المحدد غير صالح");
      }
    }

    const others = await loadOtherHalaqat(db, tx, teacherId, []);
    throwOnConflicts(
      evaluateWeeklyConflicts({
        halaqaId: halaqaRef.id,
        teacherId,
        studentIds: [],
        existingSlots: [],
        newSlots: parsedSlots,
        otherHalaqat: others,
      }),
    );

    const reservation = options.academyRef
      ? null
      : await reserveAcademyRefInTx(db, tx, "halaqa");
    const academyRef = options.academyRef ?? reservation!.ref;
    if (reservation) claimAcademyRefInTx(db, tx, reservation, { id: halaqaRef.id, name });

    const schedule: WeeklySlot[] = parsedSlots.map((s) => ({ ...s, slotId: generateId() }));
    tx.set(nameLockRef, {
      halaqaId: halaqaRef.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.create(halaqaRef, {
      name,
      nameKey,
      teacherId,
      supervisorId: supervisorId || "",
      studentIds: [],
      schedule,
      status: "active",
      academyRef,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (teacherData?.pendingHalaqaAssignment === true) {
      tx.update(teacherUserRef, {
        isActive: true,
        pendingHalaqaAssignment: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    const linkRef = db.collection(HALAQA_MEETING_LINKS_COLLECTION).doc(halaqaRef.id);
    if (meetingLink) {
      tx.set(linkRef, canonicalMeetingLinkData(meetingLink));
    } else {
      tx.delete(linkRef);
    }
    tx.set(
      db.collection("teacherProfiles").doc(teacherId),
      { halaqatIds: FieldValue.arrayUnion(halaqaRef.id) },
      { merge: true },
    );
    tx.set(lockRef, {
      teacherId,
      lastHalaqaId: halaqaRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: adminActor(uid),
          action: AUDIT_ACTION.halaqaCreate,
          targetType: AUDIT_TARGET_TYPE.halaqa,
          targetId: halaqaRef.id,
          metadata: {
            halaqaId: halaqaRef.id,
            teacherId,
            ...(supervisorId ? { supervisorId } : {}),
            slotCount: schedule.length,
            academyRef,
          },
          source: "adminCreateHalaqa",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    appendRelationshipHistory(db, tx, {
      kind: RELATIONSHIP_KIND.halaqaTeacher,
      operation: "create",
      actorId: uid,
      actorRole: "admin",
      halaqaId: halaqaRef.id,
      staffId: teacherId,
    });
    if (supervisorId) {
      appendRelationshipHistory(db, tx, {
        kind: RELATIONSHIP_KIND.halaqaSupervisor,
        operation: "create",
        actorId: uid,
        actorRole: "admin",
        halaqaId: halaqaRef.id,
        staffId: supervisorId,
      });
    }
    return {
      halaqaId: halaqaRef.id,
      slotIds: schedule.map((s) => s.slotId),
      alreadyExisted: false,
      academyRef,
    };
  });
}

export type AddSlotResult = { halaqaId: string; slotId: string };

/** Appends one slot to an existing Halaqa after the same conflict checks. */
export async function adminAddHalaqaSlotCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
  generateId: () => string = () => randomUUID(),
): Promise<AddSlotResult> {
  const uid = requireCallerUid(callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId");
  const slot = parseSlotInput(data.slot);
  await requireAdmin(db, uid);

  const halaqaRef = db.collection("halaqat").doc(halaqaId);
  const preSnap = await halaqaRef.get();
  if (!preSnap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
  const teacherId = text(preSnap.data()?.teacherId);
  if (!teacherId) throw new HttpsError("failed-precondition", "الحلقة بلا معلّم");
  const lockRef = db
    .collection(HALAQA_SCHEDULE_LOCKS_COLLECTION)
    .doc(`teacher_${teacherId}`);

  return db.runTransaction(async (tx) => {
    await tx.get(lockRef);
    const snap = await tx.get(halaqaRef);
    if (!snap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
    const d = snap.data() ?? {};
    if (text(d.teacherId) !== teacherId) {
      throw new HttpsError("aborted", "تغيّر معلّم الحلقة، أعد المحاولة");
    }
    const existingSlots = Array.isArray(d.schedule) ? d.schedule : [];
    if (existingSlots.length >= MAX_SLOTS_PER_HALAQA) {
      throw new HttpsError("failed-precondition", "عدد المواعيد أكبر من المسموح");
    }
    const roster = parseRoster(d);
    const others = await loadOtherHalaqat(db, tx, teacherId, roster);
    throwOnConflicts(
      evaluateWeeklyConflicts({
        halaqaId,
        teacherId,
        studentIds: roster,
        existingSlots,
        newSlots: [slot],
        otherHalaqat: others,
      }),
    );

    const slotId = generateId();
    tx.update(halaqaRef, {
      schedule: [...existingSlots, { ...slot, slotId }],
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(lockRef, {
      teacherId,
      lastHalaqaId: halaqaId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: adminActor(uid),
          action: AUDIT_ACTION.halaqaScheduleChange,
          targetType: AUDIT_TARGET_TYPE.halaqa,
          targetId: halaqaId,
          metadata: { halaqaId, slotId, operation: "add_slot" },
          source: "adminAddHalaqaSlot",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    return { halaqaId, slotId };
  });
}

export const adminCreateHalaqa = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("adminCreateHalaqa");
    return adminCreateHalaqaCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

export const adminAddHalaqaSlot = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("adminAddHalaqaSlot");
    return adminAddHalaqaSlotCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
