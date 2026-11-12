/**
 * Academy relationships end to end against the Firestore + Auth emulators,
 * following the owner's example: P-001 with S-001 and S-002 imported, S-003
 * added later in the app, T-001 / V-001 / A-001 on H-001, an assistant
 * teacher, a temporary cover, and account recovery. Synthetic data only.
 *
 * Run from repo root (after building functions):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore \
 *     "node --test --test-concurrency=1 functions/test/academy_relationships.emulator.test.mjs"
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
  throw new Error("relationships suite requires firestore + auth emulators and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const importer = require("../lib/accounts/academyImportFunctions.js");
const onboarding = require("../lib/accounts/onboardingFunctions.js");
const accounts = require("../lib/accounts/memberAccountFunctions.js");
const credentials = require("../lib/accounts/academyCredentials.js");
const parentLink = require("../lib/relationships/parentLinkFunctions.js");
const staff = require("../lib/staff/staffLifecycleFunctions.js");
const assist = require("../lib/staff/halaqaAssistantFunctions.js");
const sessions = require("../lib/sessions/sessionRecordFunctions.js");
const records = require("../lib/sessions/sessionRecords.js");

const ADMIN = "admin_rel";
const deps = { db, auth };
const IMPORT_ID = "imp_0123456789abcdef0456";
const MONDAY = "2026-09-28";
const monday = [{ day: "الاثنين", startTime: "16:00", endTime: "17:00" }];
const requestId = () => `req_${randomBytes(10).toString("hex")}`;

const ROSTER = [
  { kind: "teacher", ref: "T-001", name: "أحمد المعلم" },
  { kind: "teacher", ref: "T-002", name: "محمود المعلم" },
  { kind: "supervisor", ref: "V-001", name: "سعاد المشرفة" },
  { kind: "supervisor", ref: "V-002", name: "منى المشرفة" },
  { kind: "assistant", ref: "A-001", name: "يوسف المساعد" },
  { kind: "assistant", ref: "A-002", name: "زيد المساعد" },
  { kind: "parent", ref: "P-001", name: "أحمد محمد" },
  {
    kind: "halaqa", ref: "H-001", name: "حلقة الفجر",
    teacherRef: "T-001", supervisorRef: "V-001", assistantRef: "A-001", schedule: monday,
  },
  { kind: "halaqa", ref: "H-002", name: "حلقة العصر", teacherRef: "T-002", schedule: [{ day: "الثلاثاء", startTime: "16:00", endTime: "17:00" }] },
  { kind: "student", ref: "S-001", name: "سالم أحمد", parentRef: "P-001", halaqaRef: "H-001" },
  { kind: "student", ref: "S-002", name: "سارة أحمد", parentRef: "P-001", halaqaRef: "H-001" },
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

const data = async (path) => (await db.doc(path).get()).data();

async function rejects(promise, code, messagePart) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code, `expected ${code}, got ${e.code}: ${e.message}`);
    if (messagePart) assert.match(e.message, new RegExp(messagePart));
    return true;
  });
}

async function runImport(rows = ROSTER) {
  const out = {};
  for (const row of rows) {
    out[row.ref] = await importer.adminImportAcademyRowCore(deps, ADMIN, { importId: IMPORT_ID, row });
  }
  return out;
}

/** academy code → Firebase uid / halaqa id, read from the shared ledger. */
async function idOf(ref) {
  return (await data(`importRows/${ref}`)).id;
}

async function roleCounts() {
  const roles = (await db.collection("users").get()).docs.map((d) => d.get("role"));
  return Object.fromEntries(
    ["teacher", "supervisor", "assistant_teacher", "parent", "student"].map((r) => [r, roles.filter((x) => x === r).length]),
  );
}

async function history(subjectId) {
  const snap = await db
    .collection("relationshipHistory")
    .where("subjectIds", "array-contains", subjectId)
    .get();
  return snap.docs.map((d) => d.data());
}

test.beforeEach(async () => {
  await clearAll();
  await db.doc(`users/${ADMIN}`).set({ name: "المدير", role: "admin", isActive: true });
  const results = await runImport();
  for (const [ref, r] of Object.entries(results)) {
    assert.equal(r.status, "created", `${ref}: ${r.message}`);
  }
});

