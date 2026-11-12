/**
 * Admin student onboarding against the Firestore + Auth emulators:
 * parent + student accounts with generated academy usernames, parent link,
 * halaqa admission, one-time credentials that actually sign in, mandatory
 * first-login change, Admin recovery, and a safe resumable retry.
 * Synthetic data only; no plaintext password may reach Firestore.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore \
 *     "node --test --test-concurrency=1 functions/test/admin_onboarding.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { randomBytes } from "node:crypto";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("onboarding suite requires firestore + auth emulators and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const onboarding = require("../lib/accounts/onboardingFunctions.js");
const credentials = require("../lib/accounts/academyCredentials.js");

const ADMIN = "admin_onb";
const HALAQA = "halaqa_onb";
const deps = { db, auth };
const requestId = () => `req_${randomBytes(10).toString("hex")}`;

async function clearAll() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const res = await fetch(url, { method: "DELETE" });
    assert.equal(res.ok, true, `emulator clear failed: ${url}`);
  }
}

async function seedBase() {
  const batch = db.batch();
  batch.set(db.doc(`users/${ADMIN}`), { name: "المدير", role: "admin", isActive: true });
  batch.set(db.doc(`halaqat/${HALAQA}`), {
    name: "حلقة الفجر",
    status: "active",
    teacherId: "t1",
    supervisorId: "s1",
    studentIds: [],
  });
  await batch.commit();
}

const data = async (path) => (await db.doc(path).get()).data();

async function signIn(email, password) {
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  return res.ok;
}

/** Every document in the collections onboarding touches, as one JSON string. */
async function dumpTouchedCollections() {
  const names = ["users", "userPrivate", "loginUsernames", "onboardingRequests", "auditLogs", "studentProfiles", "parentProfiles"];
  const docs = [];
  for (const name of names) {
    const snap = await db.collection(name).get();
    for (const d of snap.docs) docs.push({ path: d.ref.path, data: d.data() });
  }
  return JSON.stringify(docs);
}

test.beforeEach(async () => {
  await clearAll();
  await seedBase();
});

test("journey 3: new parent + student, linked, admitted, credentials sign in, nothing secret stored", async () => {
  const result = await onboarding.adminOnboardStudentCore(deps, ADMIN, {
    requestId: requestId(),
    studentName: "عبد الله أحمد",
    parent: { mode: "new", name: "أحمد محمود" },
    halaqaId: HALAQA,
  });

  assert.equal(result.status, "completed");
  assert.deepEqual(
    result.steps.map((s) => [s.step, s.status]),
    [["parent", "done"], ["student", "done"], ["link", "done"], ["halaqa", "done"]],
  );
  assert.equal(result.credentials.length, 2);
  const [parentCred, studentCred] = result.credentials;
  assert.equal(parentCred.role, "parent");
  assert.equal(studentCred.role, "student");
  assert.match(parentCred.username, /^pr\d{6}$/);
  assert.match(studentCred.username, /^st\d{6}$/);
  for (const c of result.credentials) {
    assert.equal(c.temporaryPassword.length, credentials.TEMP_PASSWORD_LENGTH);
    assert.match(c.temporaryPassword, /[A-Za-z]/);
    assert.match(c.temporaryPassword, /[0-9]/);
  }

  // Relationships.
  const { studentId, parentId } = result;
  assert.deepEqual((await data(`parentProfiles/${parentId}`)).childrenIds, [studentId]);
  assert.equal((await data(`studentProfiles/${studentId}`)).halaqaId, HALAQA);
  assert.deepEqual((await data(`halaqat/${HALAQA}`)).studentIds, [studentId]);
  const student = await data(`users/${studentId}`);
  assert.equal(student.role, "student");
  assert.equal(student.isActive, true);
  assert.equal(student.nameNormalized.length > 0, true);

  // Credentials: private, flagged for first-login change, username indexed.
  const priv = await data(`userPrivate/${studentId}`);
  assert.equal(priv.loginUsername, studentCred.username);
  assert.equal(priv.emailSource, "generated_login");
  assert.equal(priv.mustChangePassword, true);
  assert.equal(priv.email, credentials.loginEmailFor(studentCred.username));
  assert.deepEqual(
    { uid: studentId, role: "student", status: "active" },
    (({ uid, role, status }) => ({ uid, role, status }))(await data(`loginUsernames/${studentCred.username}`)),
  );

  // The one-time passwords really work against Firebase Auth.
  assert.equal(await signIn(credentials.loginEmailFor(studentCred.username), studentCred.temporaryPassword), true);
  assert.equal(await signIn(credentials.loginEmailFor(parentCred.username), parentCred.temporaryPassword), true);

  // Audit trail and no plaintext password anywhere in Firestore.
  const audits = await db.collection("auditLogs").where("action", "==", "student_onboard").get();
  assert.equal(audits.size, 1);
  assert.equal(audits.docs[0].get("targetId"), studentId);
  const everything = await dumpTouchedCollections();
  for (const c of result.credentials) assert.equal(everything.includes(c.temporaryPassword), false);
});

