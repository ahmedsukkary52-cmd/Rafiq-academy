/**
 * Journey 15 — academy bulk import against the Firestore + Auth emulators:
 * a synthetic roster (staff, parents, halaqat, students) with deliberate
 * errors, then safe retries that never duplicate an account, halaqa or link.
 * Synthetic data only; temporary passwords must never reach Firestore.
 *
 * Run from repo root (after building functions):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore \
 *     "node --test --test-concurrency=1 functions/test/admin_import.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("import suite requires firestore + auth emulators and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const importer = require("../lib/accounts/academyImportFunctions.js");
const credentials = require("../lib/accounts/academyCredentials.js");

const ADMIN = "admin_imp";
const deps = { db, auth };
const IMPORT_ID = "imp_0123456789abcdef0123";
const sunday = [{ day: "الأحد", startTime: "16:00", endTime: "17:00" }];
const monday = [{ day: "الاثنين", startTime: "16:00", endTime: "17:00" }];

const ROSTER = [
  { kind: "teacher", ref: "T001", name: "أحمد علي" },
  { kind: "supervisor", ref: "S001", name: "سعاد محمد" },
  { kind: "parent", ref: "P001", name: "محمد حسن" },
  { kind: "parent", ref: "P002", name: "خالد عمر" },
  { kind: "halaqa", ref: "H001", name: "حلقة الفجر", teacherRef: "T001", supervisorRef: "S001", schedule: sunday },
  // Same normalized name as H001: must fail with the duplicate-name message.
  { kind: "halaqa", ref: "H002", name: "حَلقة-الفجر", teacherRef: "T001", schedule: monday },
  { kind: "student", ref: "ST001", name: "يوسف محمد", parentRef: "P001", halaqaRef: "H001" },
  { kind: "student", ref: "ST002", name: "عمر خالد", parentRef: "P002", halaqaRef: "H002" },
  { kind: "student", ref: "ST003", name: "زيد", parentRef: "P404" },
];

async function clearAll() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const res = await fetch(url, { method: "DELETE" });
    assert.equal(res.ok, true, `emulator clear failed: ${url}`);
  }
}

async function signIn(username, password) {
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: credentials.loginEmailFor(username), password, returnSecureToken: true }),
    },
  );
  return res.ok;
}

const run = async (rows, callerUid = ADMIN) => {
  const results = [];
  for (const row of rows) {
    results.push(await importer.adminImportAcademyRowCore(deps, callerUid, { importId: IMPORT_ID, row }));
  }
  return Object.fromEntries(results.map((r) => [r.ref, r]));
};

async function counts() {
  const users = (await db.collection("users").get()).docs.map((d) => d.data().role);
  const by = (role) => users.filter((r) => r === role).length;
  return {
    teachers: by("teacher"),
    supervisors: by("supervisor"),
    parents: by("parent"),
    students: by("student"),
    halaqat: (await db.collection("halaqat").get()).size,
    authUsers: (await auth.listUsers()).users.length,
    audits: (await db.collection("auditLogs").get()).size,
  };
}

async function allDocsJson() {
  const out = [];
  for (const name of ["users", "userPrivate", "loginUsernames", "importRows", "onboardingRequests", "halaqat", "parentProfiles", "studentProfiles", "auditLogs"]) {
    for (const d of (await db.collection(name).get()).docs) out.push(d.data());
  }
  return JSON.stringify(out);
}

test.beforeEach(async () => {
  await clearAll();
  await db.doc(`users/${ADMIN}`).set({ name: "المدير", role: "admin", isActive: true });
});

test("journey 15: import a sample roster, report every row, retry without duplicates", async () => {
  await assert.rejects(
    importer.adminImportAcademyRowCore(deps, "nobody", { importId: IMPORT_ID, row: ROSTER[0] }),
    (e) => e.code === "permission-denied",
  );
  await assert.rejects(
    importer.adminImportAcademyRowCore(deps, ADMIN, { importId: "bad", row: ROSTER[0] }),
    (e) => e.code === "invalid-argument",
  );
  await assert.rejects(
    importer.adminImportAcademyRowCore(deps, ADMIN, { importId: IMPORT_ID, row: { kind: "teacher", ref: "uid/../x", name: "س س" } }),
    (e) => e.code === "invalid-argument",
  );

  const first = await run(ROSTER);
  for (const ref of ["T001", "S001", "P001", "P002", "H001", "ST001"]) {
    assert.equal(first[ref].status, "created", `${ref}: ${first[ref].message}`);
  }
  assert.equal(first.H002.status, "failed");
  assert.match(first.H002.message, /بنفس الاسم/);
  assert.equal(first.H002.retryable, false, "needs correction, not a blind retry");
  assert.equal(first.ST002.status, "failed");
  assert.match(first.ST002.message, /الحلقة \(H002\)/);
  assert.equal(first.ST003.status, "failed");
  assert.match(first.ST003.message, /ولي الأمر \(P404\)/);

  // Every account created got a usable one-time credential.
  const issued = ["T001", "S001", "P001", "P002", "ST001"].map((ref) => first[ref].credential);
  for (const c of issued) assert.equal(await signIn(c.username, c.temporaryPassword), true);
  assert.equal(first.H001.credential, undefined);
  const dump = await allDocsJson();
  for (const c of issued) assert.equal(dump.includes(c.temporaryPassword), false, "no plaintext password stored");

  // Relationships: halaqa staff, parent link and roster are real.
  const h1 = (await db.collection("halaqat").where("name", "==", "حلقة الفجر").get()).docs[0];
  const ledger = async (ref) => (await db.doc(`importRows/${ref}`).get()).data();
  assert.equal(h1.get("teacherId"), (await ledger("T001")).id);
  assert.equal(h1.get("supervisorId"), (await ledger("S001")).id);
  const st1 = (await ledger("ST001")).id;
  assert.deepEqual(h1.get("studentIds"), [st1]);
  assert.deepEqual((await db.doc(`parentProfiles/${(await ledger("P001")).id}`).get()).get("childrenIds"), [st1]);

  const afterFirst = await counts();
  assert.deepEqual(
    { ...afterFirst, audits: undefined },
    { teachers: 1, supervisors: 1, parents: 2, students: 1, halaqat: 1, authUsers: 5, audits: undefined },
  );

  // Full retry of the same file: nothing new, finished rows report "existing".
  const second = await run(ROSTER);
  for (const ref of ["T001", "S001", "P001", "P002", "H001", "ST001"]) {
    assert.equal(second[ref].status, "existing", ref);
    assert.equal(second[ref].credential, undefined, "no silent password reset on retry");
  }
  assert.equal(second.H002.status, "failed");
  assert.deepEqual(await counts(), afterFirst);

  // Corrected file: H002 renamed, ST003's parent fixed — same refs, no duplicates.
  const corrected = ROSTER.map((r) => {
    if (r.ref === "H002") return { ...r, name: "حلقة العصر" };
    if (r.ref === "ST003") return { ...r, parentRef: "P002" };
    return r;
  });
  const third = await run(corrected);
  assert.equal(third.H002.status, "created");
  assert.equal(third.ST002.status, "created");
  assert.equal(third.ST003.status, "created");
  assert.equal(third.T001.status, "existing");
  const final = await counts();
  assert.equal(final.students, 3);
  assert.equal(final.halaqat, 2);
  assert.equal(final.parents, 2);
  assert.equal(final.authUsers, 7);

  // A created record cannot change meaning under the same ref.
  await assert.rejects(
    importer.adminImportAcademyRowCore(deps, ADMIN, { importId: IMPORT_ID, row: { ...ROSTER[0], name: "شخص آخر" } }),
    (e) => e.code === "already-exists" && /مرجعاً جديداً/.test(e.message),
  );
});

test("an account created just before a crash is finished on retry with a fresh credential, not duplicated", async () => {
  const [teacher] = ROSTER;
  const first = await run([teacher]);
  const uid = (await db.doc("importRows/T001").get()).get("id");
  // Simulate a crash after account creation but before the row was marked done,
  // retried once the attempt's claim lease has expired (the lease stays 2 min).
  const expired = admin.firestore.Timestamp.fromMillis(Date.now() - importer.IMPORT_LEASE_MS - 1000);
  await db.doc("importRows/T001").update({ status: "in_progress", leaseUntil: expired, updatedAt: expired });

  const retry = await run([teacher]);
  assert.equal(retry.T001.status, "created");
  assert.notEqual(retry.T001.credential.temporaryPassword, first.T001.credential.temporaryPassword);
  assert.equal(retry.T001.credential.username, first.T001.credential.username);
  assert.equal((await db.doc("importRows/T001").get()).get("id"), uid);
  assert.equal((await counts()).teachers, 1);
  assert.equal(await signIn(retry.T001.credential.username, retry.T001.credential.temporaryPassword), true);
  assert.equal(await signIn(first.T001.credential.username, first.T001.credential.temporaryPassword), false);
});

test("a live claim blocks a retry by the same admin until its lease expires", async () => {
  const [teacher] = ROSTER;
  const first = await run([teacher]);
  assert.equal(importer.IMPORT_LEASE_MS, 2 * 60 * 1000, "the claim lease stays two minutes");
  const live = admin.firestore.Timestamp.fromMillis(Date.now() + importer.IMPORT_LEASE_MS);
  await db.doc("importRows/T001").update({ status: "in_progress", leaseUntil: live });
  await assert.rejects(
    importer.adminImportAcademyRowCore(deps, ADMIN, { importId: IMPORT_ID, row: teacher }),
    (e) => e.code === "aborted" && /انتظر النتيجة/.test(e.message),
  );
  // Nothing ran: one account, the row is untouched and the first credential still signs in.
  assert.equal((await counts()).teachers, 1);
  assert.equal((await db.doc("importRows/T001").get()).get("status"), "in_progress");
  assert.equal(await signIn(first.T001.credential.username, first.T001.credential.temporaryPassword), true);
});

test("a row being processed by another admin is not run twice", async () => {
  await db.doc("users/admin_two").set({ name: "مسؤول", role: "admin", isActive: true });
  await db.doc("importRows/T001").set({
    kind: "teacher",
    status: "in_progress",
    actorId: "admin_two",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await assert.rejects(
    importer.adminImportAcademyRowCore(deps, ADMIN, { importId: IMPORT_ID, row: ROSTER[0] }),
    (e) => e.code === "aborted",
  );
  assert.equal((await counts()).teachers, 0);
});
