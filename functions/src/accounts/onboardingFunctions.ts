/**
 * Admin student onboarding (one trusted backend flow):
 *   parent (existing or new account) → student account → parent link →
 *   halaqa admission → one-time credentials.
 *
 * Idempotent and resumable per `{adminUid}_{requestId}`: progress is kept in
 * `onboardingRequests`, so a retry after a partial failure reuses the
 * accounts already created instead of duplicating them. A completed request
 * replays its summary without credentials (passwords are never stored; the
 * Admin issues new ones with `adminResetMemberPassword`).
 *
 * Also: Admin password recovery and the member's mandatory first-login
 * password change. The first-login flag lives in `userPrivate`, which no
 * client can write.
 */

import { createHash, randomUUID } from "node:crypto";

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { writeRoleProfile } from "../admin/adminProvisionUser";
import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, supervisorActor, writeAuditLog } from "../audit/auditLogWrite";
import { loadCallerRole, requireCallerUid, requireText } from "../authority/callerContext";
import { admitStudentToHalaqaCore } from "../halaqa/membershipFunctions";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
import { adminLinkParentChildCore } from "../relationships/parentLinkFunctions";
import { normalizeArabicSearchText } from "../search/arabicNormalization";
import {
  generateTemporaryPassword,
  generateUsername,
  LOGIN_USERNAMES_COLLECTION,
  loginEmailFor,
  memberPasswordProblem,
  MemberRole,
} from "./academyCredentials";
import { allocateAcademyRef, RefKind } from "./academyRefs";

export const ONBOARDING_REQUESTS_COLLECTION = "onboardingRequests";
export const REQUEST_ID_REUSED_MESSAGE = "معرّف الطلب مستخدم لطلب مختلف";
export const ONBOARDING_IN_PROGRESS_MESSAGE = "هذا الطلب قيد المعالجة؛ انتظر النتيجة قبل إعادة المحاولة";
export const ONBOARDING_LEASE_MS = 2 * 60 * 1000;
export const NO_USERNAME_MESSAGE =
  "هذا الحساب يسجّل الدخول ببريد إلكتروني؛ استخدم استعادة كلمة المرور بالبريد";

const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;
const MAX_USERNAME_ATTEMPTS = 8;

export type AuthApi = Pick<admin.auth.Auth, "createUser" | "updateUser" | "deleteUser">;
export type OnboardingDeps = { db: admin.firestore.Firestore; auth: AuthApi };

export type IssuedCredential = {
  role: MemberRole;
  uid: string;
  name: string;
  username: string;
  temporaryPassword: string;
  /** User-facing academy code (e.g. S-003); "" for legacy accounts. */
  academyRef: string;
};

export type OnboardingStep = {
  step: "parent" | "student" | "link" | "halaqa";
  status: "done" | "skipped" | "failed";
  message: string;
};

export type OnboardingResult = {
  status: "completed" | "partial";
  replayed: boolean;
  studentId: string | null;
  parentId: string | null;
  halaqaId: string | null;
  steps: OnboardingStep[];
  credentials: IssuedCredential[];
};

type ParentInput = { mode: "existing"; parentId: string } | { mode: "new"; name: string };

function requireName(raw: unknown, label: string): string {
  const name = requireText(raw, label, 60).replace(/\s+/g, " ");
  if (name.length < 2) throw new HttpsError("invalid-argument", `${label} قصير جداً`);
  const violation = contactInfoViolation(name);
  if (violation) throw new HttpsError("invalid-argument", violation);
  return name;
}

function parseParent(raw: unknown): ParentInput {
  const data = (raw ?? {}) as Record<string, unknown>;
  if (data.mode === "existing") {
    return { mode: "existing", parentId: requireText(data.parentId, "ولي الأمر", 128) };
  }
  if (data.mode === "new") return { mode: "new", name: requireName(data.name, "اسم ولي الأمر") };
  throw new HttpsError("invalid-argument", "حدد ولي أمر موجوداً أو أنشئ حساباً جديداً");
}