test("1-4, 12-13: one parent, many children; S-003 added later without re-import; codes never duplicate", async () => {
  const parentId = await idOf("P-001");
  const [s1, s2] = [await idOf("S-001"), await idOf("S-002")];
  const halaqaId = await idOf("H-001");

  // The academy code, the Firebase uid and the relationship are distinct.
  assert.equal((await data(`users/${parentId}`)).academyRef, "P-001");
  assert.equal((await data(`users/${s1}`)).academyRef, "S-001");
  assert.equal((await data(`halaqat/${halaqaId}`)).academyRef, "H-001");
  assert.notEqual(parentId, "P-001");
  assert.deepEqual((await data(`parentProfiles/${parentId}`)).childrenIds, [s1, s2]);

  // S-003 later, from the app: existing parent selected, halaqa selected.
  const later = await onboarding.adminOnboardStudentCore(deps, ADMIN, {
    requestId: requestId(),
    studentName: "عمر أحمد",
    parent: { mode: "existing", parentId },
    halaqaId,
  });
  assert.equal(later.status, "completed");
  assert.equal(later.credentials.length, 1, "only the new student receives credentials");
  const s3 = later.studentId;
  assert.equal(later.credentials[0].academyRef, "S-003", "next free code skips imported S-001/S-002");
  assert.equal((await data(`users/${s3}`)).academyRef, "S-003");
  assert.deepEqual((await data(`parentProfiles/${parentId}`)).childrenIds, [s1, s2, s3]);
  assert.deepEqual((await data(`halaqat/${halaqaId}`)).studentIds, [s1, s2, s3]);
  assert.equal(await signIn(later.credentials[0].username, later.credentials[0].temporaryPassword), true);

  // Parent history shows every child link, from the parent's side and the child's.
  const parentHistory = await history(parentId);
  assert.deepEqual(
    parentHistory.filter((h) => h.kind === "parent_child").map((h) => h.studentId).sort(),
    [s1, s2, s3].sort(),
  );
  assert.ok((await history(s3)).some((h) => h.kind === "halaqa_membership" && h.halaqaId === halaqaId));

  // A later import repeating S-003 for the same person adopts it, never duplicates.
  const before = await roleCounts();
  const repeat = await runImport([
    { kind: "student", ref: "S-003", name: "عمر أحمد", parentRef: "P-001", halaqaRef: "H-001" },
  ]);
  assert.equal(repeat["S-003"].status, "existing");
  assert.equal(repeat["S-003"].credential, undefined);
  // The same code for a different person is refused.
  await rejects(
    runImport([{ kind: "student", ref: "S-003", name: "شخص آخر", parentRef: "P-001" }]),
    "already-exists",
    "S-003",
  );
  await rejects(
    runImport([{ kind: "parent", ref: "P-001", name: "ولي أمر مختلف" }]),
    "already-exists",
    "P-001",
  );

  // Retrying the whole import creates nothing and issues no passwords.
  const retry = await runImport();
  for (const r of Object.values(retry)) {
    assert.equal(r.status, "existing", `${r.ref}: ${r.message}`);
    assert.equal(r.credential, undefined);
  }
  assert.deepEqual(await roleCounts(), before);
  assert.deepEqual((await data(`parentProfiles/${parentId}`)).childrenIds, [s1, s2, s3]);
});