test("existing parent is linked, not duplicated; replay of a completed request returns no credentials", async () => {
  const first = await onboarding.adminOnboardStudentCore(deps, ADMIN, {
    requestId: requestId(),
    studentName: "سارة",
    parent: { mode: "new", name: "خالد" },
  });
  assert.equal(first.status, "completed");
  assert.equal(first.steps.find((s) => s.step === "halaqa").status, "skipped");

  const id = requestId();
  const input = {
    requestId: id,
    studentName: "يوسف",
    parent: { mode: "existing", parentId: first.parentId },
    halaqaId: HALAQA,
  };
  const second = await onboarding.adminOnboardStudentCore(deps, ADMIN, input);
  assert.equal(second.status, "completed");
  assert.equal(second.parentId, first.parentId);
  assert.deepEqual(second.credentials.map((c) => c.role), ["student"]);
  assert.deepEqual(
    [...(await data(`parentProfiles/${first.parentId}`)).childrenIds].sort(),
    [first.studentId, second.studentId].sort(),
  );

  const parents = await db.collection("users").where("role", "==", "parent").get();
  assert.equal(parents.size, 1);

  const replay = await onboarding.adminOnboardStudentCore(deps, ADMIN, input);
  assert.equal(replay.replayed, true);
  assert.equal(replay.studentId, second.studentId);
  assert.deepEqual(replay.credentials, []);
  assert.equal((await db.collection("users").where("role", "==", "student").get()).size, 2);

  await assert.rejects(
    onboarding.adminOnboardStudentCore(deps, ADMIN, { ...input, studentName: "اسم آخر" }),
    (e) => e.code === "already-exists" && e.message === onboarding.REQUEST_ID_REUSED_MESSAGE,
  );
});

test("safe retry: a failure mid-flow resumes with the accounts already created", async () => {
  let creates = 0;
  const flakyAuth = {
    createUser: async (props) => {
      creates += 1;
      if (creates === 2) throw new Error("simulated auth outage");
      return auth.createUser(props);
    },
    updateUser: (uid, props) => auth.updateUser(uid, props),
    deleteUser: (uid) => auth.deleteUser(uid),
  };
  const input = {
    requestId: requestId(),
    studentName: "مريم",
    parent: { mode: "new", name: "فاطمة" },
    halaqaId: HALAQA,
  };

  const partial = await onboarding.adminOnboardStudentCore({ db, auth: flakyAuth }, ADMIN, input);
  assert.equal(partial.status, "partial");
  assert.deepEqual(partial.steps.map((s) => [s.step, s.status]), [["parent", "done"], ["student", "failed"]]);
  assert.equal(partial.studentId, null);
  assert.equal(partial.credentials.length, 1);
  // The failed student account left nothing behind (reservation released).
  assert.equal((await db.collection("loginUsernames").get()).size, 1);
  assert.equal((await db.collection("users").where("role", "==", "student").get()).size, 0);

  const resumed = await onboarding.adminOnboardStudentCore(deps, ADMIN, input);
  assert.equal(resumed.status, "completed");
  assert.equal(resumed.parentId, partial.parentId);
  assert.equal(resumed.steps[0].message, "حساب ولي الأمر موجود من محاولة سابقة");
  assert.deepEqual(resumed.credentials.map((c) => c.role), ["parent", "student"]);
  assert.equal((await db.collection("users").where("role", "==", "parent").get()).size, 1);

  // The re-issued parent password replaces the first one.
  const parentEmail = credentials.loginEmailFor(resumed.credentials[0].username);
  assert.equal(await signIn(parentEmail, partial.credentials[0].temporaryPassword), false);
  assert.equal(await signIn(parentEmail, resumed.credentials[0].temporaryPassword), true);
});

