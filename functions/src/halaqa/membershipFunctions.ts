/**
 * PH-02 — Academy Admission workflow (server-authoritative).
 *
 * `halaqat.studentIds` is the membership SSOT; `studentProfiles.halaqaId` is
 * only the primary UI pointer (AcademyMembershipInvariant). Clients no longer
 * mutate either field directly.
 *
 * Concurrency: every admission/transfer reads and writes
 * `studentMembershipLocks/{studentId}` inside its transaction, so two
 * concurrent admissions of one student serialize and the max-2 cap holds.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  AUDIT_ACTION,
  AUDIT_LOGS_COLLECTION,
  AUDIT_TARGET_TYPE,
} from "../audit/auditLogContract";
import {
  adminActor,
  buildAuditLogEntry,
  supervisorActor,
} from "../audit/auditLogWrite";
import {
  loadCallerRole,
  requireCallerUid,
  requireText,
} from "../authority/callerContext";
import { LIFECYCLE_ARCHIVED, normalizeLifecycle } from "../lifecycle/studentLifecycleContract";
import { assertBackendAllowed } from "../productionGate";
import { appendRelationshipHistory, RELATIONSHIP_KIND } from "../relationships/relationshipHistory";

export const MAX_HALAQAT_PER_STUDENT = 2;
export const MEMBERSHIP_LOCKS_COLLECTION = "studentMembershipLocks";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

async function eligibleParentIds(
  db: admin.firestore.Firestore,
  studentId: string,
): Promise<string[]> {
  // Discover relationship candidates before the membership lock transaction.
  // Firestore Emulator cannot safely combine an array-contains query followed
  // by additional transaction reads under concurrent admissions.
  const profiles = await db
    .collection("parentProfiles")
    .where("childrenIds", "array-contains", studentId)
    .get();
  if (profiles.empty) {
    throw new HttpsError("failed-precondition", "يجب ربط الطالب بولي أمر نشط قبل التسجيل في الحلقة");
  }
  const parents = await db.getAll(...profiles.docs.map((profile) => db.collection("users").doc(profile.id)));
  const ids = parents
    .filter((parent) => parent.exists && parent.get("role") === "parent" && parent.get("isActive") !== false)
    .map((parent) => parent.id);
  if (ids.length === 0) {
    throw new HttpsError("failed-precondition", "لا يوجد ولي أمر صالح ونشط مرتبط بالطالب");
  }
  return ids;
}

async function requireEligibleParent(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  studentId: string,
  candidateIds: readonly string[],
): Promise<void> {
  const refs = candidateIds.flatMap((id) => [
    db.collection("users").doc(id),
    db.collection("parentProfiles").doc(id),
  ]);
  const docs = await tx.getAll(...refs);
  for (let index = 0; index < candidateIds.length; index++) {
    const user = docs[index * 2];
    const profile = docs[index * 2 + 1];
    if (
      user.exists &&
      user.get("role") === "parent" &&
      user.get("isActive") !== false &&
      Array.isArray(profile.get("childrenIds")) &&
      profile.get("childrenIds").includes(studentId)
    ) {
      return;
    }
  }
  throw new HttpsError("failed-precondition", "لا يوجد ولي أمر صالح ونشط مرتبط بالطالب");
}

/** AcademyMembershipInvariant.shouldSetPrimaryOnEstablish. */
export function shouldSetPrimaryOnEstablish(params: {
  currentPrimary: string;
  otherMembershipIds: readonly string[];
}): boolean {
  // PH-02 invariant: never invent a primary while other memberships already
  // exist; only establish primary when the student has none yet.
  if (params.otherMembershipIds.length > 0) return false;
  return params.currentPrimary.trim() === "";
}

/**
 * Who may bring this student into a halaqa. The lifecycle SSOT is
 * `studentProfiles.lifecycle`: an archived student joins nothing until
 * adminSetStudentLifecycle unarchives them. A supervisor only reaches
 * students already in their own scope or in no halaqa at all, and never
 * reactivates an account (admission by Admin does).
 */