test("halaqat created in the app get the next free H-code from the shared ledger", async () => {
  const halaqat = require("../lib/halaqa/halaqaScheduleFunctions.js");
  const [t1, t2] = [await idOf("T-001"), await idOf("T-002")];
  const slot = (day) => [{ day, startTime: "18:00", endTime: "19:00" }];
  const counter = async () => (await data("academyRefCounters/halaqa"))?.last;
  const halaqaCount = async () => (await db.collection("halaqat").get()).size;
  assert.equal(await counter(), 2, "the imported roster codes H-001/H-002 moved the counter past them");

  // Imported H-001 / H-002 are skipped; the code is stamped in the create transaction.
  const rid = requestId();
  const first = await halaqat.adminCreateHalaqaCore(db, ADMIN, {
    name: "حلقة المغرب", teacherId: t1, schedule: slot("الأربعاء"), requestId: rid,
  });
  assert.equal(first.academyRef, "H-003");
  assert.equal((await data(`halaqat/${first.halaqaId}`)).academyRef, "H-003");
  const ledger = await data("importRows/H-003");
  assert.equal(ledger.kind, "halaqa");
  assert.equal(ledger.id, first.halaqaId);
  assert.equal(ledger.origin, "manual");
  assert.equal(ledger.status, "done");
  assert.equal(await counter(), 3);
  const audit = await db.collection("auditLogs").where("targetId", "==", first.halaqaId).get();
  assert.equal(audit.docs[0].get("metadata").academyRef, "H-003");

  // A replayed request returns the same halaqa and code and consumes nothing.
  const before = await halaqaCount();
  const replay = await halaqat.adminCreateHalaqaCore(db, ADMIN, {
    name: "حلقة المغرب", teacherId: t1, schedule: slot("الأربعاء"), requestId: rid,
  });
  assert.deepEqual([replay.halaqaId, replay.academyRef, replay.alreadyExisted], [first.halaqaId, "H-003", true]);
  assert.equal(await halaqaCount(), before);
  assert.equal(await counter(), 3);

  // A refused create (duplicate name) consumes no code.
  await rejects(
    halaqat.adminCreateHalaqaCore(db, ADMIN, {
      name: "حلقة المغرب", teacherId: t2, schedule: slot("الخميس"), requestId: requestId(),
    }),
    "already-exists",
  );
  assert.equal(await counter(), 3);
  assert.equal(await data("importRows/H-004"), undefined);

  // Concurrent creates never share a code.
  const concurrent = await Promise.all(
    [["حلقة أ", t1, "الخميس"], ["حلقة ب", t2, "الخميس"], ["حلقة ج", t1, "الجمعة"], ["حلقة د", t2, "الجمعة"]].map(
      ([name, teacherId, day]) =>
        halaqat.adminCreateHalaqaCore(db, ADMIN, { name, teacherId, schedule: slot(day), requestId: requestId() }),
    ),
  );
  assert.deepEqual(concurrent.map((r) => r.academyRef).sort(), ["H-004", "H-005", "H-006", "H-007"]);
  assert.equal(await counter(), 7);

  // An imported roster code is kept as given and later app codes skip it.
  const imported = await runImport([
    { kind: "halaqa", ref: "H-008", name: "حلقة الضحى", teacherRef: "T-002", schedule: slot("السبت") },
  ]);
  assert.equal(imported["H-008"].status, "created");
  assert.equal((await data(`halaqat/${await idOf("H-008")}`)).academyRef, "H-008");
  // Approved behaviour (F2): an app-format roster code moves the counter past
  // it (7 -> 8), so app codes continue after the roster's highest code.
  assert.equal(await counter(), 8, "an imported app-format roster code moves the counter past it");
  const next = await halaqat.adminCreateHalaqaCore(db, ADMIN, {
    name: "حلقة العشاء", teacherId: t1, schedule: slot("الأحد"), requestId: requestId(),
  });
  assert.equal(next.academyRef, "H-009");
  assert.equal(await counter(), 9);

  // A later import repeating an app-created code for the same halaqa adopts it.
  const countBefore = await halaqaCount();
  const adopt = await runImport([
    { kind: "halaqa", ref: "H-003", name: "حلقة المغرب", teacherRef: "T-001", schedule: slot("الأربعاء") },
  ]);
  assert.equal(adopt["H-003"].status, "existing");
  assert.equal(await halaqaCount(), countBefore);
  assert.equal(await counter(), 9, "adopting a lower code never moves the counter");

  // Existing codes are untouched.
  assert.equal((await data(`halaqat/${await idOf("H-001")}`)).academyRef, "H-001");
  assert.equal((await data(`halaqat/${await idOf("H-002")}`)).academyRef, "H-002");
  const codes = (await db.collection("halaqat").get()).docs.map((d) => d.get("academyRef"));
  assert.equal(new Set(codes).size, codes.length, "every halaqa code is unique");
  assert.ok(codes.every((c) => /^H-\d{3}$/.test(c)));
});

