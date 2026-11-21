/**
 * Admin staff lifecycle (teachers and supervisors) and halaqa staff
 * reassignment.
 *
 * Status dimensions:
 *   login           → `users.isActive` (+ Firebase Auth `disabled`)
 *   staff lifecycle → `users.staffStatus`: active → deactivated → archived
 *                     → deleted. Reactivation is allowed from deactivated
 *                     and archived; deletion is final.
 *
 * Deactivate, archive and delete are distinct steps; each needs the previous
 * one. None of them may leave a halaqa pointing at the member: every active
 * halaqa must be reassigned first (`adminReassignHalaqaStaff`), and the
 * status transaction re-reads the halaqa assignments so a concurrent
 * reassignment to this member cannot slip through.
 *
 * Deletion removes the sign-in account and private contact data but keeps
 * `users/{uid}` as a named tombstone so historical sessions, evaluations and
 * audit entries still resolve to a person.
 */

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { LOGIN_USERNAMES_COLLECTION } from "../accounts/academyCredentials";
import {
  AUDIT_ACTION,
  AUDIT_LOGS_COLLECTION,
  AUDIT_TARGET_TYPE,
} from "../audit/auditLogContract";
import { adminActor, buildAuditLogEntry } from "../audit/auditLogWrite";
import { loadCallerRole, requireCallerUid, requireText } from "../authority/callerContext";
import {
  evaluateWeeklyConflicts,
  HALAQA_SCHEDULE_LOCKS_COLLECTION,
  loadOtherHalaqat,
} from "../halaqa/halaqaScheduleFunctions";
import { assertBackendAllowed } from "../productionGate";
import { appendRelationshipHistory, RELATIONSHIP_KIND } from "../relationships/relationshipHistory";
import { ASSISTANT_TEACHER_ROLE } from "./halaqaAssistantFunctions";

export const STAFF_ROLES = ["teacher", "supervisor"] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];

export const STAFF_STATUS = {
  active: "active",
  deactivated: "deactivated",
  archived: "archived",
  deleted: "deleted",
} as const;
export type StaffStatus = (typeof STAFF_STATUS)[keyof typeof STAFF_STATUS];

export type StaffAction = "deactivate" | "reactivate" | "archive" | "delete";

const ACTION_TARGET: Record<StaffAction, StaffStatus> = {
  deactivate: STAFF_STATUS.deactivated,
  reactivate: STAFF_STATUS.active,
  archive: STAFF_STATUS.archived,
  delete: STAFF_STATUS.deleted,
};

const ALLOWED_FROM: Record<StaffAction, readonly StaffStatus[]> = {
  deactivate: [STAFF_STATUS.active],
  reactivate: [STAFF_STATUS.deactivated, STAFF_STATUS.archived],
  archive: [STAFF_STATUS.deactivated],
  delete: [STAFF_STATUS.archived],
};

const TRANSITION_MESSAGES: Record<StaffAction, string> = {
  deactivate: "الحساب غير نشط بالفعل",
  reactivate: "لا يمكن إعادة تفعيل هذا الحساب",
  archive: "عطّل الحساب أولاً قبل أرشفته",
  delete: "أرشف الحساب أولاً قبل حذفه نهائياً",
};

export const STAFF_HAS_HALAQAT_CODE = "staff_has_halaqat";
const MAX_REASSIGNED_SESSIONS = 400;

export type StaffAuthApi = Pick<
  admin.auth.Auth,
  "updateUser" | "deleteUser" | "revokeRefreshTokens"
>;
export type StaffDeps = { db: admin.firestore.Firestore; auth: StaffAuthApi };

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export function parseStaffAction(raw: unknown): StaffAction | null {
  return raw === "deactivate" || raw === "reactivate" || raw === "archive" || raw === "delete"
    ? raw
    : null;
}

function isStaffRole(role: unknown): role is StaffRole {
  return role === "teacher" || role === "supervisor";
}

/** Accounts whose lifecycle adminSetStaffStatus manages. */
function hasStaffLifecycle(role: unknown): boolean {
  return isStaffRole(role) || role === ASSISTANT_TEACHER_ROLE;
}

/** Missing `staffStatus` derives from `isActive` (no backfill needed). */
export function staffStatusOf(data: admin.firestore.DocumentData | undefined): StaffStatus {
  const raw = text(data?.staffStatus);
  if ((Object.values(STAFF_STATUS) as string[]).includes(raw)) return raw as StaffStatus;
  return data?.isActive === false ? STAFF_STATUS.deactivated : STAFF_STATUS.active;
}