function fingerprintOf(studentName: string, parent: ParentInput, halaqaId: string): string {
  return createHash("sha256")
    .update(
      JSON.stringify([
        studentName,
        parent.mode,
        parent.mode === "existing" ? parent.parentId : parent.name,
        halaqaId,
      ]),
    )
    .digest("hex");
}

async function requireAdminCaller(db: admin.firestore.Firestore, callerUid: string | undefined) {
  const uid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "هذه العملية متاحة للمسؤول فقط");
  }
  return uid;
}

export function refKindOf(role: MemberRole): RefKind {
  return role === "assistant_teacher" ? "assistant" : role;
}

/**
 * Reserves a fresh username (create fails if taken), then Auth + profile.
 * [ref] is an import code already reserved in the ledger by the caller;
 * without one the account receives the next free academy code.
 */
export async function createMemberAccount(
  deps: OnboardingDeps,
  params: { role: MemberRole; name: string; ref?: string; isActive?: boolean },
): Promise<IssuedCredential> {
  const { db, auth } = deps;
  let username = "";
  for (let attempt = 0; attempt < MAX_USERNAME_ATTEMPTS && !username; attempt++) {
    const candidate = generateUsername(params.role);
    try {
      await db.collection(LOGIN_USERNAMES_COLLECTION).doc(candidate).create({
        role: params.role,
        status: "reserved",
        createdAt: FieldValue.serverTimestamp(),
      });
      username = candidate;
    } catch (e) {
      if ((e as { code?: number }).code !== 6) throw e;
    }
  }
  if (!username) throw new HttpsError("resource-exhausted", "تعذر توليد اسم مستخدم فريد، أعد المحاولة");

  const usernameRef = db.collection(LOGIN_USERNAMES_COLLECTION).doc(username);
  const temporaryPassword = generateTemporaryPassword();
  let uid = "";
  let academyRef = params.ref ?? "";
  try {
    const record = await auth.createUser({
      email: loginEmailFor(username),
      password: temporaryPassword,
      displayName: params.name,
    });
    uid = record.uid;
    const now = FieldValue.serverTimestamp();
    const batch = db.batch();
    batch.set(db.collection("users").doc(uid), {
      name: params.name,
      nameNormalized: normalizeArabicSearchText(params.name),
      role: params.role,
      isActive: params.isActive ?? (params.role !== "teacher"),
      ...(params.role === "teacher" ? { pendingHalaqaAssignment: true } : {}),
      createdAt: now,
      ...(params.ref ? { academyRef: params.ref } : {}),
    });
    batch.set(db.collection("userPrivate").doc(uid), {
      email: loginEmailFor(username),
      emailSource: "generated_login",
      loginUsername: username,
      mustChangePassword: true,
      credentialsIssuedAt: now,
    });
    batch.update(usernameRef, { uid, status: "active" });
    await batch.commit();
    await writeRoleProfile(db, uid, params.role, params.name);
    if (!academyRef) {
      academyRef = await allocateAcademyRef(db, { kind: refKindOf(params.role), uid, name: params.name });
    }
  } catch (e) {
    if (uid) {
      const profileCollection = params.role === "student"
        ? "studentProfiles"
        : params.role === "parent"
          ? "parentProfiles"
          : params.role === "teacher"
            ? "teacherProfiles"
            : "users";
      await Promise.all([
        auth.deleteUser(uid).catch(() => undefined),
        db.collection("users").doc(uid).delete().catch(() => undefined),
        db.collection("userPrivate").doc(uid).delete().catch(() => undefined),
        profileCollection === "users"
          ? Promise.resolve()
          : db.collection(profileCollection).doc(uid).delete().catch(() => undefined),
      ]);
    }
    await usernameRef.delete().catch(() => undefined);
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", "تعذر إنشاء الحساب");
  }
  return { role: params.role, uid, name: params.name, username, temporaryPassword, academyRef };
}