test("F2: roster codes advance the counter once; codes are never reused; concurrent allocation stays unique", async () => {
  const counter = async () => (await data("academyRefCounters/parent"))?.last;
  const newParent = async (name) =>
    (await accounts.adminCreateMemberAccountCore(deps, ADMIN, { role: "parent", name })).uid;
  const refOf = async (uid) => (await data(`users/${uid}`)).academyRef;
  const parentDocs = async () => (await db.collection("users").where("role", "==", "parent").get()).docs;
  const past = () => admin.firestore.Timestamp.fromMillis(Date.now() - importer.IMPORT_LEASE_MS - 1000);
  assert.equal(await counter(), 1, "the imported P-001 moved the counter");

  // (a) A roster code moves the counter past it; app codes continue after it.
  const imported = await runImport([{ kind: "parent", ref: "P-005", name: "ولي أمر مستورد" }]);
  assert.equal(imported["P-005"].status, "created");
  assert.equal(await counter(), 5);
  assert.equal(await refOf(await newParent("ولي أمر أول")), "P-006");
  // A code already held in the shared ledger (written before imports moved the
  // counter) is skipped and never overwritten.
  await db.doc("importRows/P-007").set({ kind: "parent", status: "done", id: "legacy_parent_007", name: "سجل سابق" });
  assert.equal(await refOf(await newParent("ولي أمر ثان")), "P-008");
  assert.equal((await data("importRows/P-007")).id, "legacy_parent_007");
  assert.equal(await counter(), 8);
  // A lower roster code imported later keeps its code and never moves the counter back.
  const lower = await runImport([{ kind: "parent", ref: "P-003", name: "ولي أمر ثالث" }]);
  assert.equal(lower["P-003"].status, "created");
  assert.equal(await counter(), 8);
  assert.equal(await refOf(await newParent("ولي أمر رابع")), "P-009");

  // (b) Retrying the same import row never advances the counter again ...
  await runImport([{ kind: "parent", ref: "P-020", name: "ولي أمر عشرون" }]);
  assert.equal(await counter(), 20);
  const again = await runImport([{ kind: "parent", ref: "P-020", name: "ولي أمر عشرون" }]);
  assert.equal(again["P-020"].status, "existing");
  assert.equal(await counter(), 20);
  // ... nor after a crash once its claim lease has expired (account already created) ...
  await db.doc("importRows/P-020").update({ status: "in_progress", leaseUntil: past(), updatedAt: past() });
  const resumed = await runImport([{ kind: "parent", ref: "P-020", name: "ولي أمر عشرون" }]);
  assert.equal(resumed["P-020"].status, "created");
  assert.equal(await counter(), 20);
  // ... nor after a crash between the claim (which moved the counter) and the account.
  await db.doc("academyRefCounters/parent").update({ last: 21 });
  await db.doc("importRows/P-021").set({
    kind: "parent",
    status: "in_progress",
    actorId: ADMIN,
    importId: IMPORT_ID,
    leaseUntil: past(),
    updatedAt: past(),
  });
  const recovered = await runImport([{ kind: "parent", ref: "P-021", name: "ولي أمر واحد وعشرون" }]);
  assert.equal(recovered["P-021"].status, "created");
  assert.equal(await counter(), 21);
  const resumedRefs = (await parentDocs()).map((d) => d.get("academyRef")).filter((r) => r === "P-020" || r === "P-021");
  assert.deepEqual(resumedRefs.sort(), ["P-020", "P-021"], "each resumed row has exactly one account");

  // (c) A roster import racing app-created parents: unique codes, consistent counter.
  await Promise.all([
    runImport([{ kind: "parent", ref: "P-030", name: "ولي أمر متزامن" }]),
    newParent("متزامن أ"),
    newParent("متزامن ب"),
    newParent("متزامن ج"),
  ]);
  const docs = await parentDocs();
  const refs = docs.map((d) => d.get("academyRef"));
  assert.equal(new Set(refs).size, refs.length, "no parent code is shared");
  assert.ok(refs.includes("P-030"));
  assert.equal(
    await counter(),
    Math.max(...refs.map((r) => Number(r.slice(2)))),
    "the counter equals the highest issued code",
  );
  for (const d of docs) {
    assert.equal((await data(`importRows/${d.get("academyRef")}`)).id, d.id, `${d.get("academyRef")} points at its account`);
  }
});

test("guardian changes: second guardian, atomic replacement, history kept", async () => {
  const s1 = await idOf("S-001");
  const p1 = await idOf("P-001");
  const p2 = (await accounts.adminCreateMemberAccountCore(deps, ADMIN, { role: "parent", name: "خالد الخال" })).uid;
  assert.equal((await data(`users/${p2}`)).academyRef, "P-002");

  // A child may have more than one guardian.
  await parentLink.adminLinkParentChildCore(db, ADMIN, { parentId: p2, studentId: s1, operation: "link" });
  const guardians = await db.collection("parentProfiles").where("childrenIds", "array-contains", s1).get();
  assert.deepEqual(guardians.docs.map((d) => d.id).sort(), [p1, p2].sort());

  const p3 = (await accounts.adminCreateMemberAccountCore(deps, ADMIN, { role: "parent", name: "عم الطالب" })).uid;
  await rejects(
    parentLink.adminReplaceParentLinkCore(db, s1, { studentId: s1, fromParentId: p1, toParentId: p3 }),
    "permission-denied",
  );
  await rejects(
    parentLink.adminReplaceParentLinkCore(db, ADMIN, { studentId: s1, fromParentId: p3, toParentId: p1 }),
    "failed-precondition",
  );
  await parentLink.adminReplaceParentLinkCore(db, ADMIN, { studentId: s1, fromParentId: p1, toParentId: p3 });
  assert.ok(!(await data(`parentProfiles/${p1}`)).childrenIds.includes(s1));
  assert.ok((await data(`parentProfiles/${p3}`)).childrenIds.includes(s1));
  assert.ok((await data(`parentProfiles/${p2}`)).childrenIds.includes(s1), "other guardian untouched");

  const replace = (await history(s1)).find((h) => h.operation === "replace");
  assert.equal(replace.previousParentId, p1);
  assert.equal(replace.parentId, p3);
  const audits = await db.collection("auditLogs").where("source", "==", "adminReplaceParentLink").get();
  assert.equal(audits.size, 1);
});

