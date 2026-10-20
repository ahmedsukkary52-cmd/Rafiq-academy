import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, writeAuditLog } from "../audit/auditLogWrite";
import { findContactFieldKey } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
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

async function writeRoleProfile(
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
    case "admin":
      // No dedicated supervisorProfiles SSOT (D24). Admin has no extra profile.
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
  const isActive =
    typeof request.data?.isActive === "boolean" ? request.data.isActive : true;

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
      disabled: !isActive,
    });

    const uid = authUser.uid;
    const db = admin.firestore();

    await db.collection("users").doc(uid).set({
      name,
      role,
      email,
      isActive,
      createdAt: FieldValue.serverTimestamp(),
    });

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
      try {
        await admin.auth().deleteUser(authUser.uid);
      } catch {
        // Compensation best-effort; surface original error.
      }
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