/** New temporary password for an account created by onboarding / import. */
async function reissuePassword(
  deps: OnboardingDeps,
  uid: string,
): Promise<IssuedCredential> {
  const [user, priv] = await Promise.all([
    deps.db.collection("users").doc(uid).get(),
    deps.db.collection("userPrivate").doc(uid).get(),
  ]);
  const username = typeof priv.get("loginUsername") === "string" ? priv.get("loginUsername") : "";
  if (!user.exists || !username) throw new HttpsError("failed-precondition", NO_USERNAME_MESSAGE);
  const temporaryPassword = generateTemporaryPassword();
  await deps.auth.updateUser(uid, { password: temporaryPassword });
  await priv.ref.set(
    { mustChangePassword: true, credentialsIssuedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return {
    role: user.get("role") as MemberRole,
    uid,
    name: String(user.get("name") ?? ""),
    username,
    temporaryPassword,
    academyRef: typeof user.get("academyRef") === "string" ? user.get("academyRef") : "",
  };
}

function stepMessage(e: unknown): string {
  return e instanceof HttpsError ? e.message : "تعذر إكمال هذه الخطوة";
}

/** [internal] carries trusted server-side inputs (never request data). */
export async function adminOnboardStudentCore(
  deps: OnboardingDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
  internal: { studentRef?: string } = {},
): Promise<OnboardingResult> {
  const { db } = deps;
  const uid = await requireAdminCaller(db, callerUid);
  const requestId = typeof data.requestId === "string" ? data.requestId : "";
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    throw new HttpsError("invalid-argument", "معرّف الطلب غير صالح");
  }
  const studentName = requireName(data.studentName, "اسم الطالب");
  const parent = parseParent(data.parent);
  const halaqaId = requireText(data.halaqaId, "الحلقة", 128);
  const fingerprint = fingerprintOf(studentName, parent, halaqaId);

  const requestRef = db.collection(ONBOARDING_REQUESTS_COLLECTION).doc(`${uid}_${requestId}`);
  const replayOf = (state: admin.firestore.DocumentData): OnboardingResult => ({
    status: "completed",
    replayed: true,
    studentId: state.studentUid ?? null,
    parentId: state.parentUid ?? null,
    halaqaId: state.halaqaId || null,
    steps: Array.isArray(state.steps) ? state.steps : [],
    credentials: [],
  });
  const checkRequest = (exists: boolean, state: admin.firestore.DocumentData) => {
    if (exists && state.fingerprint !== fingerprint) {
      throw new HttpsError("already-exists", REQUEST_ID_REUSED_MESSAGE);
    }
    return exists && state.status === "completed";
  };
  const previous = await requestRef.get();
  if (checkRequest(previous.exists, previous.data() ?? {})) return replayOf(previous.data() ?? {});

  const halaqa = await db.collection("halaqat").doc(halaqaId).get();
  if (!halaqa.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
  if ((halaqa.get("status") ?? "active") !== "active") {
    throw new HttpsError("failed-precondition", "الحلقة غير نشطة");
  }
  if (parent.mode === "existing") {
    const [user, profile] = await Promise.all([
      db.collection("users").doc(parent.parentId).get(),
      db.collection("parentProfiles").doc(parent.parentId).get(),
    ]);
    if (!user.exists || user.get("role") !== "parent" || !profile.exists) {
      throw new HttpsError("failed-precondition", "الحساب المحدد ليس ولي أمر");
    }
    if (user.get("isActive") !== true) {
      throw new HttpsError("failed-precondition", "حساب ولي الأمر غير نشط");
    }
  }

  // Atomic claim: one live attempt per request (concurrent submits of the
  // same requestId never both create accounts). A crashed attempt is taken
  // over once its lease, longer than the callable timeout, has passed.
  const attemptId = randomUUID();
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(requestRef);
    const current = snap.data() ?? {};
    if (checkRequest(snap.exists, current)) return { replay: replayOf(current) };
    const leaseUntilMs = current.leaseUntil?.toMillis?.() ?? 0;
    if (current.status === "in_progress" && Date.now() < leaseUntilMs) {
      throw new HttpsError("aborted", ONBOARDING_IN_PROGRESS_MESSAGE);
    }
    tx.set(
      requestRef,
      {
        fingerprint,
        actorId: uid,
        status: "in_progress",
        attemptId,
        leaseUntil: Timestamp.fromMillis(Date.now() + ONBOARDING_LEASE_MS),
        updatedAt: FieldValue.serverTimestamp(),
        ...(snap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );
    return { state: current };
  });
  if ("replay" in claimed) return claimed.replay as OnboardingResult;
  const state = claimed.state;

  const writeOwned = (fields: Record<string, unknown>) =>
    db.runTransaction(async (tx) => {
      const current = await tx.get(requestRef);
      if (current.get("attemptId") !== attemptId) {
        throw new HttpsError("aborted", "تولّت محاولة أحدث هذا الطلب؛ راجع نتيجتها");
      }
      tx.update(requestRef, { ...fields, updatedAt: FieldValue.serverTimestamp() });
    });

  const steps: OnboardingStep[] = [];
  const credentials: IssuedCredential[] = [];
  let parentId: string | null = parent.mode === "existing" ? parent.parentId : state.parentUid ?? null;
  let studentId: string | null = state.studentUid ?? null;

  const finish = async (status: "completed" | "partial"): Promise<OnboardingResult> => {
    await writeOwned({
      status: status === "completed" ? "completed" : "failed",
      steps,
      parentUid: parentId,
      studentUid: studentId,
      halaqaId,
      leaseUntil: FieldValue.delete(),
    });
    return { status, replayed: false, studentId, parentId, halaqaId: halaqaId || null, steps, credentials };
  };

  try {
    if (parent.mode === "existing") {
      steps.push({ step: "parent", status: "done", message: "تم اختيار ولي أمر موجود" });
    } else if (parentId) {
      credentials.push(await reissuePassword(deps, parentId));
      steps.push({ step: "parent", status: "done", message: "حساب ولي الأمر موجود من محاولة سابقة" });
    } else {
      const issued = await createMemberAccount(deps, { role: "parent", name: parent.name });
      parentId = issued.uid;
      credentials.push(issued);
      await writeOwned({ parentUid: parentId });
      steps.push({ step: "parent", status: "done", message: "تم إنشاء حساب ولي الأمر" });
    }
  } catch (e) {
    steps.push({ step: "parent", status: "failed", message: stepMessage(e) });
    return finish("partial");
  }

  try {
    if (studentId) {
      credentials.push(await reissuePassword(deps, studentId));
      steps.push({ step: "student", status: "done", message: "حساب الطالب موجود من محاولة سابقة" });
    } else {
      const issued = await createMemberAccount(deps, {
        role: "student",
        name: studentName,
        ref: internal.studentRef,
        isActive: false,
      });
      studentId = issued.uid;
      credentials.push(issued);
      await writeOwned({ studentUid: studentId });
      steps.push({ step: "student", status: "done", message: "تم إنشاء حساب الطالب قيد استكمال التسجيل" });
    }
    // A resumed partial request may contain a student created by an older
    // attempt. Keep it inactive until both the guardian and halaqa links exist.
    await db.collection("users").doc(studentId).update({ isActive: false });
  } catch (e) {
    steps.push({ step: "student", status: "failed", message: stepMessage(e) });
    return finish("partial");
  }

  try {
    await adminLinkParentChildCore(db, uid, { parentId, studentId, operation: "link" });
    steps.push({ step: "link", status: "done", message: "تم ربط الطالب بولي الأمر" });
  } catch (e) {
    steps.push({ step: "link", status: "failed", message: stepMessage(e) });
    return finish("partial");
  }

  try {
    await admitStudentToHalaqaCore(db, uid, { studentId, halaqaId });
    steps.push({ step: "halaqa", status: "done", message: "تمت إضافة الطالب إلى الحلقة" });
  } catch (e) {
    if (e instanceof HttpsError && e.code === "already-exists") {
      steps.push({ step: "halaqa", status: "done", message: "الطالب عضو في الحلقة" });
    } else {
      steps.push({ step: "halaqa", status: "failed", message: stepMessage(e) });
      return finish("partial");
    }
  }

  await writeAuditLog({
    actor: adminActor(uid),
    action: AUDIT_ACTION.studentOnboard,
    targetType: AUDIT_TARGET_TYPE.user,
    targetId: studentId as string,
    metadata: {
      studentId: studentId as string,
      parentId: parentId as string,
      ...(halaqaId ? { halaqaId } : {}),
      requestId,
    },
    source: "adminOnboardStudent",
  }, db);
  return finish("completed");
}

/** Admin recovery: a new one-time password; the member must change it. */
export async function adminResetMemberPasswordCore(
  deps: OnboardingDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ userId: string; username: string; temporaryPassword: string }> {
  const uid = await requireAdminCaller(deps.db, callerUid);
  const userId = requireText(data.userId, "userId", 128);
  const user = await deps.db.collection("users").doc(userId).get();
  if (!user.exists) throw new HttpsError("not-found", "الحساب غير موجود");
  if (user.get("role") === "admin") {
    throw new HttpsError("permission-denied", "لا يمكن إعادة تعيين كلمة مرور مسؤول من هنا");
  }
  if (user.get("staffStatus") === "deleted") {
    throw new HttpsError("failed-precondition", "الحساب محذوف نهائياً");
  }
  const issued = await reissuePassword(deps, userId);
  await writeAuditLog({
    actor: adminActor(uid),
    action: AUDIT_ACTION.userCredentialReset,
    targetType: AUDIT_TARGET_TYPE.user,
    targetId: userId,
    metadata: { role: String(user.get("role") ?? "") },
    source: "adminResetMemberPassword",
  }, deps.db);
  return { userId, username: issued.username, temporaryPassword: issued.temporaryPassword };
}

/** The member replaces the temporary password on first sign-in. */
export async function completeFirstLoginCore(
  deps: OnboardingDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<{ ok: true }> {
  const uid = requireCallerUid(callerUid);
  const password = typeof data.newPassword === "string" ? data.newPassword : "";
  const privRef = deps.db.collection("userPrivate").doc(uid);
  const userRef = deps.db.collection("users").doc(uid);
  const [priv, user] = await Promise.all([privRef.get(), userRef.get()]);
  const pendingAdmin = user.get("passwordChangeRequired") === true;
  if (priv.get("mustChangePassword") !== true && !pendingAdmin) {
    throw new HttpsError("failed-precondition", "لا يلزم تغيير كلمة المرور");
  }
  if (user.exists && user.get("isActive") === false) {
    throw new HttpsError("permission-denied", "الحساب غير مفعّل");
  }
  const problem = memberPasswordProblem(password);
  if (problem) throw new HttpsError("invalid-argument", problem);
  // Flags are cleared only after Auth accepted the new password.
  await deps.auth.updateUser(uid, { password });
  const batch = deps.db.batch();
  batch.set(
    privRef,
    { mustChangePassword: false, passwordChangedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  if (pendingAdmin) batch.update(userRef, { passwordChangeRequired: false });
  await batch.commit();
  return { ok: true };
}

async function requireSupervisorCaller(db: admin.firestore.Firestore, callerUid: string | undefined) {
  const uid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, uid)) !== "supervisor") {
    throw new HttpsError("permission-denied", "هذه العملية متاحة للمشرف فقط");
  }
  return uid;
}

/**
 * Supervisor-scoped onboard: create parent (optional) + student, link, admit
 * into a halaqa the caller supervises. Does not open admin-wide callables.
 */
export async function supervisorOnboardStudentCore(
  deps: OnboardingDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<OnboardingResult> {
  const { db } = deps;
  const uid = await requireSupervisorCaller(db, callerUid);
  const requestId = typeof data.requestId === "string" ? data.requestId : "";
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    throw new HttpsError("invalid-argument", "معرّف الطلب غير صالح");
  }
  const studentName = requireName(data.studentName, "اسم الطالب");
  const parent = parseParent(data.parent);
  const halaqaId = requireText(data.halaqaId, "الحلقة", 128);
  const fingerprint = fingerprintOf(studentName, parent, halaqaId);

  const halaqa = await db.collection("halaqat").doc(halaqaId).get();
  if (!halaqa.exists) throw new HttpsError("not-found", "الحلقة غير موجودة");
  if ((halaqa.get("status") ?? "active") !== "active") {
    throw new HttpsError("failed-precondition", "الحلقة غير نشطة");
  }
  if (halaqa.get("supervisorId") !== uid) {
    throw new HttpsError("permission-denied", "الحلقة ليست ضمن نطاق إشرافك");
  }

  if (parent.mode === "existing") {
    const [user, profile] = await Promise.all([
      db.collection("users").doc(parent.parentId).get(),
      db.collection("parentProfiles").doc(parent.parentId).get(),
    ]);
    if (!user.exists || user.get("role") !== "parent" || !profile.exists) {
      throw new HttpsError("failed-precondition", "الحساب المحدد ليس ولي أمر");
    }
    if (user.get("isActive") !== true) {
      throw new HttpsError("failed-precondition", "حساب ولي الأمر غير نشط");
    }
  }

  const requestRef = db.collection(ONBOARDING_REQUESTS_COLLECTION).doc(`sup_${uid}_${requestId}`);
  const replayOf = (state: admin.firestore.DocumentData): OnboardingResult => ({
    status: "completed",
    replayed: true,
    studentId: state.studentUid ?? null,
    parentId: state.parentUid ?? null,
    halaqaId: state.halaqaId || null,
    steps: Array.isArray(state.steps) ? state.steps : [],
    credentials: [],
  });
  const checkRequest = (exists: boolean, state: admin.firestore.DocumentData) => {
    if (exists && state.fingerprint !== fingerprint) {
      throw new HttpsError("already-exists", REQUEST_ID_REUSED_MESSAGE);
    }
    return exists && state.status === "completed";
  };
  const previous = await requestRef.get();
  if (checkRequest(previous.exists, previous.data() ?? {})) return replayOf(previous.data() ?? {});

  const attemptId = randomUUID();
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(requestRef);
    const current = snap.data() ?? {};
    if (checkRequest(snap.exists, current)) return { replay: replayOf(current) };
    const leaseUntilMs = current.leaseUntil?.toMillis?.() ?? 0;
    if (current.status === "in_progress" && Date.now() < leaseUntilMs) {
      throw new HttpsError("aborted", ONBOARDING_IN_PROGRESS_MESSAGE);
    }
    tx.set(
      requestRef,
      {
        fingerprint,
        actorId: uid,
        actorRole: "supervisor",
        status: "in_progress",
        attemptId,
        leaseUntil: Timestamp.fromMillis(Date.now() + ONBOARDING_LEASE_MS),
        updatedAt: FieldValue.serverTimestamp(),
        ...(snap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );
    return { state: current };
  });
  if ("replay" in claimed) return claimed.replay as OnboardingResult;
  const state = claimed.state;

  const writeOwned = (fields: Record<string, unknown>) =>
    db.runTransaction(async (tx) => {
      const current = await tx.get(requestRef);
      if (current.get("attemptId") !== attemptId) {
        throw new HttpsError("aborted", "تولّت محاولة أحدث هذا الطلب؛ راجع نتيجتها");
      }
      tx.update(requestRef, { ...fields, updatedAt: FieldValue.serverTimestamp() });
    });

  const steps: OnboardingStep[] = [];
  const credentials: IssuedCredential[] = [];
  let parentId: string | null = parent.mode === "existing" ? parent.parentId : state.parentUid ?? null;
  let studentId: string | null = state.studentUid ?? null;

  const finish = async (status: "completed" | "partial"): Promise<OnboardingResult> => {
    await writeOwned({
      status: status === "completed" ? "completed" : "failed",
      steps,
      parentUid: parentId,
      studentUid: studentId,
      halaqaId,
      leaseUntil: FieldValue.delete(),
    });
    return { status, replayed: false, studentId, parentId, halaqaId: halaqaId || null, steps, credentials };
  };

  try {
    if (parent.mode === "existing") {
      steps.push({ step: "parent", status: "done", message: "تم اختيار ولي أمر موجود" });
    } else if (parentId) {
      credentials.push(await reissuePassword(deps, parentId));
      steps.push({ step: "parent", status: "done", message: "حساب ولي الأمر موجود من محاولة سابقة" });
    } else {
      const issued = await createMemberAccount(deps, { role: "parent", name: parent.name });
      parentId = issued.uid;
      credentials.push(issued);
      await writeOwned({ parentUid: parentId });
      steps.push({ step: "parent", status: "done", message: "تم إنشاء حساب ولي الأمر" });
    }
  } catch (e) {
    steps.push({ step: "parent", status: "failed", message: stepMessage(e) });
    return finish("partial");
  }

  try {
    if (studentId) {
      credentials.push(await reissuePassword(deps, studentId));
      steps.push({ step: "student", status: "done", message: "حساب الطالب موجود من محاولة سابقة" });
    } else {
      const issued = await createMemberAccount(deps, {
        role: "student",
        name: studentName,
        isActive: false,
      });
      studentId = issued.uid;
      credentials.push(issued);
      await writeOwned({ studentUid: studentId });
      steps.push({ step: "student", status: "done", message: "تم إنشاء حساب الطالب قيد استكمال التسجيل" });
    }
    await db.collection("users").doc(studentId).update({ isActive: false });
  } catch (e) {
    steps.push({ step: "student", status: "failed", message: stepMessage(e) });
    return finish("partial");
  }

  try {
    await adminLinkParentChildCore(
      db,
      uid,
      { parentId, studentId, operation: "link" },
      { allowSupervisor: true },
    );
    steps.push({ step: "link", status: "done", message: "تم ربط الطالب بولي الأمر" });
  } catch (e) {
    steps.push({ step: "link", status: "failed", message: stepMessage(e) });
    return finish("partial");
  }

  // Supervisor admit refuses inactive accounts (admin admit activates). Activate
  // only after parent link so a partial crash never leaves a login-ready orphan.
  try {
    await db.collection("users").doc(studentId as string).update({ isActive: true });
  } catch (e) {
    steps.push({ step: "halaqa", status: "failed", message: stepMessage(e) });
    return finish("partial");
  }

  try {
    await admitStudentToHalaqaCore(db, uid, { studentId, halaqaId });
    steps.push({ step: "halaqa", status: "done", message: "تمت إضافة الطالب إلى الحلقة" });
  } catch (e) {
    if (e instanceof HttpsError && e.code === "already-exists") {
      steps.push({ step: "halaqa", status: "done", message: "الطالب عضو في الحلقة" });
    } else {
      steps.push({ step: "halaqa", status: "failed", message: stepMessage(e) });
      return finish("partial");
    }
  }

  await writeAuditLog(
    {
      actor: supervisorActor(uid),
      action: AUDIT_ACTION.studentOnboard,
      targetType: AUDIT_TARGET_TYPE.user,
      targetId: studentId as string,
      metadata: {
        studentId: studentId as string,
        parentId: parentId as string,
        halaqaId,
        requestId,
      },
      source: "supervisorOnboardStudent",
    },
    db,
  );
  return finish("completed");
}

const deps = (): OnboardingDeps => ({ db: admin.firestore(), auth: admin.auth() });

export const adminOnboardStudent = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminOnboardStudent");
  return adminOnboardStudentCore(deps(), request.auth?.uid, (request.data ?? {}) as Record<string, unknown>);
});

export const supervisorOnboardStudent = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("supervisorOnboardStudent");
  return supervisorOnboardStudentCore(
    deps(),
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});

export const adminResetMemberPassword = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminResetMemberPassword");
  return adminResetMemberPasswordCore(deps(), request.auth?.uid, (request.data ?? {}) as Record<string, unknown>);
});

export const completeFirstLogin = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("completeFirstLogin");
  return completeFirstLoginCore(deps(), request.auth?.uid, (request.data ?? {}) as Record<string, unknown>);
});
