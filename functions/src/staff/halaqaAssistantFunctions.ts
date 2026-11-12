/**
 * Assistant teachers and temporary cover for a halaqa.
 *
 * Three distinct relationships, never conflated:
 *   - primary teacher   → `halaqat.teacherId` (unchanged by anything here);
 *   - assistant teacher → `halaqat.assistantTeacherIds` (standing assignment,
 *     read-only access to the halaqa; no teaching authority on its own);
 *   - temporary cover   → `halaqat.coverTeacherId` + `coverId`, backed by a
 *     `halaqaCoverPeriods/{coverId}` record (active → completed). While a
 *     cover is active, the cover person may record attendance and live
 *     evaluations for that halaqa only; sessions keep the primary teacher and
 *     are stamped with who actually handled them.
 *
 * A cover is either an assistant already assigned to the halaqa or another
 * active teacher. Only Admin changes any of this; every change is
 * transactional, audited and appended to the relationship history. Cover
 * periods are completed, never deleted.
 */

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
import {
  evaluateWeeklyConflicts,
  loadOtherHalaqat,
} from "../halaqa/halaqaScheduleFunctions";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
import {
  appendRelationshipHistory,
  RELATIONSHIP_KIND,
} from "../relationships/relationshipHistory";

export const ASSISTANT_TEACHER_ROLE = "assistant_teacher";
export const HALAQA_COVER_PERIODS_COLLECTION = "halaqaCoverPeriods";
/** Academy policy default; see the owner decisions in the report. */
export const MAX_ASSISTANTS_PER_HALAQA = 3;

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * True when [uid] is the active temporary cover of [halaqa]. The role must
 * still be a teaching role: a deactivated account has no role at all.
 */
export function isActiveCoverOf(
  halaqa: Record<string, unknown> | undefined,
  uid: string,
  role: string,
): boolean {
  if (!uid) return false;
  if (role !== "teacher" && role !== ASSISTANT_TEACHER_ROLE) return false;
  return text(halaqa?.coverTeacherId) === uid && text(halaqa?.coverId) !== "";
}

function isOpen(halaqa: Record<string, unknown> | undefined): boolean {
  const status = text(halaqa?.status);
  return status !== "archived" && status !== "closed";
}

function isActiveAccount(user: Record<string, unknown> | undefined): boolean {
  if (!user) return false;
  if (user.isActive === false) return false;
  const staffStatus = text(user.staffStatus);
  return staffStatus === "" || staffStatus === "active";
}

async function requireAdmin(db: admin.firestore.Firestore, callerUid: string | undefined) {
  const uid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "إدارة إسناد الحلقات متاحة للمسؤول فقط");
  }
  return uid;
}

function audit(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  adminUid: string,
  action: string,
  halaqaId: string,
  metadata: Record<string, unknown>,
  source: string,
) {
  tx.set(
    db.collection(AUDIT_LOGS_COLLECTION).doc(),
    buildAuditLogEntry(
      {
        actor: adminActor(adminUid),
        action,
        targetType: AUDIT_TARGET_TYPE.halaqa,
        targetId: halaqaId,
        metadata: { halaqaId, ...metadata },
        source,
      },
      FieldValue.serverTimestamp(),
    ),
  );
}

export type AssistantResult = {
  halaqaId: string;
  assistantId: string;
  operation: "assign" | "unassign";
  changed: boolean;
  assistantTeacherIds: string[];
};

export async function adminSetHalaqaAssistantCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<AssistantResult> {
  const adminUid = await requireAdmin(db, callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId", 128);
  const assistantId = requireText(data.assistantId, "assistantId", 128);
  const operation = data.operation === "unassign" ? "unassign" : data.operation === "assign" ? "assign" : null;
  if (!operation) throw new HttpsError("invalid-argument", "نوع العملية غير صالح");
  const halaqaRef = db.collection("halaqat").doc(halaqaId);
  const userRef = db.collection("users").doc(assistantId);

  return db.runTransaction(async (tx) => {
    const [halaqaSnap, userSnap] = await tx.getAll(halaqaRef, userRef);
    if (!halaqaSnap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
    const halaqa = halaqaSnap.data() ?? {};
    const current = stringList(halaqa.assistantTeacherIds);
    const has = current.includes(assistantId);
    const base = { halaqaId, assistantId, operation } as const;

    if (operation === "assign") {
      if (!isOpen(halaqa)) throw new HttpsError("failed-precondition", "الحلقة غير نشطة");
      if (!userSnap.exists || userSnap.get("role") !== ASSISTANT_TEACHER_ROLE) {
        throw new HttpsError("failed-precondition", "الحساب المحدد ليس مساعد مدرس");
      }
      if (!isActiveAccount(userSnap.data())) {
        throw new HttpsError("failed-precondition", "لا يمكن الإسناد إلى حساب غير نشط");
      }
      if (has) return { ...base, changed: false, assistantTeacherIds: current };
      if (current.length >= MAX_ASSISTANTS_PER_HALAQA) {
        throw new HttpsError(
          "failed-precondition",
          `الحد الأقصى ${MAX_ASSISTANTS_PER_HALAQA} مساعدين لكل حلقة`,
        );
      }
    } else {
      if (!has) return { ...base, changed: false, assistantTeacherIds: current };
      if (text(halaqa.coverTeacherId) === assistantId) {
        throw new HttpsError(
          "failed-precondition",
          "المساعد يغطي الحلقة حالياً؛ أنهِ التغطية المؤقتة أولاً",
        );
      }
    }

    const next = operation === "assign"
      ? [...current, assistantId]
      : current.filter((id) => id !== assistantId);
    tx.update(halaqaRef, {
      assistantTeacherIds: next,
      updatedAt: FieldValue.serverTimestamp(),
    });
    audit(db, tx, adminUid, AUDIT_ACTION.halaqaAssistantChange, halaqaId, {
      assistantId,
      operation,
    }, "adminSetHalaqaAssistant");
    appendRelationshipHistory(db, tx, {
      kind: RELATIONSHIP_KIND.halaqaAssistant,
      operation,
      actorId: adminUid,
      actorRole: "admin",
      halaqaId,
      staffId: assistantId,
    });
    return { ...base, changed: true, assistantTeacherIds: next };
  });
}

export type CoverResult = {
  halaqaId: string;
  coverId: string;
  coverTeacherId: string;
  status: "active" | "completed";
  changed: boolean;
};

const MAX_REASON_LENGTH = 200;

export async function adminStartHalaqaCoverCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<CoverResult> {
  const adminUid = await requireAdmin(db, callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId", 128);
  const coverTeacherId = requireText(data.coverTeacherId, "coverTeacherId", 128);
  const reason = optionalText(data.reason, MAX_REASON_LENGTH);
  const violation = contactInfoViolation(reason);
  if (violation) throw new HttpsError("invalid-argument", violation);
  const halaqaRef = db.collection("halaqat").doc(halaqaId);
  const userRef = db.collection("users").doc(coverTeacherId);

  return db.runTransaction(async (tx) => {
    const [halaqaSnap, userSnap] = await tx.getAll(halaqaRef, userRef);
    if (!halaqaSnap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
    const halaqa = halaqaSnap.data() ?? {};
    if (!isOpen(halaqa)) throw new HttpsError("failed-precondition", "الحلقة غير نشطة");
    const activeCoverId = text(halaqa.coverId);
    if (activeCoverId) {
      if (text(halaqa.coverTeacherId) === coverTeacherId) {
        return { halaqaId, coverId: activeCoverId, coverTeacherId, status: "active", changed: false };
      }
      throw new HttpsError(
        "failed-precondition",
        "توجد تغطية مؤقتة نشطة لهذه الحلقة؛ أنهِها قبل بدء تغطية أخرى",
      );
    }
    if (coverTeacherId === text(halaqa.teacherId)) {
      throw new HttpsError("failed-precondition", "هذا هو المعلم الأساسي للحلقة");
    }
    if (!userSnap.exists || !isActiveAccount(userSnap.data())) {
      throw new HttpsError("failed-precondition", "الحساب المحدد غير نشط");
    }
    const coverRole = text(userSnap.get("role"));
    if (coverRole === ASSISTANT_TEACHER_ROLE) {
      if (!stringList(halaqa.assistantTeacherIds).includes(coverTeacherId)) {
        throw new HttpsError(
          "failed-precondition",
          "عيّن المساعد على هذه الحلقة أولاً قبل تفعيله كبديل",
        );
      }
    } else if (coverRole === "teacher") {
      const schedule = (Array.isArray(halaqa.schedule) ? (halaqa.schedule as unknown[]) : [])
        .filter((s): s is Record<string, unknown> => typeof s === "object" && s !== null)
        .map((s) => ({
          day: text(s.day),
          startTime: text(s.startTime),
          endTime: text(s.endTime),
        }));
      const others = await loadOtherHalaqat(db, tx, coverTeacherId, []);
      const clash = evaluateWeeklyConflicts({
        halaqaId,
        teacherId: coverTeacherId,
        studentIds: [],
        existingSlots: [],
        newSlots: schedule,
        otherHalaqat: others,
      }).find((c) => c.reason === "same_teacher");
      if (clash) {
        throw new HttpsError(
          "failed-precondition",
          `يتداخل موعد الحلقة مع حلقة أخرى لهذا المعلم (${clash.slot})`,
          { code: "schedule_conflict", conflicts: [clash] },
        );
      }
    } else {
      throw new HttpsError("failed-precondition", "البديل يجب أن يكون معلماً أو مساعد مدرس");
    }

    const coverRef = db.collection(HALAQA_COVER_PERIODS_COLLECTION).doc();
    tx.set(coverRef, {
      halaqaId,
      coverTeacherId,
      coverRole,
      primaryTeacherId: text(halaqa.teacherId),
      status: "active",
      ...(reason ? { reason } : {}),
      startedAt: FieldValue.serverTimestamp(),
      startedBy: adminUid,
    });
    tx.update(halaqaRef, {
      coverTeacherId,
      coverId: coverRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
    audit(db, tx, adminUid, AUDIT_ACTION.halaqaCoverStart, halaqaId, {
      coverId: coverRef.id,
      teacherId: coverTeacherId,
      role: coverRole,
    }, "adminStartHalaqaCover");
    appendRelationshipHistory(db, tx, {
      kind: RELATIONSHIP_KIND.halaqaCover,
      operation: "start",
      actorId: adminUid,
      actorRole: "admin",
      halaqaId,
      staffId: coverTeacherId,
      previousStaffId: text(halaqa.teacherId),
      coverId: coverRef.id,
      reason,
    });
    return { halaqaId, coverId: coverRef.id, coverTeacherId, status: "active", changed: true };
  });
}

/** Returns the halaqa to its primary teacher; the cover period is kept. */
export async function adminEndHalaqaCoverCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<CoverResult> {
  const adminUid = await requireAdmin(db, callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId", 128);
  const expectedCoverId = text(data.coverId);
  const halaqaRef = db.collection("halaqat").doc(halaqaId);

  return db.runTransaction(async (tx) => {
    const halaqaSnap = await tx.get(halaqaRef);
    if (!halaqaSnap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
    const coverId = text(halaqaSnap.get("coverId"));
    const coverTeacherId = text(halaqaSnap.get("coverTeacherId"));
    if (!coverId) {
      return { halaqaId, coverId: expectedCoverId, coverTeacherId: "", status: "completed", changed: false };
    }
    if (expectedCoverId && expectedCoverId !== coverId) {
      throw new HttpsError("aborted", "تغيّرت التغطية المؤقتة، أعد تحميل الصفحة");
    }
    const coverRef = db.collection(HALAQA_COVER_PERIODS_COLLECTION).doc(coverId);
    const cover = await tx.get(coverRef);
    if (cover.exists) {
      tx.update(coverRef, {
        status: "completed",
        endedAt: FieldValue.serverTimestamp(),
        endedBy: adminUid,
      });
    }
    tx.update(halaqaRef, {
      coverTeacherId: "",
      coverId: "",
      updatedAt: FieldValue.serverTimestamp(),
    });
    audit(db, tx, adminUid, AUDIT_ACTION.halaqaCoverEnd, halaqaId, {
      coverId,
      teacherId: coverTeacherId,
    }, "adminEndHalaqaCover");
    appendRelationshipHistory(db, tx, {
      kind: RELATIONSHIP_KIND.halaqaCover,
      operation: "end",
      actorId: adminUid,
      actorRole: "admin",
      halaqaId,
      staffId: coverTeacherId,
      coverId,
    });
    return { halaqaId, coverId, coverTeacherId, status: "completed", changed: true };
  });
}

export const adminSetHalaqaAssistant = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminSetHalaqaAssistant");
  return adminSetHalaqaAssistantCore(
    admin.firestore(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});

export const adminStartHalaqaCover = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminStartHalaqaCover");
  return adminStartHalaqaCoverCore(
    admin.firestore(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});

export const adminEndHalaqaCover = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminEndHalaqaCover");
  return adminEndHalaqaCoverCore(
    admin.firestore(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});
