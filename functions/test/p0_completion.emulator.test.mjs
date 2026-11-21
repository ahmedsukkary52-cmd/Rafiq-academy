/**
 * P0 COMPLETION — callable cores against the Firestore emulator.
 * Homework reward security (P0-05), Parent linking (P0-01), Halaqa + schedule
 * creation (P0-04) and their integration with existing PH-02 workflows.
 * Never touches a real project.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 functions/test/p0_completion.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("P0 emulator suite requires FIRESTORE_EMULATOR_HOST and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const economy = require("../lib/economy/economyFunctions.js");
const parentLink = require("../lib/relationships/parentLinkFunctions.js");
const halaqa = require("../lib/halaqa/halaqaScheduleFunctions.js");
const membership = require("../lib/halaqa/membershipFunctions.js");
const review = require("../lib/billing/paymentReview.js");
const materialize = require("../lib/sessions/materializeSession.js");

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed(entries) {
  const batch = db.batch();
  for (const [path, value] of Object.entries(entries)) batch.set(db.doc(path), value);
  await batch.commit();
}

async function expectCode(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `expected ${code}, got ${err.code}: ${err.message}`);
    return true;
  });
}

async function data(path) {
  return (await db.doc(path).get()).data();
}

async function auditCount(action) {
  return (await db.collection("auditLogs").where("action", "==", action).get()).size;
}

const user = (role, name = role) => ({ name, role, isActive: true });

test.beforeEach(async () => {
  await clearFirestore();
  await seed({
    "users/admin1": user("admin"),
    "users/sup1": user("supervisor"),
    "users/teacher1": user("teacher"),
    "users/teacher2": user("teacher"),
    "users/parent1": user("parent"),
    "users/parent2": user("parent"),
    "users/parent3": user("parent"),
    "users/student1": user("student", "Student One"),
    "users/student2": user("student", "Student Two"),
    "users/student3": user("student", "Student Three"),
    "users/archived1": { ...user("student"), lifecycle: "archived" },
    "halaqat/h1": {
      name: "H1",
      teacherId: "teacher1",
      supervisorId: "sup1",
      studentIds: ["student1", "student2"],
      schedule: [{ slotId: "slot-mon", day: "monday", startTime: "16:00", endTime: "17:00" }],
    },
    "studentProfiles/student1": { uid: "student1", halaqaId: "h1", points: 0, coins: 0 },
    "studentProfiles/student2": { uid: "student2", halaqaId: "h1", points: 0, coins: 0 },
    "studentProfiles/student3": { uid: "student3", coins: 0 },
    "studentProfiles/archived1": { uid: "archived1", lifecycle: "archived" },
    "parentProfiles/parent1": { uid: "parent1", childrenIds: [] },
    "parentProfiles/parent2": { uid: "parent2", childrenIds: ["student2"] },
    "parentProfiles/parent3": { uid: "parent3", childrenIds: ["student3"] },
  });
});

// ── P0-05 Homework reward security ─────────────────────────────────────────

const lessonTasks = (overrides = {}) => [
  { id: "t1", kind: "reading", points: 20, isCompleted: true },
  { id: "t2", kind: "listening", points: 15, isCompleted: true },
  { id: "t3", kind: "recitation", points: 30, isCompleted: false },
  ...(overrides.extra ?? []),
];

async function seedHomework(id, overrides = {}) {
  await seed({
    [`assignments/${id}`]: {
      studentId: "student1",
      halaqaId: "h1",
      assignedBy: "teacher1",
      kind: "lessonHomework",
      isSubmitted: false,
      status: "pending",
      tasks: lessonTasks(),
      ...overrides,
    },
  });
}

const complete = (uid, id, caps) =>
  economy.completeHomeworkCore(db, uid, { assignmentId: id }, caps);

test("P0-05 valid completion: disabled recitation is not a blocker; fixed server reward", async () => {
  await seedHomework("hw1");
  const result = await complete("student1", "hw1");
  assert.equal(result.awardedCoins, 35);
  assert.equal(result.alreadyRewarded, false);
  const profile = await data("studentProfiles/student1");
  assert.equal(profile.coins, 35);
  assert.equal(profile.points, 0);
  const marker = await data("homeworkRewards/hw1");
  assert.equal(marker.studentId, "student1");
  assert.equal(marker.coins, 35);
  assert.deepEqual(marker.requiredKinds, ["reading", "listening"]);
  const hw = await data("assignments/hw1");
  assert.equal(hw.status, "completed");
  assert.ok(hw.completedAt instanceof Timestamp);
});

test("P0-05 forged task list: inflated points / extra kinds never change the reward", async () => {
  await seedHomework("hwForged", {
    tasks: [
      { id: "t1", kind: "reading", points: 9999, isCompleted: true },
      { id: "t2", kind: "listening", points: 9999, isCompleted: true },
      { id: "x1", kind: "bonus", points: 9999, isCompleted: true },
      { id: "x2", kind: "reading", points: 9999, isCompleted: true },
    ],
  });
  const result = await complete("student1", "hwForged");
  assert.equal(result.awardedCoins, 35);
  assert.equal((await data("studentProfiles/student1")).coins, 35);
});

test("P0-05 forged task list: removing required kinds cannot complete", async () => {
  await seedHomework("hwEmpty", { tasks: [] });
  await expectCode(complete("student1", "hwEmpty"), "failed-precondition");
  await seedHomework("hwOnlyBonus", {
    tasks: [{ id: "x", kind: "bonus", points: 999, isCompleted: true }],
  });
  await expectCode(complete("student1", "hwOnlyBonus"), "failed-precondition");
  await seedHomework("hwHalf", {
    tasks: [{ id: "t1", kind: "reading", isCompleted: true }],
  });
  await expectCode(complete("student1", "hwHalf"), "failed-precondition");
  assert.equal((await data("studentProfiles/student1")).coins, 0);
  assert.equal((await db.doc("homeworkRewards/hwEmpty").get()).exists, false);
});

test("P0-05 forged kind: a non-lesson kind is rejected (stale/forged client)", async () => {
  await seedHomework("hwKind", { kind: "quiz" });
  await expectCode(complete("student1", "hwKind"), "failed-precondition");
  await seedHomework("hwAct", { kind: "halaqaActivity" });
  await expectCode(complete("student1", "hwAct"), "failed-precondition");
});

test("P0-05 capability enabled: recitation becomes required and needs real evidence", async () => {
  const enabled = { audioUploadsEnabled: true };
  await seedHomework("hwRec", {
    tasks: [
      ...lessonTasks().slice(0, 2),
      { id: "t3", kind: "recitation", isCompleted: true, recitationRecordId: "r1" },
    ],
  });
  await seed({
    "recitationRecords/r1": {
      studentId: "student1",
      halaqaId: "h1",
      assignmentId: "hwRec",
      reviewStatus: "pending",
    },
  });
  // Forged record without an uploaded file under the student's path.
  await expectCode(complete("student1", "hwRec", enabled), "failed-precondition");
  await db.doc("recitationRecords/r1").update({
    storagePath: "recitations/student2/hwRec/t3.m4a",
  });
  await expectCode(complete("student1", "hwRec", enabled), "failed-precondition");
  await db.doc("recitationRecords/r1").update({
    storagePath: "recitations/student1/hwRec/t3_1.m4a",
  });
  const result = await complete("student1", "hwRec", enabled);
  assert.equal(result.awardedCoins, 65);

  await seedHomework("hwRecMissing");
  await expectCode(complete("student1", "hwRecMissing", enabled), "failed-precondition");
});

test("P0-05 repeated completion / retry returns alreadyRewarded and pays once", async () => {
  await seedHomework("hw1");
  await complete("student1", "hw1");
  for (let i = 0; i < 3; i++) {
    const replay = await complete("student1", "hw1");
    assert.equal(replay.alreadyRewarded, true);
    assert.equal(replay.awardedCoins, 0);
  }
  assert.equal((await data("studentProfiles/student1")).coins, 35);
});

test("P0-05 concurrent completion: exactly one credit", async () => {
  await seedHomework("hw1");
  const results = await Promise.allSettled([
    complete("student1", "hw1"),
    complete("student1", "hw1"),
    complete("student1", "hw1"),
  ]);
  const fresh = results.filter((r) => r.status === "fulfilled" && !r.value.alreadyRewarded);
  assert.equal(fresh.length, 1);
  assert.equal((await data("studentProfiles/student1")).coins, 35);
});

test("P0-05 Teacher reopen cannot cause a second reward", async () => {
  await seedHomework("hw1");
  await complete("student1", "hw1");
  // A Teacher reopen (fields the rules allow a Teacher to change).
  await db.doc("assignments/hw1").update({ status: "pending", isSubmitted: false });
  const again = await complete("student1", "hw1");
  assert.equal(again.alreadyRewarded, true);
  assert.equal((await data("studentProfiles/student1")).coins, 35);
  assert.equal((await data("assignments/hw1")).status, "completed");
});

test("P0-05 legacy completion (completedAt, no marker) reopened never re-credits", async () => {
  await seedHomework("hwLegacy", {
    status: "pending",
    isSubmitted: false,
    completedAt: Timestamp.fromMillis(1_780_000_000_000),
  });
  const result = await complete("student1", "hwLegacy");
  assert.equal(result.alreadyRewarded, true);
  assert.equal((await data("studentProfiles/student1")).coins, 0);
});

test("P0-05 foreign student / other roles are denied", async () => {
  await seedHomework("hwOther", { studentId: "student2" });
  await expectCode(complete("student1", "hwOther"), "permission-denied");
  await expectCode(complete("teacher1", "hwOther"), "permission-denied");
  await expectCode(complete(undefined, "hwOther"), "unauthenticated");
});

// ── P0-01 Parent linking ───────────────────────────────────────────────────

const link = (uid, payload) => parentLink.adminLinkParentChildCore(db, uid, payload);

test("P0-01 Admin links a child: childrenIds updated + one audit; relink is a no-op; the sole guardian cannot be unlinked", async () => {
  const result = await link("admin1", { parentId: "parent1", studentId: "student1" });
  assert.equal(result.changed, true);
  assert.deepEqual((await data("parentProfiles/parent1")).childrenIds, ["student1"]);
  assert.equal(await auditCount("relationship_children_change"), 1);

  const again = await link("admin1", { parentId: "parent1", studentId: "student1" });
  assert.equal(again.changed, false);
  assert.equal(await auditCount("relationship_children_change"), 1);

  // Approved rule (F4): a student always keeps a guardian. Unlinking the only
  // one is refused and changes nothing; replacement is the path.
  const unlinkSole = (parentId) => link("admin1", { parentId, studentId: "student1", operation: "unlink" });
  await assert.rejects(unlinkSole("parent1"), (err) => {
    assert.equal(err.code, "failed-precondition");
    assert.match(err.message, /الوحيد/);
    return true;
  });
  assert.deepEqual((await data("parentProfiles/parent1")).childrenIds, ["student1"]);
  assert.equal(await auditCount("relationship_children_change"), 1);

  // With a second active guardian, unlinking one of them succeeds and is audited.
  assert.equal((await link("admin1", { parentId: "parent2", studentId: "student1" })).changed, true);
  const unlink = await unlinkSole("parent1");
  assert.equal(unlink.changed, true);
  assert.deepEqual((await data("parentProfiles/parent1")).childrenIds, []);
  assert.deepEqual((await data("parentProfiles/parent2")).childrenIds, ["student2", "student1"]);
  assert.equal(await auditCount("relationship_children_change"), 3);

  // The remaining guardian is now the only one and is protected in turn.
  await expectCode(unlinkSole("parent2"), "failed-precondition");
  assert.deepEqual((await data("parentProfiles/parent2")).childrenIds, ["student2", "student1"]);
});

test("P0-01 a wrong sole-guardian link is corrected atomically by replacement, audited", async () => {
  await link("admin1", { parentId: "parent1", studentId: "student1" });
  const replaced = await parentLink.adminReplaceParentLinkCore(db, "admin1", {
    studentId: "student1",
    fromParentId: "parent1",
    toParentId: "parent2",
  });
  assert.equal(replaced.changed, true);
  assert.deepEqual((await data("parentProfiles/parent1")).childrenIds, []);
  assert.deepEqual((await data("parentProfiles/parent2")).childrenIds, ["student2", "student1"]);
  const audits = (await db.collection("auditLogs").where("action", "==", "relationship_children_change").get()).docs
    .map((d) => d.data())
    .filter((a) => a.metadata?.operation === "replace");
  assert.equal(audits.length, 1);
  assert.deepEqual(
    [audits[0].metadata.previousParentId, audits[0].metadata.parentId, audits[0].metadata.studentId],
    ["parent1", "parent2", "student1"],
  );
  const history = (await db.collection("relationshipHistory").get()).docs.map((d) => d.data());
  assert.ok(history.some((h) => h.operation === "replace" && h.previousParentId === "parent1" && h.parentId === "parent2"));
  // Only an Admin may replace.
  await expectCode(
    parentLink.adminReplaceParentLinkCore(db, "sup1", { studentId: "student1", fromParentId: "parent2", toParentId: "parent1" }),
    "permission-denied",
  );
});

test("P0-01 unauthorized roles cannot link", async () => {
  for (const uid of ["sup1", "teacher1", "parent1", "student1"]) {
    await expectCode(
      link(uid, { parentId: "parent1", studentId: "student1" }),
      "permission-denied",
    );
  }
  await expectCode(link(undefined, { parentId: "parent1", studentId: "student1" }), "unauthenticated");
  assert.deepEqual((await data("parentProfiles/parent1")).childrenIds, []);
});

test("P0-01 forged / invalid ids fail closed", async () => {
  await expectCode(link("admin1", { parentId: "teacher1", studentId: "student1" }), "failed-precondition");
  await expectCode(link("admin1", { parentId: "parent1", studentId: "ghost" }), "failed-precondition");
  await expectCode(link("admin1", { parentId: "parent1", studentId: "parent2" }), "failed-precondition");
  await expectCode(link("admin1", { parentId: "parent1", studentId: "archived1" }), "failed-precondition");
  await expectCode(link("admin1", { parentId: "parent1" }), "invalid-argument");
  await expectCode(
    link("admin1", { parentId: "parent1", studentId: "student1", operation: "delete_all" }),
    "invalid-argument",
  );
  assert.deepEqual((await data("parentProfiles/parent1")).childrenIds, []);
});

test("P0-01 concurrent links of different children both persist", async () => {
  await Promise.all([
    link("admin1", { parentId: "parent1", studentId: "student1" }),
    link("admin1", { parentId: "parent1", studentId: "student3" }),
  ]);
  const ids = (await data("parentProfiles/parent1")).childrenIds;
  assert.deepEqual([...ids].sort(), ["student1", "student3"]);
});

test("P0-01 the new relationship is immediately authoritative (payment review scope)", async () => {
  await seed({
    "payments/p1": {
      parentId: "parent1",
      studentId: "student1",
      amount: 200,
      status: "due",
      reviewStatus: "pending_review",
      proofSubmittedAt: Timestamp.fromMillis(1_790_000_000_000),
    },
  });
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "p1", decision: "approve" }),
    "failed-precondition",
  );
  await link("admin1", { parentId: "parent1", studentId: "student1" });
  const result = await review.reviewPaymentProofCore(db, "admin1", {
    paymentId: "p1",
    decision: "approve",
  });
  assert.equal(result.status, "paid");
});

// ── P0-04 Halaqa + schedule creation ───────────────────────────────────────

let idCounter = 0;
const nextId = () => `slot-${++idCounter}`;
const create = (uid, payload) => halaqa.adminCreateHalaqaCore(db, uid, payload, nextId);
const addSlot = (uid, payload) => halaqa.adminAddHalaqaSlotCore(db, uid, payload, nextId);

const newHalaqa = (overrides = {}) => ({
  name: "حلقة الفجر",
  teacherId: "teacher2",
  supervisorId: "sup1",
  schedule: [
    { day: "السبت", startTime: "16:00", endTime: "17:00" },
    { day: "الثلاثاء", startTime: "18:00", endTime: "19:00" },
  ],
  ...overrides,
});

test("P0-04 valid creation: ≥1 slot, slotIds, empty roster, teacher profile, audit", async () => {
  const result = await create("admin1", newHalaqa());
  assert.equal(result.alreadyExisted, false);
  assert.equal(result.slotIds.length, 2);
  const doc = await data(`halaqat/${result.halaqaId}`);
  assert.equal(doc.name, "حلقة الفجر");
  assert.equal(doc.teacherId, "teacher2");
  assert.equal(doc.supervisorId, "sup1");
  assert.deepEqual(doc.studentIds, []);
  assert.equal(doc.status, "active");
  assert.equal(doc.createdBy, "admin1");
  assert.deepEqual(
    doc.schedule.map((s) => [s.day, s.startTime, s.endTime]),
    [["السبت", "16:00", "17:00"], ["الثلاثاء", "18:00", "19:00"]],
  );
  assert.ok(doc.schedule.every((s) => typeof s.slotId === "string" && s.slotId));
  assert.deepEqual((await data("teacherProfiles/teacher2")).halaqatIds, [result.halaqaId]);
  assert.equal(await auditCount("halaqa_create"), 1);
});

test("P0-04 D9: a created slot materializes its own Session (Cairo date contract)", async () => {
  const result = await create("admin1", newHalaqa());
  const session = await materialize.materializeSessionCore(db, "admin1", {
    halaqaId: result.halaqaId,
    slotId: result.slotIds[0],
    date: "2026-10-03", // Saturday (Cairo)
  });
  assert.equal(session.created, true);
  assert.equal(session.slotId, result.slotIds[0]);
});

test("P0-04 missing / malformed slots are rejected (D8)", async () => {
  await expectCode(create("admin1", newHalaqa({ schedule: [] })), "invalid-argument");
  await expectCode(create("admin1", newHalaqa({ schedule: undefined })), "invalid-argument");
  await expectCode(
    create("admin1", newHalaqa({ schedule: [{ day: "يوم", startTime: "16:00", endTime: "17:00" }] })),
    "invalid-argument",
  );
  await expectCode(
    create("admin1", newHalaqa({ schedule: [{ day: "السبت", startTime: "17:00", endTime: "16:00" }] })),
    "invalid-argument",
  );
  assert.equal((await db.collection("halaqat").get()).size, 1);
});

test("P0-04 hard conflicts: same Halaqa, same Teacher; adjacent and Supervisor overlap allowed", async () => {
  await expectCode(
    create("admin1", newHalaqa({
      schedule: [
        { day: "السبت", startTime: "16:00", endTime: "17:00" },
        { day: "السبت", startTime: "16:30", endTime: "17:30" },
      ],
    })),
    "failed-precondition",
  );
  // teacher1 already teaches h1 on Monday 16:00–17:00.
  await expectCode(
    create("admin1", newHalaqa({
      teacherId: "teacher1",
      schedule: [{ day: "الاثنين", startTime: "16:30", endTime: "17:30" }],
    })),
    "failed-precondition",
  );
  const adjacent = await create("admin1", newHalaqa({
    teacherId: "teacher1",
    schedule: [{ day: "الاثنين", startTime: "17:00", endTime: "18:00" }],
  }));
  assert.ok(adjacent.halaqaId);
  // sup1 supervises h1 at the same time — Supervisor overlap is not a conflict.
  const supOverlap = await create("admin1", newHalaqa({
    name: "حلقة المغرب",
    teacherId: "teacher2",
    supervisorId: "sup1",
    schedule: [{ day: "الاثنين", startTime: "16:00", endTime: "17:00" }],
  }));
  assert.ok(supOverlap.halaqaId);
});

test("P0-04 add slot: student roster intersection is a hard conflict", async () => {
  // The admission boundary requires the student's eligible guardian link.
  await db.doc("parentProfiles/parent1").update({ childrenIds: ["student1"] });
  const created = await create("admin1", newHalaqa({ supervisorId: "" }));
  await membership.admitStudentToHalaqaCore(db, "admin1", {
    studentId: "student1",
    halaqaId: created.halaqaId,
  });
  // student1 is also in h1 on Monday 16:00–17:00.
  await expectCode(
    addSlot("admin1", {
      halaqaId: created.halaqaId,
      slot: { day: "الاثنين", startTime: "16:15", endTime: "16:45" },
    }),
    "failed-precondition",
  );
  const ok = await addSlot("admin1", {
    halaqaId: created.halaqaId,
    slot: { day: "الأربعاء", startTime: "16:00", endTime: "17:00" },
  });
  const doc = await data(`halaqat/${created.halaqaId}`);
  assert.equal(doc.schedule.length, 3);
  assert.equal(doc.schedule[2].slotId, ok.slotId);
  assert.equal(await auditCount("halaqa_schedule_change"), 1);
});

test("P0-04 concurrent conflicting creations for one Teacher: exactly one succeeds", async () => {
  const results = await Promise.allSettled([
    create("admin1", newHalaqa({ name: "A", schedule: [{ day: "الخميس", startTime: "10:00", endTime: "11:00" }] })),
    create("admin1", newHalaqa({ name: "B", schedule: [{ day: "الخميس", startTime: "10:30", endTime: "11:30" }] })),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  const teacher2Halaqat = await db.collection("halaqat").where("teacherId", "==", "teacher2").get();
  assert.equal(teacher2Halaqat.size, 1);
});

test("P0-04 requestId makes retries idempotent", async () => {
  const payload = newHalaqa({ requestId: "req_halaqa_0001" });
  const first = await create("admin1", payload);
  const retry = await create("admin1", payload);
  assert.equal(first.halaqaId, "req_halaqa_0001");
  assert.equal(retry.alreadyExisted, true);
  assert.deepEqual(retry.slotIds, first.slotIds);
  assert.equal(await auditCount("halaqa_create"), 1);
});

test("P0-04 unauthorized roles and invalid staff are denied", async () => {
  for (const uid of ["sup1", "teacher1", "parent1", "student1"]) {
    await expectCode(create(uid, newHalaqa()), "permission-denied");
  }
  await expectCode(create("admin1", newHalaqa({ teacherId: "student1" })), "failed-precondition");
  await expectCode(create("admin1", newHalaqa({ supervisorId: "teacher1" })), "failed-precondition");
  await expectCode(
    addSlot("sup1", { halaqaId: "h1", slot: { day: "الأحد", startTime: "10:00", endTime: "11:00" } }),
    "permission-denied",
  );
});

test("P0-04 membership stays server-authoritative after creation", async () => {
  const created = await create("admin1", newHalaqa());
  assert.deepEqual((await data(`halaqat/${created.halaqaId}`)).studentIds, []);
  await membership.admitStudentToHalaqaCore(db, "admin1", {
    studentId: "student3",
    halaqaId: created.halaqaId,
  });
  assert.deepEqual((await data(`halaqat/${created.halaqaId}`)).studentIds, ["student3"]);
  assert.equal((await data("studentProfiles/student3")).halaqaId, created.halaqaId);
});