/**
 * A freshly provisioned Teacher is created inactive with
 * `pendingHalaqaAssignment === true` and no lifecycle `staffStatus` yet; the
 * first valid assignment activates them (Halaqa creation or reassignment).
 * Accounts that went through the explicit lifecycle — including the teacher
 * deactivated after their last Halaqa was reassigned — always carry a
 * `staffStatus` and are never auto-activated by an assignment.
 */
function isPendingFirstAssignment(data: admin.firestore.DocumentData | undefined): boolean {
  return (
    text(data?.staffStatus) === "" &&
    data?.isActive === false &&
    data?.pendingHalaqaAssignment === true
  );
}

function isOpenHalaqa(data: admin.firestore.DocumentData | undefined): boolean {
  const status = text(data?.status);
  return status !== "archived" && status !== "closed";
}

async function requireAdmin(db: admin.firestore.Firestore, callerUid: string | undefined): Promise<string> {
  const uid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "إدارة حسابات الطاقم متاحة للمسؤول فقط");
  }
  return uid;
}

export type StaffStatusResult = { uid: string; status: StaffStatus; changed: boolean };

async function applyAuth(deps: StaffDeps, uid: string, status: StaffStatus): Promise<void> {
  try {
    if (status === STAFF_STATUS.deleted) {
      await deps.auth.deleteUser(uid).catch((e: { code?: string }) => {
        if (e?.code !== "auth/user-not-found") throw e;
      });
      return;
    }
    await deps.auth.updateUser(uid, { disabled: status !== STAFF_STATUS.active });
    if (status !== STAFF_STATUS.active) await deps.auth.revokeRefreshTokens(uid);
  } catch (e) {
    if ((e as { code?: string })?.code === "auth/user-not-found") return;
    throw new HttpsError(
      "unavailable",
      "تم حفظ الحالة لكن تعذر تحديث تسجيل الدخول. أعد المحاولة لإكمال العملية.",
    );
  }
}

