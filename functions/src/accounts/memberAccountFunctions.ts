/**
 * Individual account creation from the app and the Admin account-status view.
 *
 * Creation uses the same `createMemberAccount` path as bulk import (academy
 * username, one-time temporary password, mandatory first-login change, next
 * free academy code). Students are not created here: they go through
 * `adminOnboardStudent`, which always links a guardian.
 *
 * The status view never returns a password or the private email. Last sign-in
 * comes from Firebase Auth metadata; recovery history comes from the audit
 * log (`user_credential_reset`), which records who reset and when, never the
 * secret.
 */

import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { AUDIT_ACTION, AUDIT_LOGS_COLLECTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, writeAuditLog } from "../audit/auditLogWrite";
import { loadCallerRole, requireCallerUid, requireText } from "../authority/callerContext";
import { normalizeLifecycle, STUDENT_PROFILES_COLLECTION } from "../lifecycle/studentLifecycleContract";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
import { isInternalLoginEmail, MemberRole } from "./academyCredentials";
import { createMemberAccount, IssuedCredential, OnboardingDeps } from "./onboardingFunctions";

const CREATABLE_ROLES: readonly MemberRole[] = ["parent", "teacher", "supervisor", "assistant_teacher"];
const RECOVERY_HISTORY_LIMIT = 10;

async function requireAdmin(db: admin.firestore.Firestore, callerUid: string | undefined) {
  const uid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "هذه العملية متاحة للمسؤول فقط");
  }
  return uid;
}

export async function adminCreateMemberAccountCore(
  deps: OnboardingDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<IssuedCredential> {
  const adminUid = await requireAdmin(deps.db, callerUid);
  const role = data.role as MemberRole;
  if (!CREATABLE_ROLES.includes(role)) {
    throw new HttpsError(
      "invalid-argument",
      "الدور غير صالح — الطلاب يُسجَّلون من «تسجيل طالب» مع ولي أمرهم",
    );
  }
  const name = requireText(data.name, "الاسم", 60).replace(/\s+/g, " ");
  if (name.length < 2) throw new HttpsError("invalid-argument", "الاسم قصير جداً");
  const violation = contactInfoViolation(name);
  if (violation) throw new HttpsError("invalid-argument", violation);

  const issued = await createMemberAccount(deps, { role, name });
  await writeAuditLog({
    actor: adminActor(adminUid),
    action: AUDIT_ACTION.memberAccountCreate,
    targetType: AUDIT_TARGET_TYPE.user,
    targetId: issued.uid,
    metadata: { role, academyRef: issued.academyRef },
    source: "adminCreateMemberAccount",
  }, deps.db);
  return issued;
}

export type AuthLookup = Pick<admin.auth.Auth, "getUser">;

export type MemberAccountStatus = {
  userId: string;
  name: string;
  role: string;
  academyRef: string;
  isActive: boolean;
  staffStatus: string;
  lifecycle: string;
  loginKind: "username" | "email" | "none";
  username: string;
  mustChangePassword: boolean;
  authDisabled: boolean | null;
  lastSignInAtMs: number | null;
  createdAtMs: number | null;
  credentialsIssuedAtMs: number | null;
  passwordChangedAtMs: number | null;
  canResetPassword: boolean;
  recoveries: { atMs: number | null; actorId: string; actorName: string }[];
};

function ms(raw: unknown): number | null {
  return raw instanceof Timestamp ? raw.toMillis() : null;
}

function str(raw: unknown): string {
  return typeof raw === "string" ? raw.trim() : "";
}

export async function adminGetMemberAccountCore(
  db: admin.firestore.Firestore,
  auth: AuthLookup,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<MemberAccountStatus> {
  await requireAdmin(db, callerUid);
  const userId = requireText(data.userId, "userId", 128);
  const [user, priv] = await Promise.all([
    db.collection("users").doc(userId).get(),
    db.collection("userPrivate").doc(userId).get(),
  ]);
  if (!user.exists) throw new HttpsError("not-found", "الحساب غير موجود");
  const u = user.data() ?? {};
  const p = priv.data() ?? {};

  let authDisabled: boolean | null = null;
  let lastSignInAtMs: number | null = null;
  let authEmail = "";
  try {
    const record = await auth.getUser(userId);
    authDisabled = record.disabled;
    authEmail = record.email ?? "";
    const parsed = Date.parse(record.metadata.lastSignInTime ?? "");
    lastSignInAtMs = Number.isNaN(parsed) ? null : parsed;
  } catch (e) {
    if ((e as { code?: string })?.code !== "auth/user-not-found") {
      throw new HttpsError("unavailable", "تعذر قراءة حالة تسجيل الدخول، أعد المحاولة");
    }
  }

  const username = str(p.loginUsername);
  const loginKind = username || isInternalLoginEmail(authEmail)
    ? "username"
    : authEmail
      ? "email"
      : "none";

  const resets = await db
    .collection(AUDIT_LOGS_COLLECTION)
    .where("targetId", "==", userId)
    .where("action", "==", AUDIT_ACTION.userCredentialReset)
    .orderBy("timestamp", "desc")
    .limit(RECOVERY_HISTORY_LIMIT)
    .get();
  const actorIds = [...new Set(resets.docs.map((d) => str(d.get("actorId"))).filter(Boolean))];
  const actors = actorIds.length
    ? await db.getAll(...actorIds.map((id) => db.collection("users").doc(id)))
    : [];
  const actorName = new Map(actors.map((a) => [a.id, str(a.get("name"))]));

  const role = str(u.role);
  // Lifecycle lives on studentProfiles (adminSetStudentLifecycle never
  // writes users.lifecycle).
  const lifecycle = role === "student"
    ? normalizeLifecycle((await db.collection(STUDENT_PROFILES_COLLECTION).doc(userId).get())
      .get("lifecycle"))
    : "";
  return {
    userId,
    name: str(u.name),
    role,
    academyRef: str(u.academyRef),
    isActive: u.isActive !== false,
    staffStatus: str(u.staffStatus),
    lifecycle,
    loginKind,
    username,
    mustChangePassword: p.mustChangePassword === true || u.passwordChangeRequired === true,
    authDisabled,
    lastSignInAtMs,
    createdAtMs: ms(u.createdAt),
    credentialsIssuedAtMs: ms(p.credentialsIssuedAt),
    passwordChangedAtMs: ms(p.passwordChangedAt),
    canResetPassword: role !== "admin" && username !== "" && str(u.staffStatus) !== "deleted",
    recoveries: resets.docs.map((d) => ({
      atMs: ms(d.get("timestamp")),
      actorId: str(d.get("actorId")),
      actorName: actorName.get(str(d.get("actorId"))) ?? "",
    })),
  };
}

export const adminCreateMemberAccount = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminCreateMemberAccount");
  return adminCreateMemberAccountCore(
    { db: admin.firestore(), auth: admin.auth() },
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});

export const adminGetMemberAccount = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminGetMemberAccount");
  return adminGetMemberAccountCore(
    admin.firestore(),
    admin.auth(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});