test("P2-2: parent/student activation is Admin-callable only, audited, never for staff or Admin accounts", async () => {
  const status = require("../lib/accounts/memberStatusFunctions.js");
  const revoked = [];
  const sdeps = { db, auth: { revokeRefreshTokens: async (uid) => revoked.push(uid) } };
  const set = (caller, uid, isActive) => status.adminSetMemberActiveCore(sdeps, caller, { uid, isActive });
  const [s1, p1, t1] = [await idOf("S-001"), await idOf("P-001"), await idOf("T-001")];
  const audits = async () =>
    (await db.collection("auditLogs").where("action", "==", "account_active_change").get()).docs.map((d) => d.data());

  for (const caller of [t1, p1, s1]) await rejects(set(caller, s1, false), "permission-denied");
  await rejects(set(ADMIN, ADMIN, false), "failed-precondition");
  await rejects(set(ADMIN, t1, false), "failed-precondition", "الطاقم");
  await db.doc("users/admin_two").set({ name: "مدير ثان", role: "admin", isActive: true });
  await rejects(set(ADMIN, "admin_two", false), "failed-precondition", "مسؤول");
  await rejects(set(ADMIN, s1, "no"), "invalid-argument");
  assert.equal((await data(`users/${t1}`)).isActive, true);
  assert.equal((await data("users/admin_two")).isActive, true);
  assert.equal((await audits()).length, 0);

  const off = await set(ADMIN, s1, false);
  assert.deepEqual(off, { uid: s1, isActive: false, changed: true });
  assert.equal((await data(`users/${s1}`)).isActive, false);
  assert.deepEqual(revoked, [s1]);
  const again = await set(ADMIN, s1, false);
  assert.equal(again.changed, false);
  const [entry] = await audits();
  assert.equal((await audits()).length, 1);
  assert.equal(entry.actorId, ADMIN);
  assert.equal(entry.targetId, s1);
  assert.deepEqual(entry.metadata, { role: "student", previousActive: true, newActive: false });
  assert.equal(typeof entry.metadata.previousActive, "boolean");
  assert.equal(typeof entry.metadata.newActive, "boolean");

  // An archived student is unarchived first; then activation works.
  await db.doc(`studentProfiles/${s1}`).update({ lifecycle: "archived" });
  await rejects(set(ADMIN, s1, true), "failed-precondition", "مؤرشف");
  await db.doc(`studentProfiles/${s1}`).update({ lifecycle: "active" });
  assert.equal((await set(ADMIN, s1, true)).changed, true);
  assert.equal((await set(ADMIN, p1, false)).changed, true);
  assert.equal((await set(ADMIN, p1, true)).changed, true);
  assert.equal((await audits()).length, 4);
});

test("P2-1 / P3-1: guardian links read lifecycle from studentProfiles; no inactive parent; never zero guardians", async () => {
  const s1 = await idOf("S-001");
  const p1 = await idOf("P-001");
  const p2 = (await accounts.adminCreateMemberAccountCore(deps, ADMIN, { role: "parent", name: "خالد الخال" })).uid;
  const link = (parentId, operation) =>
    parentLink.adminLinkParentChildCore(db, ADMIN, { parentId, studentId: s1, operation });

  // The only guardian cannot be unlinked; replacement is the path.
  await rejects(link(p1, "unlink"), "failed-precondition", "الوحيد");
  assert.ok((await data(`parentProfiles/${p1}`)).childrenIds.includes(s1));

  // An inactive parent cannot receive a child, by link or by replacement.
  await db.doc(`users/${p2}`).update({ isActive: false });
  await rejects(link(p2, "link"), "failed-precondition", "غير نشط");
  await rejects(
    parentLink.adminReplaceParentLinkCore(db, ADMIN, { studentId: s1, fromParentId: p1, toParentId: p2 }),
    "failed-precondition",
  );
  assert.ok(!((await data(`parentProfiles/${p2}`)).childrenIds ?? []).includes(s1));

  // With a second active guardian, unlinking one is allowed.
  await db.doc(`users/${p2}`).update({ isActive: true });
  await link(p2, "link");
  await link(p1, "unlink");
  assert.ok(!(await data(`parentProfiles/${p1}`)).childrenIds.includes(s1));
  await rejects(link(p2, "unlink"), "failed-precondition", "الوحيد");

  // Archived on the SSOT (studentProfiles) blocks link and replace even when
  // the users doc still says active; the account status reports the SSOT.
  await db.doc(`studentProfiles/${s1}`).update({ lifecycle: "archived" });
  await db.doc(`users/${s1}`).update({ lifecycle: "active" });
  await rejects(link(p1, "link"), "failed-precondition", "مؤرشف");
  await rejects(
    parentLink.adminReplaceParentLinkCore(db, ADMIN, { studentId: s1, fromParentId: p2, toParentId: p1 }),
    "failed-precondition",
    "مؤرشف",
  );
  const status = await accounts.adminGetMemberAccountCore(db, auth, ADMIN, { userId: s1 });
  assert.equal(status.lifecycle, "archived");
  const parentStatus = await accounts.adminGetMemberAccountCore(db, auth, ADMIN, { userId: p2 });
  assert.equal(parentStatus.lifecycle, "");
});

