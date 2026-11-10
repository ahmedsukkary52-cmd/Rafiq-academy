/**
 * Admin activation of parent and student accounts (`users.isActive`).
 *
 * Staff use adminSetStaffStatus (halaqa reassignment checks, staffStatus);
 * Admin accounts are never switched here, so this path cannot lock the
 * academy out of its last Admin. An archived student is reactivated only
 * after adminSetStudentLifecycle unarchives them. Every change is audited;
 * deactivation revokes refresh tokens so sessions end at the next refresh.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { AUDIT_ACTION, AUDIT_LOGS_COLLECTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, buildAuditLogEntry } from "../audit/auditLogWrite";
import { loadCallerRole, requireCallerUid, requireText } from "../authority/callerContext";
import {
  LIFECYCLE_ARCHIVED,
  normalizeLifecycle,
  STUDENT_PROFILES_COLLECTION,
} from "../lifecycle/studentLifecycleContract";
import { assertBackendAllowed } from "../productionGate";

export const MEMBER_ACTIVE_ROLES = ["parent", "student"] as const;

export type MemberStatusAuthApi = Pick<admin.auth.Auth, "revokeRefreshTokens">;
export type MemberStatusDeps = { db: admin.firestore.Firestore; auth: MemberStatusAuthApi };

export type MemberActiveResult = { uid: string; isActive: boolean; changed: boolean };

export async function adminSetMemberActiveCore(
  deps: MemberStatusDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<MemberActiveResult> {
  const { db } = deps;
  const adminUid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, adminUid)) !== "admin") {
    throw new HttpsError("permission-denied", "تفعيل الحسابات متاح للمسؤول فقط");
  }
  const uid = requireText(data.uid, "uid", 128);
  if (typeof data.isActive !== "boolean") {
    throw new HttpsError("invalid-argument", "حالة التفعيل غير صالحة");
  }
  const isActive = data.isActive;
  if (uid === adminUid) {
    throw new HttpsError("failed-precondition", "لا يمكنك تغيير حالة حسابك");
  }
  const userRef = db.collection("users").doc(uid);
  const profileRef = db.collection(STUDENT_PROFILES_COLLECTION).doc(uid);

  const changed = await db.runTransaction(async (tx) => {
    const [user, profile] = await tx.getAll(userRef, profileRef);
    if (!user.exists) throw new HttpsError("not-found", "الحساب غير موجود");
    const role = user.get("role");
    if (!(MEMBER_ACTIVE_ROLES as readonly string[]).includes(role)) {
      throw new HttpsError(
        "failed-precondition",
        role === "admin"
          ? "لا يمكن تغيير حالة حساب مسؤول من هنا"
          : "حالة حسابات الطاقم تُدار من صفحة الطاقم",
      );
    }
    if (
      isActive &&
      role === "student" &&
      normalizeLifecycle(profile.get("lifecycle")) === LIFECYCLE_ARCHIVED
    ) {
      throw new HttpsError("failed-precondition", "الطالب مؤرشف؛ ألغِ الأرشفة أولاً");
    }
    const previous = user.get("isActive") !== false;
    if (previous === isActive) return false;
    tx.update(userRef, {
      isActive,
      isActiveUpdatedAt: FieldValue.serverTimestamp(),
      isActiveUpdatedBy: adminUid,
    });
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: adminActor(adminUid),
          action: AUDIT_ACTION.accountActiveChange,
          targetType: AUDIT_TARGET_TYPE.user,
          targetId: uid,
          metadata: { role, previousActive: previous, newActive: isActive },
          source: "adminSetMemberActive",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    return true;
  });

  if (!isActive) {
    try {
      await deps.auth.revokeRefreshTokens(uid);
    } catch (e) {
      if ((e as { code?: string })?.code !== "auth/user-not-found") {
        throw new HttpsError(
          "unavailable",
          "تم حفظ الحالة لكن تعذر إنهاء الجلسات. أعد المحاولة لإكمال العملية.",
        );
      }
    }
  }
  return { uid, isActive, changed };
}

export const adminSetMemberActive = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminSetMemberActive");
  return adminSetMemberActiveCore(
    { db: admin.firestore(), auth: admin.auth() },
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});