function assertStudentAdmissible(params: {
  role: string;
  callerUid: string;
  userData: admin.firestore.DocumentData | undefined;
  profileData: admin.firestore.DocumentData | undefined;
  otherMemberships: readonly admin.firestore.QueryDocumentSnapshot[];
}): void {
  if (normalizeLifecycle(params.profileData?.lifecycle) === LIFECYCLE_ARCHIVED) {
    throw new HttpsError("failed-precondition", "لا يمكن إضافة طالب مؤرشف إلى حلقة");
  }
  if (params.role !== "supervisor") return;
  if (params.userData?.isActive === false) {
    throw new HttpsError("failed-precondition", "حساب الطالب غير نشط؛ تفعيله من صلاحيات المسؤول");
  }
  if (params.otherMemberships.some((d) => text(d.data()?.supervisorId) !== params.callerUid)) {
    throw new HttpsError("permission-denied", "الطالب مسجّل في حلقة خارج نطاق إشرافك");
  }
}

/** primaryAfterTransfer + primaryAfterMembershipsChanged. */
export function primaryAfterTransfer(params: {
  currentPrimary: string;
  source: string;
  target: string;
  remaining: readonly string[];
}): string | null {
  const primary = params.currentPrimary.trim();
  const next = primary === "" || primary === params.source ? params.target : primary;
  const remaining = new Set(params.remaining.filter((id) => id.trim() !== ""));
  if (remaining.size === 0) return null;
  if (remaining.has(next)) return next;
  return [...remaining].sort()[0];
}

export type AdmitResult = {
  studentId: string;
  halaqaId: string;
  membershipCount: number;
  primaryHalaqaId: string | null;
};