test("5-6: teacher and supervisor assignment and change, audited with history", async () => {
  const halaqaId = await idOf("H-001");
  const [t1, t2] = [await idOf("T-001"), await idOf("T-002")];
  const [v1, v2] = [await idOf("V-001"), await idOf("V-002")];
  let h = await data(`halaqat/${halaqaId}`);
  assert.equal(h.teacherId, t1);
  assert.equal(h.supervisorId, v1);

  await staff.adminReassignHalaqaStaffCore(db, ADMIN, { halaqaId, role: "supervisor", newStaffId: v2 });
  await staff.adminReassignHalaqaStaffCore(db, ADMIN, { halaqaId, role: "teacher", newStaffId: t2 });
  h = await data(`halaqat/${halaqaId}`);
  assert.equal(h.teacherId, t2);
  assert.equal(h.supervisorId, v2);
  assert.deepEqual(h.assistantTeacherIds, [await idOf("A-001")], "assistants survive a teacher change");

  const entries = await history(halaqaId);
  const sup = entries.find((e) => e.kind === "halaqa_supervisor" && e.operation === "assign");
  assert.equal(sup.previousStaffId, v1);
  assert.equal(sup.staffId, v2);
  const teacher = entries.find((e) => e.kind === "halaqa_teacher" && e.operation === "assign");
  assert.equal(teacher.previousStaffId, t1);
  // The original assignment from creation is still in history.
  assert.ok(entries.some((e) => e.kind === "halaqa_teacher" && e.operation === "create" && e.staffId === t1));
});