test("first login replaces the temporary password; Admin recovery issues a new one", async () => {
  const result = await onboarding.adminOnboardStudentCore(deps, ADMIN, {
    requestId: requestId(),
    studentName: "عمر",
    parent: { mode: "new", name: "حسن" },
  });
  const student = result.credentials.find((c) => c.role === "student");
  const email = credentials.loginEmailFor(student.username);

  await assert.rejects(
    onboarding.completeFirstLoginCore(deps, result.studentId, { newPassword: "short1" }),
    (e) => e.code === "invalid-argument",
  );
  await assert.rejects(
    onboarding.completeFirstLoginCore(deps, result.studentId, { newPassword: "onlyletters" }),
    (e) => e.code === "invalid-argument",
  );
  await onboarding.completeFirstLoginCore(deps, result.studentId, { newPassword: "NewPass2026" });
  assert.equal((await data(`userPrivate/${result.studentId}`)).mustChangePassword, false);
  assert.equal(await signIn(email, student.temporaryPassword), false);
  assert.equal(await signIn(email, "NewPass2026"), true);
  await assert.rejects(
    onboarding.completeFirstLoginCore(deps, result.studentId, { newPassword: "Another2026" }),
    (e) => e.code === "failed-precondition",
  );

  // Recovery: Admin only, never for admins, audited, forces a change again.
  await assert.rejects(
    onboarding.adminResetMemberPasswordCore(deps, result.parentId, { userId: result.studentId }),
    (e) => e.code === "permission-denied",
  );
  await assert.rejects(
    onboarding.adminResetMemberPasswordCore(deps, ADMIN, { userId: ADMIN }),
    (e) => e.code === "permission-denied",
  );
  const reset = await onboarding.adminResetMemberPasswordCore(deps, ADMIN, { userId: result.studentId });
  assert.equal(reset.username, student.username);
  assert.equal(await signIn(email, "NewPass2026"), false);
  assert.equal(await signIn(email, reset.temporaryPassword), true);
  assert.equal((await data(`userPrivate/${result.studentId}`)).mustChangePassword, true);
  const audits = await db.collection("auditLogs").where("action", "==", "user_credential_reset").get();
  assert.equal(audits.size, 1);
  assert.equal((await dumpTouchedCollections()).includes(reset.temporaryPassword), false);
});

test("a newly provisioned Admin holds no authority until the first-login change succeeds", async () => {
  const { adminProvisionUser } = require("../lib/admin/adminProvisionUser.js");
  const callerContext = require("../lib/authority/callerContext.js");
  const previous = process.env.FUNCTIONS_EMULATOR;
  process.env.FUNCTIONS_EMULATOR = "true";
  let uid;
  let teacherUid;
  try {
    ({ uid } = await adminProvisionUser.run({
      auth: { uid: ADMIN },
      data: { email: "new.admin@academy.test", password: "Initial1", name: "مسؤول جديد", role: "admin" },
    }));
    ({ uid: teacherUid } = await adminProvisionUser.run({
      auth: { uid: ADMIN },
      data: { email: "new.teacher@academy.test", password: "Initial1", name: "معلم", role: "teacher" },
    }));
  } finally {
    if (previous === undefined) delete process.env.FUNCTIONS_EMULATOR;
    else process.env.FUNCTIONS_EMULATOR = previous;
  }

  assert.equal((await data(`users/${uid}`)).passwordChangeRequired, true);
  assert.equal((await data(`userPrivate/${uid}`)).mustChangePassword, true);
  // Only new Admins are forced; other provisioned roles keep today's contract.
  assert.equal((await data(`users/${teacherUid}`)).passwordChangeRequired, undefined);
  assert.equal((await data(`userPrivate/${teacherUid}`)).mustChangePassword, undefined);
  // Existing Admins are untouched.
  assert.equal((await data(`users/${ADMIN}`)).passwordChangeRequired, undefined);

  // Every server-side Admin check refuses the pending Admin.
  assert.equal(await callerContext.loadCallerRole(db, uid), "");
  await assert.rejects(
    onboarding.adminOnboardStudentCore(deps, uid, {
      requestId: requestId(),
      studentName: "طالب",
      parent: { mode: "new", name: "ولي" },
    }),
    (e) => e.code === "permission-denied",
  );
  await assert.rejects(
    onboarding.adminResetMemberPasswordCore(deps, uid, { userId: teacherUid }),
    (e) => e.code === "permission-denied",
  );

  // A rejected change leaves the account pending and the old password valid.
  await assert.rejects(
    onboarding.completeFirstLoginCore(deps, uid, { newPassword: "short1" }),
    (e) => e.code === "invalid-argument",
  );
  assert.equal((await data(`users/${uid}`)).passwordChangeRequired, true);
  assert.equal(await signIn("new.admin@academy.test", "Initial1"), true);

  await onboarding.completeFirstLoginCore(deps, uid, { newPassword: "Admin2026x" });
  assert.equal((await data(`users/${uid}`)).passwordChangeRequired, false);
  assert.equal((await data(`userPrivate/${uid}`)).mustChangePassword, false);
  assert.equal(await signIn("new.admin@academy.test", "Initial1"), false);
  assert.equal(await signIn("new.admin@academy.test", "Admin2026x"), true);
  assert.equal(await callerContext.loadCallerRole(db, uid), "admin");
  await assert.rejects(
    onboarding.completeFirstLoginCore(deps, uid, { newPassword: "Another2026" }),
    (e) => e.code === "failed-precondition",
  );
  // An existing Admin cannot use the first-login path to change a password.
  await assert.rejects(
    onboarding.completeFirstLoginCore(deps, ADMIN, { newPassword: "Another2026" }),
    (e) => e.code === "failed-precondition",
  );
  const dump = await dumpTouchedCollections();
  for (const secret of ["Initial1", "Admin2026x"]) assert.equal(dump.includes(secret), false);
});

