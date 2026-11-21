import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, writeAuditLog } from "../audit/auditLogWrite";
import { findContactFieldKey } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
import { normalizeArabicSearchText } from "../search/arabicNormalization";
import { assertCallerIsAdmin, parseProvisionRole, ProvisionRole } from "./assertAdmin";

interface AdminProvisionUserRequest {
  email: string;
  password: string;
  name: string;
  role: string;
  isActive?: boolean;
}

interface AdminProvisionUserResponse {
  uid: string;
}

function requireNonEmptyString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} مطلوب`);
  }
  return value.trim();
}

export async function writeRoleProfile(
  db: admin.firestore.Firestore,
  uid: string,
  role: ProvisionRole,
  name: string,
): Promise<void> {
  const now = FieldValue.serverTimestamp();
  switch (role) {
    case "student":
      await db.collection("studentProfiles").doc(uid).set(
        {
          uid,
          name,
          avatarId: "fox",
          level: 1,
          coins: 0,
          totalStars: 0,
          streakDays: 0,
          halaqaId: null,
          halaqaName: null,
          currentPlanName: null,
          overallProgressPercent: 0,
          totalVersesMemorized: 0,
          completedJuz: 0,
          completedSurahs: 0,
          createdAt: now,
        },
        { merge: true },
      );
      break;
    case "parent":
      await db.collection("parentProfiles").doc(uid).set(
        {
          uid,
          childrenIds: [],
          createdAt: now,
        },
        { merge: true },
      );
      break;
    case "teacher":
      await db.collection("teacherProfiles").doc(uid).set(
        {
          uid,
          halaqatIds: [],
          weeklyQuota: 0,
          createdAt: now,
        },
        { merge: true },
      );
      break;
    case "supervisor":
    case "assistant_teacher":
    case "admin":
      // No dedicated supervisorProfiles SSOT (D24). Assistant assignments live
      // on halaqat.assistantTeacherIds; Admin has no extra profile.
      break;
  }
}


/**
 * C1 / D1 — Admin-only Auth + users + profile provisioning.
 * Emulator-ready. Production requires B-BILLING / PRODUCTION_BACKEND_ENABLED.
 */
export const adminProvisionUser = onCall<
  AdminProvisionUserRequest,
  Promise<AdminProvisionUserResponse>
>({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminProvisionUser");

  const actorUid = await assertCallerIsAdmin(request.auth?.uid);

  if (findContactFieldKey(request.data) !== null) {
    throw new HttpsError(
      "invalid-argument",
      "لا يتم حفظ أرقام الهواتف الشخصية في التطبيق",
    );
  }

  const email = requireNonEmptyString(request.data?.email, "email");
  const password = requireNonEmptyString(request.data?.password, "password");
  const name = requireNonEmptyString(request.data?.name, "name");
  const role = parseProvisionRole(request.data?.role);
  if (role === "student") {
    throw new HttpsError(
      "failed-precondition",
      "يجب تسجيل الطالب مع ولي أمر وحلقة من مسار تسجيل الطلاب",
    );
  }
  const requestedActive =
    typeof request.data?.isActive === "boolean" ? request.data.isActive : true;
  // Teachers remain unable to use academy services until a Halaqa assignment
  // transaction activates them. Auth creation itself is not atomic with that
  // later assignment, so the Firestore role gate stays closed meanwhile.
  const isPendingTeacher = role === "teacher";
  const isActive = isPendingTeacher ? false : requestedActive;

  if (password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "كلمة المرور يجب أن تكون 6 أحرف على الأقل",
    );
  }

  let authUser: admin.auth.UserRecord | null = null;
  try {
    authUser = await admin.auth().createUser({
      email,
      password,
      displayName: name,
      disabled: !isPendingTeacher && !isActive,
    });

    const uid = authUser.uid;
    const db = admin.firestore();

    // Email never goes on users/{uid} (readable by other active users); it
    // lives in userPrivate/{uid}, which only the owner and Admin can read.
    const batch = db.batch();
    batch.set(db.collection("users").doc(uid), {
      name,
      role,
      isActive,
      createdAt: FieldValue.serverTimestamp(),
    });
    // Admin directory search key (memberDirectory.ts).
    batch.update(db.collection("users").doc(uid), {
      nameNormalized: normalizeArabicSearchText(name),
    });
    batch.set(db.collection("userPrivate").doc(uid), {
      email,
      emailSource: "auth",
      emailUpdatedAt: FieldValue.serverTimestamp(),
    });
    if (role === "admin") {
      // The provisioning password is known to the issuing Admin: the new
      // Admin holds no authority until completeFirstLogin replaces it.
      batch.update(db.collection("users").doc(uid), { passwordChangeRequired: true });
      batch.update(db.collection("userPrivate").doc(uid), { mustChangePassword: true });
    }
    await batch.commit();
    if (isPendingTeacher) {
      await db.collection("users").doc(uid).update({ pendingHalaqaAssignment: true });
    }

    await writeRoleProfile(db, uid, role, name);
    await writeAuditLog({
      actor: adminActor(actorUid),
      action: AUDIT_ACTION.userProvision,
      targetType: AUDIT_TARGET_TYPE.user,
      targetId: uid,
      metadata: { role },
      source: "adminProvisionUser",
    });

    return { uid };
  } catch (e: unknown) {
    if (authUser) {
      const uid = authUser.uid;
      const db = admin.firestore();
      await Promise.all([
        admin.auth().deleteUser(uid).catch(() => undefined),
        db.collection("users").doc(uid).delete().catch(() => undefined),
        db.collection("userPrivate").doc(uid).delete().catch(() => undefined),
        db.collection("studentProfiles").doc(uid).delete().catch(() => undefined),
        db.collection("parentProfiles").doc(uid).delete().catch(() => undefined),
        db.collection("teacherProfiles").doc(uid).delete().catch(() => undefined),
      ]);
    }

    if (e instanceof HttpsError) {
      throw e;
    }

    const err = e as { code?: string; message?: string };
    if (err.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "البريد الإلكتروني مسجّل مسبقاً",
      );
    }

    throw new HttpsError(
      "internal",
      err.message ?? "تعذر إنشاء الحساب",
    );
  }
});