test("7-9: assistant never overwrites the primary teacher; cover start/complete; scoped authority", async () => {
  const halaqaId = await idOf("H-001");
  const otherHalaqa = await idOf("H-002");
  const t1 = await idOf("T-001");
  const t2 = await idOf("T-002");
  const [a1, a2] = [await idOf("A-001"), await idOf("A-002")];
  const [s1, s2] = [await idOf("S-001"), await idOf("S-002")];

  // 7. Assistant assignment keeps the primary teacher.
  await assist.adminSetHalaqaAssistantCore(db, ADMIN, { halaqaId, assistantId: a2, operation: "assign" });
  let h = await data(`halaqat/${halaqaId}`);
  assert.equal(h.teacherId, t1);
  assert.deepEqual(h.assistantTeacherIds, [a1, a2]);
  await rejects(
    assist.adminSetHalaqaAssistantCore(db, ADMIN, { halaqaId, assistantId: t2, operation: "assign" }),
    "failed-precondition",
    "مساعد",
  );
  // An assistant cannot change their own (or anyone's) assignment.
  await rejects(
    assist.adminSetHalaqaAssistantCore(db, a1, { halaqaId: otherHalaqa, assistantId: a1, operation: "assign" }),
    "permission-denied",
  );
  await rejects(assist.adminStartHalaqaCoverCore(db, a1, { halaqaId, coverTeacherId: a1 }), "permission-denied");

  const day = records.operationalDay(records.operationalSlotsForDate(h.schedule, MONDAY));
  const inWindow = new Date(day.startAt.getTime() + 30 * 60_000);
  const mark = (uid, hid = halaqaId) =>
    sessions.recordSessionAttendanceCore(
      db,
      uid,
      { halaqaId: hid, date: MONDAY, marks: [{ studentId: s1, status: "present" }, { studentId: s2, status: "absent" }] },
      inWindow,
    );

  // 9. A merely assigned assistant has no teaching authority.
  await rejects(mark(a1), "permission-denied");

  // 8. Cover: only assigned assistants or other active teachers; one at a time.
  await rejects(
    assist.adminStartHalaqaCoverCore(db, ADMIN, { halaqaId: otherHalaqa, coverTeacherId: a1 }),
    "failed-precondition",
    "عيّن المساعد",
  );
  await rejects(
    assist.adminStartHalaqaCoverCore(db, ADMIN, { halaqaId, coverTeacherId: t1 }),
    "failed-precondition",
    "الأساسي",
  );
  const started = await assist.adminStartHalaqaCoverCore(db, ADMIN, {
    halaqaId,
    coverTeacherId: a1,
    reason: "سفر المعلم",
  });
  assert.equal(started.status, "active");
  h = await data(`halaqat/${halaqaId}`);
  assert.equal(h.teacherId, t1, "primary teacher preserved during cover");
  assert.equal(h.coverTeacherId, a1);
  await rejects(
    assist.adminStartHalaqaCoverCore(db, ADMIN, { halaqaId, coverTeacherId: t2 }),
    "failed-precondition",
    "نشطة",
  );
  await rejects(
    assist.adminSetHalaqaAssistantCore(db, ADMIN, { halaqaId, assistantId: a1, operation: "unassign" }),
    "failed-precondition",
    "التغطية",
  );

  const result = await mark(a1);
  const session = await data(`sessions/${result.sessionId}`);
  assert.equal(session.teacherId, t1, "session keeps the primary teacher");
  assert.equal(session.handledBy, a1);
  assert.equal(session.handledAs, "cover");
  assert.equal(session.coverId, started.coverId);
  assert.equal((await data(`attendanceRecords/${result.sessionId}_${s1}`)).recordedBy, a1);

  // Evaluation by the cover is attributed to the cover, scoped to the halaqa.
  const evaluation = await sessions.upsertSessionEvaluationCore(
    db,
    a1,
    { halaqaId, studentId: s1, sessionId: result.sessionId, type: "memorization", grade: "excellent", behaviorGrade: "excellent" },
    inWindow,
  );
  const evalDoc = await data(`recitationRecords/${evaluation.evaluationId}`);
  assert.equal(evalDoc.teacherId, a1);
  assert.equal(evalDoc.handledAs, "cover");

  // The cover never reaches an unrelated halaqa; a non-cover assistant stays out.
  await rejects(mark(a1, otherHalaqa), "permission-denied");
  await rejects(mark(a2), "permission-denied");

  // Return to normal: the period is completed (kept), authority ends.
  const ended = await assist.adminEndHalaqaCoverCore(db, ADMIN, { halaqaId, coverId: started.coverId });
  assert.equal(ended.status, "completed");
  const period = await data(`halaqaCoverPeriods/${started.coverId}`);
  assert.equal(period.status, "completed");
  assert.equal(period.primaryTeacherId, t1);
  assert.equal(period.coverTeacherId, a1);
  assert.equal(period.endedBy, ADMIN);
  h = await data(`halaqat/${halaqaId}`);
  assert.equal(h.coverTeacherId, "");
  assert.equal(h.teacherId, t1);
  await rejects(mark(a1), "permission-denied");
  // Ending again is a no-op.
  assert.equal((await assist.adminEndHalaqaCoverCore(db, ADMIN, { halaqaId })).changed, false);

  // The primary teacher still works normally.
  await mark(t1);

  // History and audit both carry the full story.
  const ops = (await history(halaqaId))
    .filter((e) => e.kind === "halaqa_cover" || e.kind === "halaqa_assistant")
    .map((e) => `${e.kind}:${e.operation}`)
    .sort();
  assert.deepEqual(ops, ["halaqa_assistant:assign", "halaqa_assistant:assign", "halaqa_cover:end", "halaqa_cover:start"]);
  for (const action of ["halaqa_assistant_change", "halaqa_cover_start", "halaqa_cover_end"]) {
    const n = (await db.collection("auditLogs").where("action", "==", action).get()).size;
    assert.ok(n >= 1, action);
  }

  // A teacher may also cover (not just assistants).
  const teacherCover = await assist.adminStartHalaqaCoverCore(db, ADMIN, { halaqaId, coverTeacherId: t2 });
  assert.equal((await data(`halaqat/${halaqaId}`)).coverTeacherId, t2);
  await assist.adminEndHalaqaCoverCore(db, ADMIN, { halaqaId, coverId: teacherCover.coverId });
});

test("staff lifecycle refuses to orphan an assistant assignment or an active cover", async () => {
  const halaqaId = await idOf("H-001");
  const a1 = await idOf("A-001");
  const staffDeps = { db, auth };
  await rejects(
    staff.adminSetStaffStatusCore(staffDeps, ADMIN, { uid: a1, action: "deactivate" }),
    "failed-precondition",
    "حلقة الفجر",
  );
  await assist.adminSetHalaqaAssistantCore(db, ADMIN, { halaqaId, assistantId: a1, operation: "unassign" });
  const r = await staff.adminSetStaffStatusCore(staffDeps, ADMIN, { uid: a1, action: "deactivate" });
  assert.equal(r.status, "deactivated");
  // An inactive assistant cannot be assigned or activated as cover.
  await rejects(
    assist.adminSetHalaqaAssistantCore(db, ADMIN, { halaqaId, assistantId: a1, operation: "assign" }),
    "failed-precondition",
  );
});