/** Admin: any halaqa. Supervisor: only a halaqa they supervise. */
export async function admitStudentToHalaqaCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<AdmitResult> {
  const uid = requireCallerUid(callerUid);
  const studentId = requireText(data.studentId, "studentId");
  const halaqaId = requireText(data.halaqaId, "halaqaId");

  const role = await loadCallerRole(db, uid);
  if (role !== "admin" && role !== "supervisor") {
    throw new HttpsError(
      "permission-denied",
      "إضافة الطلاب للحلقات متاحة للمسؤول أو مشرف الحلقة فقط",
    );
  }

  const candidateStudent = await db.collection("users").doc(studentId).get();
  if (!candidateStudent.exists) throw new HttpsError("not-found", "الطالب غير موجود");
  if (candidateStudent.get("role") !== "student") {
    throw new HttpsError("failed-precondition", "لا يمكن إتمام العضوية: دور المستخدم ليس طالباً");
  }
  const parentIds = await eligibleParentIds(db, studentId);
  const lockRef = db.collection(MEMBERSHIP_LOCKS_COLLECTION).doc(studentId);
  const userRef = db.collection("users").doc(studentId);
  const profileRef = db.collection("studentProfiles").doc(studentId);
  const halaqaRef = db.collection("halaqat").doc(halaqaId);

  return db.runTransaction(async (tx) => {
    await tx.get(lockRef);
    const [userSnap, profileSnap, halaqaSnap] = await tx.getAll(
      userRef,
      profileRef,
      halaqaRef,
    );
    if (!userSnap.exists) throw new HttpsError("not-found", "الطالب غير موجود");
    if (userSnap.data()?.role !== "student") {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن إتمام العضوية: دور المستخدم ليس طالباً",
      );
    }
    if (!profileSnap.exists) throw new HttpsError("not-found", "ملف الطالب غير موجود");
    if (!halaqaSnap.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
    if (text(halaqaSnap.get("status")) && text(halaqaSnap.get("status")) !== "active") {
      throw new HttpsError("failed-precondition", "لا يمكن التسجيل في حلقة غير نشطة");
    }

    if (role === "supervisor" && text(halaqaSnap.data()?.supervisorId) !== uid) {
      throw new HttpsError("permission-denied", "الحلقة خارج نطاق إشرافك");
    }
    await requireEligibleParent(db, tx, studentId, parentIds);

    const membershipSnap = await tx.get(
      db.collection("halaqat").where("studentIds", "array-contains", studentId),
    );
    const memberships = membershipSnap.docs.map((d) => d.id);
    if (memberships.includes(halaqaId)) {
      throw new HttpsError("already-exists", "الطالب عضو بالفعل في هذه الحلقة");
    }
    if (memberships.length >= MAX_HALAQAT_PER_STUDENT) {
      throw new HttpsError("failed-precondition", "الطالب وصل للحد الأقصى (حلقتان)");
    }
    assertStudentAdmissible({
      role,
      callerUid: uid,
      userData: userSnap.data(),
      profileData: profileSnap.data(),
      otherMemberships: membershipSnap.docs,
    });

    const currentPrimary = text(profileSnap.data()?.halaqaId);
    const setPrimary = shouldSetPrimaryOnEstablish({
      currentPrimary,
      otherMembershipIds: memberships,
    });

    tx.update(halaqaRef, {
      studentIds: FieldValue.arrayUnion(studentId),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (setPrimary) tx.update(profileRef, { halaqaId });
    if (role === "admin") tx.update(userRef, { isActive: true });
    const after = [...memberships, halaqaId];
    tx.set(lockRef, {
      studentId,
      halaqaIds: after,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: role === "admin" ? adminActor(uid) : supervisorActor(uid),
          action: AUDIT_ACTION.studentAdmit,
          targetType: AUDIT_TARGET_TYPE.halaqa,
          targetId: halaqaId,
          metadata: { studentId, halaqaId },
          source: "admitStudentToHalaqa",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    appendRelationshipHistory(db, tx, {
      kind: RELATIONSHIP_KIND.halaqaMembership,
      operation: "admit",
      actorId: uid,
      actorRole: role,
      halaqaId,
      studentId,
    });

    return {
      studentId,
      halaqaId,
      membershipCount: after.length,
      primaryHalaqaId: setPrimary ? halaqaId : currentPrimary || null,
    };
  });
}

export type TransferResult = {
  studentId: string;
  fromHalaqaId: string;
  toHalaqaId: string;
  primaryHalaqaId: string | null;
};

/**
 * Atomic move (1 out, 1 in) — the cap is preserved.
 * Admin: any halaqat. Supervisor: only when BOTH source and target are
 * supervised by the caller (spec §2 "Admit/transfer via CF within supervised").
 */
export async function adminTransferStudentCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<TransferResult> {
  const uid = requireCallerUid(callerUid);
  const studentId = requireText(data.studentId, "studentId");
  const source = requireText(data.fromHalaqaId, "fromHalaqaId");
  const target = requireText(data.toHalaqaId, "toHalaqaId");
  if (source === target) {
    throw new HttpsError("invalid-argument", "المصدر والهدف يجب أن يختلفا");
  }
  const role = await loadCallerRole(db, uid);
  if (role !== "admin" && role !== "supervisor") {
    throw new HttpsError(
      "permission-denied",
      "نقل الطلاب متاح للمسؤول أو مشرف الحلقتين فقط",
    );
  }

  const candidateStudent = await db.collection("users").doc(studentId).get();
  if (!candidateStudent.exists) throw new HttpsError("not-found", "الطالب غير موجود");
  if (candidateStudent.get("role") !== "student") {
    throw new HttpsError("failed-precondition", "لا يمكن إتمام النقل: دور المستخدم ليس طالباً");
  }
  const parentIds = await eligibleParentIds(db, studentId);
  const lockRef = db.collection(MEMBERSHIP_LOCKS_COLLECTION).doc(studentId);
  const userRef = db.collection("users").doc(studentId);
  const profileRef = db.collection("studentProfiles").doc(studentId);
  const sourceRef = db.collection("halaqat").doc(source);
  const targetRef = db.collection("halaqat").doc(target);

  return db.runTransaction(async (tx) => {
    await tx.get(lockRef);
    const [userSnap, profileSnap, sourceSnap, targetSnap] = await tx.getAll(
      userRef,
      profileRef,
      sourceRef,
      targetRef,
    );
    if (!userSnap.exists) throw new HttpsError("not-found", "الطالب غير موجود");
    if (userSnap.data()?.role !== "student") {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن إتمام النقل: دور المستخدم ليس طالباً",
      );
    }
    if (!profileSnap.exists) throw new HttpsError("not-found", "ملف الطالب غير موجود");
    if (!sourceSnap.exists || !targetSnap.exists) {
      throw new HttpsError("not-found", "الحلقة غير موجودة");
    }
    if (text(targetSnap.get("status")) && text(targetSnap.get("status")) !== "active") {
      throw new HttpsError("failed-precondition", "لا يمكن نقل الطالب إلى حلقة غير نشطة");
    }
    if (
      role === "supervisor" &&
      (text(sourceSnap.data()?.supervisorId) !== uid ||
        text(targetSnap.data()?.supervisorId) !== uid)
    ) {
      throw new HttpsError("permission-denied", "الحلقة خارج نطاق إشرافك");
    }
    await requireEligibleParent(db, tx, studentId, parentIds);

    const membershipSnap = await tx.get(
      db.collection("halaqat").where("studentIds", "array-contains", studentId),
    );
    const memberships = membershipSnap.docs.map((d) => d.id);
    if (!memberships.includes(source)) {
      throw new HttpsError("failed-precondition", "الطالب ليس عضوًا في الحلقة المصدر");
    }
    if (memberships.includes(target)) {
      throw new HttpsError("already-exists", "الطالب عضو بالفعل في الحلقة الهدف");
    }
    const remaining = [...memberships.filter((id) => id !== source), target];
    if (remaining.length > MAX_HALAQAT_PER_STUDENT) {
      throw new HttpsError("failed-precondition", "الطالب وصل للحد الأقصى (حلقتان)");
    }
    // Source and target are already checked for a supervisor; the student's
    // other halaqa may belong to someone else and does not change hands.
    assertStudentAdmissible({
      role,
      callerUid: uid,
      userData: userSnap.data(),
      profileData: profileSnap.data(),
      otherMemberships: [],
    });

    const primary = primaryAfterTransfer({
      currentPrimary: text(profileSnap.data()?.halaqaId),
      source,
      target,
      remaining,
    });

    tx.update(sourceRef, {
      studentIds: FieldValue.arrayRemove(studentId),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(targetRef, {
      studentIds: FieldValue.arrayUnion(studentId),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(profileRef, { halaqaId: primary });
    tx.set(lockRef, {
      studentId,
      halaqaIds: remaining,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: role === "admin" ? adminActor(uid) : supervisorActor(uid),
          action: AUDIT_ACTION.studentTransfer,
          targetType: AUDIT_TARGET_TYPE.studentProfile,
          targetId: studentId,
          metadata: { studentId, fromHalaqaId: source, toHalaqaId: target },
          source: "adminTransferStudent",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    appendRelationshipHistory(db, tx, {
      kind: RELATIONSHIP_KIND.halaqaMembership,
      operation: "transfer",
      actorId: uid,
      actorRole: role,
      fromHalaqaId: source,
      toHalaqaId: target,
      studentId,
    });

    return { studentId, fromHalaqaId: source, toHalaqaId: target, primaryHalaqaId: primary };
  });
}

export const admitStudentToHalaqa = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("admitStudentToHalaqa");
    return admitStudentToHalaqaCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

export const adminTransferStudent = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("adminTransferStudent");
    return adminTransferStudentCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