test("name backfill: dry run by default, then stamps legacy accounts once (resumable)", async () => {
  const directory = require("../lib/accounts/memberDirectory.js");
  await db.doc("users/legacy1").set({ name: "أمينة إبراهيم", role: "parent", isActive: true });
  await db.doc("users/legacy2").set({ name: "زكريا", role: "parent", isActive: true });

  const dry = await directory.adminBackfillUserNameNormalizedCore(db, ADMIN, { pageSize: 2 });
  assert.equal(dry.dryRun, true);
  assert.equal(dry.stamped > 0, true);
  assert.equal((await data("users/legacy1")).nameNormalized, undefined);

  let cursor = null;
  let stamped = 0;
  do {
    const page = await directory.adminBackfillUserNameNormalizedCore(db, ADMIN, { pageSize: 2, cursor, dryRun: false });
    stamped += page.stamped;
    cursor = page.nextCursor;
  } while (cursor);
  assert.equal(stamped, 3);
  assert.equal((await data("users/legacy1")).nameNormalized, directory.nameNormalizedPatch({ name: "أمينة إبراهيم" }));

  const again = await directory.adminBackfillUserNameNormalizedCore(db, ADMIN, { pageSize: 50, dryRun: false });
  assert.equal(again.stamped, 0);
  const hits = await db
    .collection("users")
    .where("role", "==", "parent")
    .orderBy("nameNormalized")
    .startAt("امينه")
    .endAt("امينه\uf8ff")
    .get();
  assert.deepEqual(hits.docs.map((d) => d.id), ["legacy1"]);
});

test("guards: admin only, valid parent, active halaqa, no contact info in names", async () => {
  const base = { requestId: requestId(), studentName: "طالب", parent: { mode: "new", name: "ولي" } };
  await db.doc("users/t1").set({ name: "معلم", role: "teacher", isActive: true });
  await assert.rejects(
    onboarding.adminOnboardStudentCore(deps, "t1", base),
    (e) => e.code === "permission-denied",
  );
  await assert.rejects(
    onboarding.adminOnboardStudentCore(deps, ADMIN, { ...base, parent: { mode: "existing", parentId: "t1" } }),
    (e) => e.code === "failed-precondition",
  );
  await db.doc("halaqat/archived").set({ name: "قديمة", status: "archived", studentIds: [] });
  await assert.rejects(
    onboarding.adminOnboardStudentCore(deps, ADMIN, { ...base, halaqaId: "archived" }),
    (e) => e.code === "failed-precondition",
  );
  await assert.rejects(
    onboarding.adminOnboardStudentCore(deps, ADMIN, { ...base, studentName: "اتصل 01012345678" }),
    (e) => e.code === "invalid-argument",
  );
  await assert.rejects(
    onboarding.adminOnboardStudentCore(deps, ADMIN, { ...base, requestId: "short" }),
    (e) => e.code === "invalid-argument",
  );
  // Nothing was created by any rejected call.
  assert.equal((await auth.listUsers()).users.length, 0);
  assert.equal((await db.collection("loginUsernames").get()).size, 0);
});