test("account status and recovery never expose a password", async () => {
  const created = await accounts.adminCreateMemberAccountCore(deps, ADMIN, {
    role: "assistant_teacher",
    name: "مساعد جديد",
  });
  assert.match(created.username, /^as\d{6}$/);
  assert.equal(created.academyRef, "A-003");
  assert.equal(await signIn(created.username, created.temporaryPassword), true);

  // Students are never created without a guardian; Admins are not created here.
  await rejects(accounts.adminCreateMemberAccountCore(deps, ADMIN, { role: "student", name: "طالب" }), "invalid-argument");
  await rejects(accounts.adminCreateMemberAccountCore(deps, ADMIN, { role: "admin", name: "مسؤول" }), "invalid-argument");
  await rejects(
    accounts.adminCreateMemberAccountCore(deps, created.uid, { role: "parent", name: "ولي" }),
    "permission-denied",
  );

  let status = await accounts.adminGetMemberAccountCore(db, auth, ADMIN, { userId: created.uid });
  assert.equal(status.loginKind, "username");
  assert.equal(status.username, created.username);
  assert.equal(status.mustChangePassword, true);
  assert.equal(status.canResetPassword, true);
  assert.equal(status.academyRef, "A-003");
  assert.equal(typeof status.lastSignInAtMs, "number", "Auth metadata records the sign-in");
  assert.deepEqual(status.recoveries, []);
  await rejects(accounts.adminGetMemberAccountCore(db, auth, created.uid, { userId: created.uid }), "permission-denied");

  const reset = await onboarding.adminResetMemberPasswordCore(deps, ADMIN, { userId: created.uid });
  assert.equal(await signIn(created.username, created.temporaryPassword), false, "old password revoked");
  assert.equal(await signIn(created.username, reset.temporaryPassword), true);
  status = await accounts.adminGetMemberAccountCore(db, auth, ADMIN, { userId: created.uid });
  assert.equal(status.recoveries.length, 1);
  assert.equal(status.recoveries[0].actorId, ADMIN);
  assert.equal(status.recoveries[0].actorName, "المدير");
  assert.equal(status.mustChangePassword, true);

  // No secret in the status payload, Firestore, or the audit log.
  const payload = JSON.stringify(status);
  const everything = [];
  for (const name of ["users", "userPrivate", "auditLogs", "importRows", "relationshipHistory", "loginUsernames"]) {
    for (const d of (await db.collection(name).get()).docs) everything.push(JSON.stringify(d.data()));
  }
  for (const secret of [created.temporaryPassword, reset.temporaryPassword]) {
    assert.equal(payload.includes(secret), false);
    assert.equal(everything.join("|").includes(secret), false);
  }
  // Admin accounts are never reset from here.
  const adminStatus = await accounts.adminGetMemberAccountCore(db, auth, ADMIN, { userId: ADMIN });
  assert.equal(adminStatus.canResetPassword, false);
});

test("10-11: only an active Admin provisions another Admin; nobody self-promotes", async () => {
  const { adminProvisionUser } = require("../lib/admin/adminProvisionUser.js");
  const t1 = await idOf("T-001");
  const previous = process.env.FUNCTIONS_EMULATOR;
  process.env.FUNCTIONS_EMULATOR = "true";
  try {
    await rejects(
      adminProvisionUser.run({
        auth: { uid: t1 },
        data: { email: "self.promote@academy.test", password: "Initial1", name: "ترقية", role: "admin" },
      }),
      "permission-denied",
    );
    const { uid } = await adminProvisionUser.run({
      auth: { uid: ADMIN },
      data: { email: "second.admin@academy.test", password: "Initial1", name: "مسؤول ثان", role: "admin" },
    });
    const created = await data(`users/${uid}`);
    assert.equal(created.role, "admin");
    assert.equal(created.passwordChangeRequired, true);
    assert.equal(created.nameNormalized.length > 0, true, "new Admins are searchable in the directory");
    const audit = await db.collection("auditLogs").where("action", "==", "user_provision").where("targetId", "==", uid).get();
    assert.equal(audit.size, 1);
  } finally {
    if (previous === undefined) delete process.env.FUNCTIONS_EMULATOR;
    else process.env.FUNCTIONS_EMULATOR = previous;
  }
});
