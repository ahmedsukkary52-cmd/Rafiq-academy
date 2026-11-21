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
import {
  loadCallerRole,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import {
  LIFECYCLE_ARCHIVED,
  normalizeLifecycle,
  STUDENT_PROFILES_COLLECTION,
} from "../lifecycle/studentLifecycleContract";
import { assertBackendAllowed } from "../productionGate";

export const MEMBER_ACTIVE_ROLES = ["parent", "student"] as const;

/**
 * Guardianship invariant for Parent deactivation: an active Student must keep
 * at least one eligible active Parent. The same rule the unlink path already
 * enforces (a Student may never lose their last guardian) applies when a Parent
 * account is deactivated; only the account suspension differs, the relationship
 * graph does not.
 *
 * The candidate co-guardians are discovered before the transaction (the
 * emulator cannot safely combine an `array-contains` query with further
 * transaction reads), then every candidate is re-read inside the same
 * transaction as the deactivation. A concurrent unlink, replacement or
 * deactivation of any candidate therefore conflicts and retries, so the
 * decision is always re-made against the committed state.
 */
type CoGuardianPlan = { childId: string; otherParentIds: string[] };

async function discoverCoGuardians(
  db: admin.firestore.Firestore,
  parentId: string,
): Promise<CoGuardianPlan[]> {
  const profile = await db.collection("parentProfiles").doc(parentId).get();
  const childrenIds = stringList(profile.get("childrenIds"));
  const plan: CoGuardianPlan[] = [];
  for (const childId of childrenIds) {
    const guardians = await db
      .collection("parentProfiles")
      .where("childrenIds", "array-contains", childId)
      .get();
    plan.push({
      childId,
      otherParentIds: guardians.docs.map((d) => d.id).filter((id) => id !== parentId),
    });
  }
  return plan;
}

function isActiveStudent(
  user: admin.firestore.DocumentSnapshot | undefined,
  profile: admin.firestore.DocumentSnapshot | undefined,
): boolean {
  return (
    Boolean(user?.exists) &&
    user?.get("role") === "student" &&
    user?.get("isActive") !== false &&
    normalizeLifecycle(profile?.get("lifecycle")) !== LIFECYCLE_ARCHIVED
  );
}

function isEligibleGuardianOf(
  user: admin.firestore.DocumentSnapshot | undefined,
  profile: admin.firestore.DocumentSnapshot | undefined,
  childId: string,
): boolean {
  const children = profile?.get("childrenIds");
  return (
    Boolean(user?.exists) &&
    user?.get("role") === "parent" &&
    user?.get("isActive") !== false &&
    Array.isArray(children) &&
    children.includes(childId)
  );
}

async function assertDeactivationKeepsGuardians(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  parentId: string,
  plan: readonly CoGuardianPlan[],
): Promise<void> {
  const refs = new Map<string, admin.firestore.DocumentReference>();
  const add = (ref: admin.firestore.DocumentReference) => {
    if (!refs.has(ref.path)) refs.set(ref.path, ref);
  };
  add(db.collection("parentProfiles").doc(parentId));
  for (const entry of plan) {
    add(db.collection("users").doc(entry.childId));
    add(db.collection(STUDENT_PROFILES_COLLECTION).doc(entry.childId));
    for (const otherId of entry.otherParentIds) {
      add(db.collection("parentProfiles").doc(otherId));
      add(db.collection("users").doc(otherId));
    }
  }
  const refList = [...refs.values()];
  const snapshots = await tx.getAll(...refList);
  const byPath = new Map<string, admin.firestore.DocumentSnapshot>();
  refList.forEach((ref, index) => byPath.set(ref.path, snapshots[index]));

  const ownChildren = new Set(
    stringList(byPath.get(db.collection("parentProfiles").doc(parentId).path)?.get("childrenIds")),
  );

  for (const { childId, otherParentIds } of plan) {
    // The candidate was discovered before the transaction; re-check that this
    // Parent still guards the child in the committed state.
    if (!ownChildren.has(childId)) continue;
    if (
      !isActiveStudent(
        byPath.get(db.collection("users").doc(childId).path),
        byPath.get(db.collection(STUDENT_PROFILES_COLLECTION).doc(childId).path),
      )
    ) {
      continue;
    }
    const hasOtherGuardian = otherParentIds.some((otherId) =>
      isEligibleGuardianOf(
        byPath.get(db.collection("users").doc(otherId).path),
        byPath.get(db.collection("parentProfiles").doc(otherId).path),
        childId,
      ),
    );
    if (!hasOtherGuardian) {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن تعطيل حساب ولي الأمر لأنه ولي الأمر النشط الوحيد لطالب نشط؛ عيّن ولي أمر بديلاً أولاً",
      );
    }
  }
}

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
  // Only a deactivation can strip a Student of their last guardian.
  const coGuardianPlan = isActive ? [] : await discoverCoGuardians(db, uid);

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
    if (!isActive && role === "parent" && coGuardianPlan.length > 0) {
      await assertDeactivationKeepsGuardians(db, tx, uid, coGuardianPlan);
    }
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