export async function adminSetStaffStatusCore(
  deps: StaffDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<StaffStatusResult> {
  const { db } = deps;
  const adminUid = await requireAdmin(db, callerUid);
  const uid = requireText(data.uid, "uid", 128);
  const action = parseStaffAction(data.action);
  if (!action) throw new HttpsError("invalid-argument", "إجراء غير صالح");
  if (uid === adminUid) {
    throw new HttpsError("failed-precondition", "لا يمكنك تغيير حالة حسابك");
  }
  const target = ACTION_TARGET[action];
  const userRef = db.collection("users").doc(uid);
  const privateRef = db.collection("userPrivate").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const user = await tx.get(userRef);
    if (!user.exists) throw new HttpsError("not-found", "الحساب غير موجود");
    const role = user.get("role");
    if (!hasStaffLifecycle(role)) {
      throw new HttpsError("failed-precondition", "هذا الإجراء مخصص للمعلمين والمشرفين");
    }
    const current = staffStatusOf(user.data());
    if (current === target) return { role, current, changed: false };
    if (!ALLOWED_FROM[action].includes(current)) {
      throw new HttpsError(
        "failed-precondition",
        current === STAFF_STATUS.deleted ? "الحساب محذوف نهائياً" : TRANSITION_MESSAGES[action],
      );
    }

    if (target !== STAFF_STATUS.active) {
      const [asTeacher, asSupervisor, asAssistant, asCover] = await Promise.all([
        tx.get(db.collection("halaqat").where("teacherId", "==", uid)),
        tx.get(db.collection("halaqat").where("supervisorId", "==", uid)),
        tx.get(db.collection("halaqat").where("assistantTeacherIds", "array-contains", uid)),
        tx.get(db.collection("halaqat").where("coverTeacherId", "==", uid)),
      ]);
      const open = [...asTeacher.docs, ...asSupervisor.docs, ...asAssistant.docs, ...asCover.docs]
        .filter((d) => isOpenHalaqa(d.data()));
      if (open.length > 0) {
        const names = [...new Set(open.map((d) => text(d.get("name")) || "حلقة بدون اسم"))];
        throw new HttpsError(
          "failed-precondition",
          `أعد إسناد حلقات هذا الحساب أولاً: ${names.join("، ")}`,
          {
            code: STAFF_HAS_HALAQAT_CODE,
            halaqat: [...new Map(open.map((d) => [d.id, { id: d.id, name: text(d.get("name")) }])).values()],
          },
        );
      }
    }

    let username = "";
    if (target === STAFF_STATUS.deleted) {
      username = text((await tx.get(privateRef)).get("loginUsername"));
    }

    tx.update(userRef, {
      staffStatus: target,
      isActive: target === STAFF_STATUS.active,
      staffStatusUpdatedAt: FieldValue.serverTimestamp(),
      staffStatusUpdatedBy: adminUid,
      ...(target === STAFF_STATUS.deleted ? { deletedAt: FieldValue.serverTimestamp() } : {}),
    });
    if (target === STAFF_STATUS.deleted) {
      tx.delete(privateRef);
      if (username) {
        // Kept (not deleted) so the username is never reissued to someone else.
        tx.set(
          db.collection(LOGIN_USERNAMES_COLLECTION).doc(username),
          { status: "retired", retiredAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
      }
    }
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: adminActor(adminUid),
          action: AUDIT_ACTION.staffStatusChange,
          targetType: AUDIT_TARGET_TYPE.user,
          targetId: uid,
          metadata: { role, previousStatus: current, newStatus: target, operation: action },
          source: "adminSetStaffStatus",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    return { role, current, changed: true };
  });

  // Also re-applied on an idempotent retry so a failed Auth step can finish.
  await applyAuth(deps, uid, target);
  return { uid, status: target, changed: result.changed };
}

export type ReassignResult = {
  halaqaId: string;
  role: StaffRole;
  previousStaffId: string;
  newStaffId: string;
  changed: boolean;
  sessionsUpdated: number;
};

/**
 * Moves one halaqa to another teacher (or supervisor) in a single
 * transaction: halaqa pointer, teacher profiles, not-yet-started scheduled
 * sessions, schedule locks and the audit entry. Past and running sessions
 * keep the teacher who held them. The halaqa chat group follows through the
 * existing `syncHalaqaGroupOnWrite` trigger.
 *
 * A teacher is mandatory; a supervisor may be cleared (`newStaffId: ""`),
 * matching halaqa creation where the supervisor is optional.
 */
export async function adminReassignHalaqaStaffCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
  now: () => Date = () => new Date(),
): Promise<ReassignResult> {
  const adminUid = await requireAdmin(db, callerUid);
  const halaqaId = requireText(data.halaqaId, "halaqaId", 128);
  const role = data.role;
  if (!isStaffRole(role)) throw new HttpsError("invalid-argument", "الدور غير صالح");
  const newStaffId = text(data.newStaffId);
  if (newStaffId.length > 128) throw new HttpsError("invalid-argument", "المعرّف غير صالح");
  if (role === "teacher" && !newStaffId) {
    throw new HttpsError("invalid-argument", "اختر معلماً بديلاً؛ لا تُترك الحلقة بلا معلم");
  }
  const field = role === "teacher" ? "teacherId" : "supervisorId";
  const halaqaRef = db.collection("halaqat").doc(halaqaId);
  const pre = await halaqaRef.get();
  if (!pre.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
  const previousStaffId = text(pre.get(field));
  const lockRefs =
    role === "teacher"
      ? [...new Set([previousStaffId, newStaffId].filter(Boolean))].map((id) =>
          db.collection(HALAQA_SCHEDULE_LOCKS_COLLECTION).doc(`teacher_${id}`),
        )
      : [];

  return db.runTransaction(async (tx) => {
    for (const ref of lockRefs) await tx.get(ref);
    const snap = await tx.get(halaqaRef);
    if (!snap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
    if (text(snap.get(field)) !== previousStaffId) {
      throw new HttpsError("aborted", "تغيّر إسناد الحلقة، أعد المحاولة");
    }
    const base = { halaqaId, role, previousStaffId, newStaffId };
    if (previousStaffId === newStaffId) return { ...base, changed: false, sessionsUpdated: 0 };

    let activatePendingTeacher = false;
    if (newStaffId) {
      const next = await tx.get(db.collection("users").doc(newStaffId));
      if (!next.exists || next.get("role") !== role) {
        throw new HttpsError(
          "failed-precondition",
          role === "teacher" ? "المعلم المحدد غير صالح" : "المشرف المحدد غير صالح",
        );
      }
      // A pending first assignment may activate an otherwise inactive teacher;
      // explicitly deactivated / archived / deleted staff stay rejected.
      activatePendingTeacher = isPendingFirstAssignment(next.data());
      if (!activatePendingTeacher && staffStatusOf(next.data()) !== STAFF_STATUS.active) {
        throw new HttpsError("failed-precondition", "لا يمكن الإسناد إلى حساب غير نشط");
      }
      if (role === "teacher" && text(snap.get("coverTeacherId")) === newStaffId) {
        throw new HttpsError(
          "failed-precondition",
          "هذا المعلم يغطي الحلقة مؤقتاً؛ أنهِ التغطية المؤقتة قبل جعله المعلم الأساسي",
        );
      }
    }

    let deactivatePreviousTeacher = false;
    if (role === "teacher" && previousStaffId) {
      const assignedElsewhere = await tx.get(
        db.collection("halaqat").where("teacherId", "==", previousStaffId),
      );
      const hasOtherActiveHalaqa = assignedElsewhere.docs.some((halaqa) =>
        halaqa.id !== halaqaId && (!text(halaqa.get("status")) || text(halaqa.get("status")) === "active"),
      );
      if (!hasOtherActiveHalaqa) {
        const previousTeacher = await tx.get(db.collection("users").doc(previousStaffId));
        deactivatePreviousTeacher = previousTeacher.exists && previousTeacher.get("isActive") !== false;
      }
    }

    if (role === "teacher") {
      const schedule = (Array.isArray(snap.get("schedule")) ? snap.get("schedule") : [])
        .filter((s: unknown) => typeof s === "object" && s !== null)
        .map((s: Record<string, unknown>) => ({
          day: text(s.day),
          startTime: text(s.startTime),
          endTime: text(s.endTime),
        }));
      const others = await loadOtherHalaqat(db, tx, newStaffId, []);
      const clash = evaluateWeeklyConflicts({
        halaqaId,
        teacherId: newStaffId,
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
    }

    const upcoming = await tx.get(
      db.collection("sessions").where("halaqaId", "==", halaqaId).where("status", "==", "scheduled"),
    );
    const nowMs = now().getTime();
    const toMove = upcoming.docs.filter((d) => {
      const startAt = d.get("startAt");
      return startAt instanceof Timestamp && startAt.toMillis() > nowMs;
    });
    if (toMove.length > MAX_REASSIGNED_SESSIONS) {
      throw new HttpsError("resource-exhausted", "عدد الجلسات المجدولة كبير جداً لنقلها دفعة واحدة");
    }

    tx.update(halaqaRef, { [field]: newStaffId, updatedAt: FieldValue.serverTimestamp() });
    for (const d of toMove) {
      tx.update(d.ref, {
        [field]: newStaffId ? newStaffId : FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    if (role === "teacher") {
      if (previousStaffId) {
        tx.set(
          db.collection("teacherProfiles").doc(previousStaffId),
          { halaqatIds: FieldValue.arrayRemove(halaqaId) },
          { merge: true },
        );
        if (deactivatePreviousTeacher) {
          tx.update(db.collection("users").doc(previousStaffId), {
            isActive: false,
            staffStatus: STAFF_STATUS.deactivated,
            pendingHalaqaAssignment: true,
            staffStatusUpdatedAt: FieldValue.serverTimestamp(),
            staffStatusUpdatedBy: adminUid,
            updatedAt: FieldValue.serverTimestamp(),
          });
          tx.set(
            db.collection(AUDIT_LOGS_COLLECTION).doc(),
            buildAuditLogEntry(
              {
                actor: adminActor(adminUid),
                action: AUDIT_ACTION.staffStatusChange,
                targetType: AUDIT_TARGET_TYPE.user,
                targetId: previousStaffId,
                metadata: {
                  role: "teacher",
                  previousStatus: STAFF_STATUS.active,
                  newStatus: STAFF_STATUS.deactivated,
                  operation: "deactivate_after_last_halaqa_reassignment",
                  halaqaId,
                },
                source: "adminReassignHalaqaStaff",
              },
              FieldValue.serverTimestamp(),
            ),
          );
        }
      }
      tx.set(
        db.collection("teacherProfiles").doc(newStaffId),
        { halaqatIds: FieldValue.arrayUnion(halaqaId) },
        { merge: true },
      );
      if (activatePendingTeacher) {
        tx.update(db.collection("users").doc(newStaffId), {
          isActive: true,
          pendingHalaqaAssignment: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      for (const ref of lockRefs) {
        tx.set(ref, {
          teacherId: ref.id.slice("teacher_".length),
          lastHalaqaId: halaqaId,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: adminActor(adminUid),
          action: AUDIT_ACTION.halaqaStaffReassign,
          targetType: AUDIT_TARGET_TYPE.halaqa,
          targetId: halaqaId,
          metadata: {
            halaqaId,
            role,
            previousStaffId,
            newStaffId,
            updatedCount: toMove.length,
          },
          source: "adminReassignHalaqaStaff",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    appendRelationshipHistory(db, tx, {
      kind: role === "teacher" ? RELATIONSHIP_KIND.halaqaTeacher : RELATIONSHIP_KIND.halaqaSupervisor,
      operation: newStaffId ? "assign" : "unassign",
      actorId: adminUid,
      actorRole: "admin",
      halaqaId,
      staffId: newStaffId,
      previousStaffId,
    });
    return { ...base, changed: true, sessionsUpdated: toMove.length };
  });
}

export const adminSetStaffStatus = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminSetStaffStatus");
  return adminSetStaffStatusCore(
    { db: admin.firestore(), auth: admin.auth() },
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});

export const adminReassignHalaqaStaff = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminReassignHalaqaStaff");
  return adminReassignHalaqaStaffCore(
    admin.firestore(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});
