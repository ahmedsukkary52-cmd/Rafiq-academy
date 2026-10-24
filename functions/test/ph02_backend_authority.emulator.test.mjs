/**
 * PRODUCTION-HARDENING-02 — callable/trigger cores against the Firestore
 * emulator (transactions, idempotency, races). Never touches a real project.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 functions/test/ph02_backend_authority.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "PH-02 emulator suite requires FIRESTORE_EMULATOR_HOST and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const review = require("../lib/billing/paymentReview.js");
const sessions = require("../lib/sessions/sessionRecordFunctions.js");
const records = require("../lib/sessions/sessionRecords.js");
const membership = require("../lib/halaqa/membershipFunctions.js");
const economy = require("../lib/economy/economyFunctions.js");
const awards = require("../lib/awards/awardFunctions.js");
const evalFanOut = require("../lib/notifications/evaluationNotificationFunctions.js");
const assignmentFanOut = require("../lib/notifications/assignmentNotificationFunctions.js");

const MONDAY = "2026-09-28";
const SCHEDULE = [
  { slotId: "slot-mon", day: "monday", startTime: "16:00", endTime: "17:00" },
];
const DAY = records.operationalDay(records.operationalSlotsForDate(SCHEDULE, MONDAY));
const IN_WINDOW = new Date(DAY.startAt.getTime() + 30 * 60_000);
const AFTER_WINDOW = new Date(DAY.endAt.getTime() + 60 * 60_000);

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed(entries) {
  const batch = db.batch();
  for (const [path, data] of Object.entries(entries)) batch.set(db.doc(path), data);
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
    "users/sup2": user("supervisor"),
    "users/teacher1": user("teacher"),
    "users/teacher2": user("teacher"),
    "users/parent1": user("parent"),
    "users/parent2": user("parent"),
    "users/student1": user("student", "Student One"),
    "users/student2": user("student", "Student Two"),
    "users/student3": user("student", "Student Three"),
    "halaqat/h1": {
      name: "H1",
      teacherId: "teacher1",
      supervisorId: "sup1",
      studentIds: ["student1", "student2"],
      schedule: SCHEDULE,
    },
    "halaqat/h2": {
      name: "H2",
      teacherId: "teacher2",
      supervisorId: "sup2",
      studentIds: [],
      schedule: [{ slotId: "slot-tue", day: "tuesday", startTime: "16:00", endTime: "17:00" }],
    },
    "halaqat/h3": {
      name: "H3",
      teacherId: "teacher2",
      supervisorId: "sup2",
      studentIds: [],
      schedule: [{ slotId: "slot-wed", day: "wednesday", startTime: "16:00", endTime: "17:00" }],
    },
    "studentProfiles/student1": { uid: "student1", halaqaId: "h1", points: 0, coins: 0 },
    "studentProfiles/student2": { uid: "student2", halaqaId: "h1", points: 0 },
    "studentProfiles/student3": { uid: "student3", points: 0 },
    "parentProfiles/parent1": { uid: "parent1", childrenIds: ["student1"] },
    "parentProfiles/parent2": { uid: "parent2", childrenIds: ["student2"] },
  });
});

// ── C4 / C16 payment review ────────────────────────────────────────────────

function pendingPayment(overrides = {}) {
  return {
    parentId: "parent1",
    studentId: "student1",
    amount: 200,
    status: "due",
    reviewStatus: "pending_review",
    proofSubmittedAt: Timestamp.fromMillis(1_790_000_000_000),
    ...overrides,
  };
}

test("PH02 payment: Admin approves → paid with server-derived fields + one audit", async () => {
  await seed({ "payments/p1": pendingPayment() });
  const result = await review.reviewPaymentProofCore(db, "admin1", {
    paymentId: "p1",
    decision: "approve",
    // Forged client fields are ignored.
    amount: 1,
    amountPaidConfirmed: 1,
    reviewedBy: "someone",
    status: "paid",
  });
  assert.deepEqual(result, {
    paymentId: "p1",
    reviewStatus: "approved",
    status: "paid",
    amount: 200,
    previousAmountPaidConfirmed: 0,
    amountPaidConfirmed: 200,
    remainingAmount: 0,
    receiptAmount: 200,
    amountMode: "approve_remaining",
    replayed: false,
  });

  const doc = await data("payments/p1");
  assert.equal(doc.status, "paid");
  assert.equal(doc.amount, 200);
  assert.equal(doc.amountPaidConfirmed, 200);
  assert.equal(doc.remainingAmount, 0);
  assert.equal(doc.reviewedBy, "admin1");
  assert.ok(doc.reviewedAt instanceof Timestamp);
  assert.ok(doc.paidAt instanceof Timestamp);

  const logs = await db.collection("auditLogs").get();
  assert.equal(logs.size, 1);
  const entry = logs.docs[0].data();
  assert.equal(entry.actorId, "admin1");
  assert.equal(entry.actorRole, "admin");
  assert.equal(entry.action, "payment_review");
  assert.equal(entry.targetId, "p1");
  assert.equal(entry.metadata.paymentId, "p1");
  assert.equal(entry.metadata.parentId, "parent1");
  assert.equal(entry.metadata.previousStatus, "due");
  assert.equal(entry.metadata.newStatus, "paid");
  assert.ok(entry.timestamp instanceof Timestamp);
  assert.ok(!JSON.stringify(entry).includes("phone"));
});

test("PH02 payment: replay is rejected without a second transition or audit", async () => {
  await seed({ "payments/p1": pendingPayment() });
  await review.reviewPaymentProofCore(db, "admin1", { paymentId: "p1", decision: "approve" });
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "p1", decision: "approve" }),
    "failed-precondition",
  );
  await expectCode(
    review.reviewPaymentProofCore(db, "sup1", { paymentId: "p1", decision: "reject" }),
    "failed-precondition",
  );
  assert.equal(await auditCount("payment_review"), 1);
  assert.equal((await data("payments/p1")).reviewStatus, "approved");
});

test("PH02 payment: concurrent approvals commit exactly once", async () => {
  await seed({ "payments/p1": pendingPayment() });
  const results = await Promise.allSettled([
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "p1", decision: "approve" }),
    review.reviewPaymentProofCore(db, "sup1", { paymentId: "p1", decision: "approve" }),
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "p1", decision: "reject" }),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(await auditCount("payment_review"), 1);
});

test("PH02 payment: scoped Supervisor reviews; unscoped / other roles denied", async () => {
  await seed({ "payments/p1": pendingPayment(), "payments/p2": pendingPayment() });
  await expectCode(
    review.reviewPaymentProofCore(db, "sup2", { paymentId: "p1", decision: "approve" }),
    "permission-denied",
  );
  for (const uid of ["teacher1", "parent1", "student1"]) {
    await expectCode(
      review.reviewPaymentProofCore(db, uid, { paymentId: "p1", decision: "approve" }),
      "permission-denied",
    );
  }
  await expectCode(
    review.reviewPaymentProofCore(db, "ghost", { paymentId: "p1", decision: "approve" }),
    "permission-denied",
  );
  await expectCode(
    review.reviewPaymentProofCore(db, undefined, { paymentId: "p1", decision: "approve" }),
    "unauthenticated",
  );
  assert.equal((await data("payments/p1")).reviewStatus, "pending_review");

  const result = await review.reviewPaymentProofCore(db, "sup1", {
    paymentId: "p2",
    decision: "reject",
    notes: "unclear image",
  });
  assert.equal(result.reviewStatus, "rejected");
  const doc = await data("payments/p2");
  assert.equal(doc.status, "due");
  assert.equal(doc.reviewedBy, "sup1");
  assert.equal(doc.reviewNotes, "unclear image");
  const [log] = (await db.collection("auditLogs").get()).docs;
  assert.equal(log.data().actorRole, "supervisor");
});

test("PH02 payment: not pending / wrong family / missing / bad input fail closed", async () => {
  await seed({
    "payments/due": pendingPayment({ reviewStatus: null }),
    "payments/cross": pendingPayment({ parentId: "parent2", studentId: "student1" }),
    "payments/p3": pendingPayment(),
  });
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "due", decision: "approve" }),
    "failed-precondition",
  );
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "cross", decision: "approve" }),
    "failed-precondition",
  );
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "nope", decision: "approve" }),
    "not-found",
  );
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", { paymentId: "p3", decision: "paid" }),
    "invalid-argument",
  );
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", {
      paymentId: "p3",
      decision: "partial",
      amountPaidConfirmed: 500,
    }),
    "invalid-argument",
  );
  const partial = await review.reviewPaymentProofCore(db, "admin1", {
    paymentId: "p3",
    decision: "partial",
    amountPaidConfirmed: 50,
  });
  assert.equal(partial.status, "due");
  const doc = await data("payments/p3");
  assert.equal(doc.remainingAmount, 150);
  assert.equal(doc.amountPaidConfirmed, 50);
  assert.equal(await auditCount("payment_review"), 1);
});

// ── Repeated partial payments: current contract (idempotent, proof-bound) ──

const PROOF_A = "1790000000000.jpg";
const PROOF_B = "1790000100000.jpg";

function proofPayment(overrides = {}) {
  return pendingPayment({
    proofFileName: PROOF_A,
    proofSubmittedAt: Timestamp.fromMillis(1_790_000_000_000),
    ...overrides,
  });
}

function currentReview(uid, overrides = {}) {
  return review.reviewPaymentProofCore(db, uid, {
    paymentId: "p1",
    decision: "partial",
    requestId: "req_aaaaaaaaaaaaaaaa",
    expectedProofFileName: PROOF_A,
    amountMode: "receipt",
    amountValue: 60,
    ...overrides,
  });
}

/** Parent resubmission as Rules allow it: proof fields + pending_review only. */
async function resubmit(fileName, millis) {
  await db.doc("payments/p1").update({
    proofFileName: fileName,
    proofStoragePath: `payment_proofs/parent1/p1/${fileName}`,
    proofSubmittedAt: Timestamp.fromMillis(millis),
    reviewStatus: "pending_review",
  });
}

async function auditEntries() {
  const snap = await db.collection("auditLogs").where("action", "==", "payment_review").get();
  return snap.docs.map((d) => d.data()).sort(
    (a, b) => a.metadata.amountPaidConfirmed - b.metadata.amountPaidConfirmed,
  );
}

async function requestCount() {
  return (await db.collection("paymentReviewRequests").get()).size;
}

test("PH02 partial cycle: receipt → resubmit → receipt → resubmit → approve", async () => {
  await seed({ "payments/p1": proofPayment() });

  const first = await currentReview("admin1");
  assert.equal(first.amountPaidConfirmed, 60);
  assert.equal(first.remainingAmount, 140);
  assert.equal(first.receiptAmount, 60);
  assert.equal(first.replayed, false);

  await resubmit(PROOF_B, 1_790_000_100_000);
  const second = await currentReview("sup1", {
    requestId: "req_bbbbbbbbbbbbbbbb",
    expectedProofFileName: PROOF_B,
    amountValue: 50,
  });
  assert.equal(second.previousAmountPaidConfirmed, 60);
  assert.equal(second.amountPaidConfirmed, 110);
  assert.equal(second.remainingAmount, 90);

  await resubmit("1790000200000.png", 1_790_000_200_000);
  const closed = await currentReview("admin1", {
    requestId: "req_cccccccccccccccc",
    expectedProofFileName: "1790000200000.png",
    decision: "approve",
    amountMode: undefined,
    amountValue: undefined,
  });
  assert.equal(closed.status, "paid");
  assert.equal(closed.receiptAmount, 90);

  const doc = await data("payments/p1");
  assert.equal(doc.status, "paid");
  assert.equal(doc.amountPaidConfirmed, 200);
  assert.equal(doc.remainingAmount, 0);
  assert.equal(doc.amount, 200);

  const entries = await auditEntries();
  assert.equal(entries.length, 3);
  assert.deepEqual(
    entries.map((e) => [
      e.metadata.amountMode,
      e.metadata.amount,
      e.metadata.receiptAmount,
      e.metadata.previousAmountPaidConfirmed,
      e.metadata.amountPaidConfirmed,
      e.metadata.remainingAmount,
    ]),
    [
      ["receipt", 200, 60, 0, 60, 140],
      ["receipt", 200, 50, 60, 110, 90],
      ["approve_remaining", 200, 90, 110, 200, 0],
    ],
  );
  assert.deepEqual(entries.map((e) => e.metadata.requestId), [
    "req_aaaaaaaaaaaaaaaa",
    "req_bbbbbbbbbbbbbbbb",
    "req_cccccccccccccccc",
  ]);
  for (const entry of entries) {
    const raw = JSON.stringify(entry);
    assert.ok(!raw.includes("payment_proofs/"), "audit must not carry the proof path");
    assert.ok(!raw.includes(".jpg") && !raw.includes(".png"), "audit must not carry the proof name");
  }
  assert.equal(await requestCount(), 3);
});

test("PH02 partial cumulative mode stores the entered total", async () => {
  await seed({ "payments/p1": proofPayment({ amountPaidConfirmed: 60, remainingAmount: 140 }) });
  const result = await currentReview("admin1", { amountMode: "cumulative", amountValue: 150 });
  assert.equal(result.previousAmountPaidConfirmed, 60);
  assert.equal(result.amountPaidConfirmed, 150);
  assert.equal(result.receiptAmount, 90);

  await resubmit(PROOF_B, 1_790_000_100_000);
  await expectCode(
    currentReview("admin1", {
      requestId: "req_dddddddddddddddd",
      expectedProofFileName: PROOF_B,
      amountMode: "cumulative",
      amountValue: 120,
    }),
    "invalid-argument",
  );
  assert.equal((await data("payments/p1")).amountPaidConfirmed, 150);
});

test("PH02 idempotency: same requestId + content replays without a second review", async () => {
  await seed({ "payments/p1": proofPayment() });
  const first = await currentReview("admin1");
  const replay = await currentReview("admin1");
  assert.equal(replay.replayed, true);
  assert.deepEqual({ ...replay, replayed: false }, first);

  // Still a replay after the Parent resubmits: the stored result is returned
  // and the newer proof stays pending, untouched.
  await resubmit(PROOF_B, 1_790_000_100_000);
  const late = await currentReview("admin1");
  assert.equal(late.replayed, true);
  assert.equal(late.amountPaidConfirmed, 60);

  const doc = await data("payments/p1");
  assert.equal(doc.reviewStatus, "pending_review");
  assert.equal(doc.amountPaidConfirmed, 60);
  assert.equal(await auditCount("payment_review"), 1);
  assert.equal(await requestCount(), 1);
});

test("PH02 idempotency: reusing a requestId with different content is refused", async () => {
  await seed({ "payments/p1": proofPayment() });
  await currentReview("admin1");
  for (const change of [
    { amountValue: 61 },
    { amountMode: "cumulative" },
    { notes: "different" },
    { decision: "reject", amountMode: undefined, amountValue: undefined },
  ]) {
    await assert.rejects(currentReview("admin1", change), (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.equal(err.message, review.REQUEST_ID_REUSED_MESSAGE);
      return true;
    });
  }
  // Another reviewer's identical requestId is a separate key, never a replay.
  await expectCode(currentReview("sup1"), "failed-precondition");
  assert.equal((await data("payments/p1")).amountPaidConfirmed, 60);
  assert.equal(await auditCount("payment_review"), 1);
});

test("PH02 proof binding: a request for an older proof never reviews a newer one", async () => {
  await seed({ "payments/p1": proofPayment({ amountPaidConfirmed: 60, remainingAmount: 140 }) });
  await resubmit(PROOF_B, 1_790_000_100_000);
  await assert.rejects(currentReview("admin1", { amountValue: 20 }), (err) => {
    assert.equal(err.code, "failed-precondition");
    assert.equal(err.message, review.PROOF_CHANGED_MESSAGE);
    return true;
  });
  const doc = await data("payments/p1");
  assert.equal(doc.amountPaidConfirmed, 60);
  assert.equal(doc.reviewStatus, "pending_review");
  assert.equal(await auditCount("payment_review"), 0);
  assert.equal(await requestCount(), 0);

  await seed({ "payments/p2": pendingPayment() });
  await expectCode(
    currentReview("admin1", { paymentId: "p2", requestId: "req_eeeeeeeeeeeeeeee" }),
    "failed-precondition",
  );
});

test("PH02 concurrency: same requestId in parallel applies the receipt once", async () => {
  await seed({ "payments/p1": proofPayment() });
  // The emulator may close a contending transaction instead of retrying it;
  // the invariant is that the receipt lands once and a retry replays it.
  const settled = await Promise.allSettled([1, 2, 3].map(() => currentReview("admin1")));
  const fulfilled = settled.filter((r) => r.status === "fulfilled").map((r) => r.value);
  assert.equal(fulfilled.filter((r) => r.replayed === false).length, 1);
  assert.ok(fulfilled.every((r) => r.amountPaidConfirmed === 60));
  const retry = await currentReview("admin1");
  assert.equal(retry.replayed, true);
  assert.equal(retry.amountPaidConfirmed, 60);
  assert.equal(retry.receiptAmount, 60);
  assert.equal((await data("payments/p1")).amountPaidConfirmed, 60);
  assert.equal(await auditCount("payment_review"), 1);
  assert.equal(await requestCount(), 1);
});

test("PH02 concurrency: different requests on one proof commit exactly once", async () => {
  await seed({ "payments/p1": proofPayment() });
  const results = await Promise.allSettled([
    currentReview("admin1", { requestId: "req_1111111111111111", amountValue: 60 }),
    currentReview("sup1", { requestId: "req_2222222222222222", amountValue: 70 }),
    currentReview("admin1", { requestId: "req_3333333333333333", amountMode: "cumulative", amountValue: 80 }),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  const winner = results.find((r) => r.status === "fulfilled").value;
  assert.equal((await data("payments/p1")).amountPaidConfirmed, winner.amountPaidConfirmed);
  assert.equal(await auditCount("payment_review"), 1);
  assert.equal(await requestCount(), 1);
});

test("PH02 reject keeps confirmed totals and records no receipt", async () => {
  await seed({ "payments/p1": proofPayment({ amountPaidConfirmed: 60, remainingAmount: 140 }) });
  const result = await currentReview("admin1", {
    decision: "reject",
    amountMode: undefined,
    amountValue: undefined,
    notes: "unclear",
  });
  assert.equal(result.receiptAmount, null);
  assert.equal(result.amountMode, "reject_unchanged");
  const doc = await data("payments/p1");
  assert.equal(doc.reviewStatus, "rejected");
  assert.equal(doc.amountPaidConfirmed, 60);
  assert.equal(doc.remainingAmount, 140);
  const [entry] = await auditEntries();
  assert.equal(entry.metadata.amountMode, "reject_unchanged");
  assert.ok(!("receiptAmount" in entry.metadata));
  assert.equal(entry.metadata.previousAmountPaidConfirmed, 60);
  assert.equal(entry.metadata.amountPaidConfirmed, 60);
  assert.equal(entry.metadata.remainingAmount, 140);
});

test("PH02 legacy contract: cumulative total may not shrink; no request record", async () => {
  await seed({ "payments/p1": proofPayment({ amountPaidConfirmed: 60, remainingAmount: 140 }) });
  await expectCode(
    review.reviewPaymentProofCore(db, "admin1", {
      paymentId: "p1",
      decision: "partial",
      amountPaidConfirmed: 40,
    }),
    "invalid-argument",
  );
  const result = await review.reviewPaymentProofCore(db, "admin1", {
    paymentId: "p1",
    decision: "partial",
    amountPaidConfirmed: 100,
  });
  assert.equal(result.amountMode, "legacy_cumulative");
  assert.equal(result.receiptAmount, 40);
  assert.equal((await data("payments/p1")).remainingAmount, 100);
  assert.equal(await requestCount(), 0);
});

test("PH02 current contract: missing idempotency fields are invalid", async () => {
  await seed({ "payments/p1": proofPayment() });
  await expectCode(currentReview("admin1", { requestId: undefined }), "invalid-argument");
  await expectCode(currentReview("admin1", { expectedProofFileName: undefined }), "invalid-argument");
  assert.equal((await data("payments/p1")).reviewStatus, "pending_review");
});

// ── C6 attendance ──────────────────────────────────────────────────────────

function attendance(uid, marks, now = IN_WINDOW, date = MONDAY) {
  return sessions.recordSessionAttendanceCore(db, uid, { halaqaId: "h1", date, marks }, now);
}

test("PH02 attendance: Teacher binds marks to a real session + parent fan-out", async () => {
  const result = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
    { studentId: "student2", status: "absent" },
  ]);
  assert.match(result.sessionId, /^sess_/);
  assert.equal(result.savedCount, 2);
  assert.equal(result.correction, false);

  const session = await data(`sessions/${result.sessionId}`);
  assert.equal(session.halaqaId, "h1");
  assert.equal(session.date, MONDAY);

  const mark = await data(`attendanceRecords/${result.sessionId}_student1`);
  assert.equal(mark.sessionId, result.sessionId);
  assert.equal(mark.recordedBy, "teacher1");
  assert.equal(mark.status, "present");
  assert.equal(mark.studentName, "Student One");

  // Absence → linked parent only; ids-only payload.
  assert.equal(result.notificationCount, 1);
  const cards = await db.collection("notifications").get();
  assert.equal(cards.size, 1);
  const card = cards.docs[0].data();
  assert.equal(card.audience, "parent2");
  assert.equal(card.data.studentId, "student2");
  assert.equal(card.data.sessionId, result.sessionId);
  assert.ok(!Object.values(card.data).join("|").includes("Student Two"));
});

test("PH02 attendance: resave is idempotent (no duplicate docs or cards)", async () => {
  const marks = [{ studentId: "student2", status: "absent" }];
  const first = await attendance("teacher1", marks);
  const second = await attendance("teacher1", marks);
  assert.equal(second.sessionId, first.sessionId);
  assert.equal(second.notificationCount, 0);
  assert.equal((await db.collection("attendanceRecords").get()).size, 1);
  assert.equal((await db.collection("notifications").get()).size, 1);
  assert.equal((await db.collection("sessions").get()).size, 1);
});

test("PH02 attendance: wrong teacher / roster / role denied, nothing written", async () => {
  await expectCode(
    attendance("teacher2", [{ studentId: "student1", status: "present" }]),
    "permission-denied",
  );
  for (const uid of ["sup1", "parent1", "student1"]) {
    await expectCode(
      attendance(uid, [{ studentId: "student1", status: "present" }]),
      "permission-denied",
    );
  }
  await expectCode(
    attendance("teacher1", [
      { studentId: "student1", status: "present" },
      { studentId: "student3", status: "present" },
    ]),
    "invalid-argument",
  );
  await expectCode(
    attendance("teacher1", [{ studentId: "student1", status: "vip" }]),
    "invalid-argument",
  );
  assert.equal((await db.collection("attendanceRecords").get()).size, 0);
});

test("PH02 attendance: edit window — Teacher frozen after the day, Admin corrects", async () => {
  await expectCode(
    attendance("teacher1", [{ studentId: "student1", status: "present" }], AFTER_WINDOW),
    "failed-precondition",
  );
  const corrected = await attendance(
    "admin1",
    [{ studentId: "student1", status: "late" }],
    AFTER_WINDOW,
  );
  assert.equal(corrected.correction, true);
  assert.equal(await auditCount("attendance_correct"), 1);

  // Future day and a day without a scheduled slot are rejected.
  await expectCode(
    attendance("teacher1", [{ studentId: "student1", status: "present" }], IN_WINDOW, "2026-10-05"),
    "failed-precondition",
  );
  await expectCode(
    attendance("teacher1", [{ studentId: "student1", status: "present" }], IN_WINDOW, "2026-09-27"),
    "failed-precondition",
  );
});

test("PH02 attendance: legacy synthetic duplicates retired, history preserved", async () => {
  const range = records.cairoDayRange(MONDAY);
  const previousDay = records.cairoDayRange("2026-09-21");
  await seed({
    "attendanceRecords/h1_20260928_student1": {
      studentId: "student1",
      halaqaId: "h1",
      date: Timestamp.fromDate(range.start),
      status: "absent",
      sessionId: "h1_20260928",
    },
    "attendanceRecords/h1_20260921_student1": {
      studentId: "student1",
      halaqaId: "h1",
      date: Timestamp.fromDate(previousDay.start),
      status: "present",
      sessionId: "h1_20260921",
    },
  });
  const result = await attendance("teacher1", [{ studentId: "student1", status: "present" }]);
  assert.equal(result.retiredCount, 1);
  assert.equal((await db.doc("attendanceRecords/h1_20260928_student1").get()).exists, false);
  assert.equal((await db.doc("attendanceRecords/h1_20260921_student1").get()).exists, true);
  // absent → present is a correction card for the linked parent.
  assert.equal(result.notificationCount, 1);
});

test("PH02 attendance: slot without slotId fails closed (WA-7 prerequisite)", async () => {
  await db.doc("halaqat/h1").update({
    schedule: [{ day: "monday", startTime: "16:00", endTime: "17:00" }],
  });
  await expectCode(
    attendance("teacher1", [{ studentId: "student1", status: "present" }]),
    "failed-precondition",
  );
});

// ── C6 / D7 evaluation ─────────────────────────────────────────────────────

function evaluate(uid, overrides = {}, now = undefined) {
  return sessions.upsertSessionEvaluationCore(
    db,
    uid,
    {
      halaqaId: "h1",
      studentId: "student1",
      type: "memorization",
      grade: "excellent",
      behaviorGrade: "good",
      date: MONDAY,
      ...overrides,
    },
    now,
  );
}

test("PH02 evaluation: Present student on a real session is evaluable", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const result = await evaluate("teacher1");
  assert.equal(result.sessionId, sessionId);
  assert.equal(result.evaluationId, `${sessionId}_student1_memorization`);
  const doc = await data(`recitationRecords/${result.evaluationId}`);
  assert.equal(doc.grade, records.GRADE_LABELS.excellent);
  assert.equal(doc.behaviorGrade, records.GRADE_LABELS.good);
  assert.equal(doc.teacherId, "teacher1");
  assert.equal(doc.reviewStatus, "reviewed");

  // Explicit real session id is accepted and upserts the same document.
  const again = await evaluate("teacher1", { sessionId, grade: "veryGood" });
  assert.equal(again.evaluationId, result.evaluationId);
  assert.equal((await db.collection("recitationRecords").get()).size, 1);
});

test("PH02 evaluation: Late allowed; Absent / unmarked denied (D7)", async () => {
  await attendance("teacher1", [
    { studentId: "student1", status: "late" },
    { studentId: "student2", status: "absent" },
  ]);
  await evaluate("teacher1");
  await expectCode(evaluate("teacher1", { studentId: "student2" }), "failed-precondition");
  await expectCode(evaluate("teacher1", { date: "2026-09-21" }), "failed-precondition");
});

test("PH02 evaluation: synthetic / foreign / missing session denied", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  await expectCode(evaluate("teacher1", { sessionId: "h1_20260928" }), "invalid-argument");
  await expectCode(evaluate("teacher1", { sessionId: "sess_ghost" }), "not-found");
  await seed({
    "sessions/sess_foreign": { halaqaId: "h2", date: MONDAY, status: "scheduled" },
  });
  await expectCode(evaluate("teacher1", { sessionId: "sess_foreign" }), "failed-precondition");
  await db.doc(`sessions/${sessionId}`).update({ status: "cancelled" });
  await expectCode(evaluate("teacher1", { sessionId }), "failed-precondition");
  assert.equal((await db.collection("recitationRecords").get()).size, 0);
});

test("PH02 evaluation: wrong student / cross-halaqa teacher / non-teacher denied", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  await expectCode(
    evaluate("teacher1", { sessionId, studentId: "student3" }),
    "invalid-argument",
  );
  await expectCode(evaluate("teacher2", { sessionId }), "permission-denied");
  for (const uid of ["sup1", "sup2", "parent1", "student1"]) {
    await expectCode(evaluate(uid, { sessionId }), "permission-denied");
  }
  await expectCode(evaluate("teacher1", { sessionId, grade: "A+" }), "invalid-argument");
  await expectCode(evaluate("teacher1", { sessionId, type: "tajweed" }), "invalid-argument");
});

test("PH02 evaluation: same-day legacy live duplicates retired, submissions kept", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const range = records.cairoDayRange(MONDAY);
  const base = {
    studentId: "student1",
    halaqaId: "h1",
    type: "memorization",
    date: Timestamp.fromDate(range.start),
  };
  await seed({
    "recitationRecords/h1_20260928_student1_memorization": {
      ...base,
      sessionId: "h1_20260928",
      reviewStatus: "reviewed",
    },
    "recitationRecords/submission1": {
      ...base,
      assignmentId: "hw1",
      reviewStatus: "pending",
    },
  });
  const result = await evaluate("teacher1", { sessionId });
  assert.equal(result.retiredCount, 1);
  assert.equal(
    (await db.doc("recitationRecords/h1_20260928_student1_memorization").get()).exists,
    false,
  );
  assert.equal((await db.doc("recitationRecords/submission1").get()).exists, true);
});

async function evaluationAudits() {
  return (
    await db
      .collection("auditLogs")
      .where("action", "==", "evaluation_create_or_correct")
      .orderBy("timestamp")
      .get()
  ).docs.map((d) => d.data());
}

test("PH02 C16: evaluation create + correction audited by a server-derived teacher actor", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const created = await evaluate("teacher1", { actorRole: "admin", actorId: "admin1" });
  let logs = await evaluationAudits();
  assert.equal(logs.length, 1);
  assert.equal(logs[0].actorId, "teacher1");
  assert.equal(logs[0].actorRole, "teacher");
  assert.equal(logs[0].targetType, "evaluation");
  assert.equal(logs[0].targetId, created.evaluationId);
  assert.equal(logs[0].source, "upsertSessionEvaluation");
  assert.deepEqual(logs[0].metadata, {
    sessionId,
    halaqaId: "h1",
    studentId: "student1",
    evaluationType: "memorization",
    versesRange: "",
    operation: "create",
  });

  // Identical replay: no business change → no duplicate audit.
  await evaluate("teacher1", { sessionId });
  assert.equal((await evaluationAudits()).length, 1);

  await evaluate("teacher1", { sessionId, grade: "veryGood" });
  await evaluate("teacher1", { sessionId, grade: "veryGood", notes: "راجع الآية" });
  logs = await evaluationAudits();
  assert.equal(logs.length, 3);
  assert.deepEqual(
    logs.map((l) => l.metadata.operation),
    ["create", "correct", "correct"],
  );
  for (const log of logs) {
    assert.ok(!("notes" in log.metadata), "free-text notes are never audited");
    assert.ok(!("grade" in log.metadata));
  }
});

test("PH02 C16: denied evaluations (Supervisor / wrong teacher / others) write no audit", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  for (const uid of ["sup1", "teacher2", "parent1", "student1"]) {
    await expectCode(evaluate(uid, { sessionId }), "permission-denied");
  }
  assert.equal((await evaluationAudits()).length, 0);
  assert.equal((await db.collection("recitationRecords").get()).size, 0);
});

// ── B1 Teacher 24h edit window / B2 Admin correction ──────────────────────

const HOUR = 60 * 60_000;

async function createdAtOf(evaluationId) {
  const raw = (await data(`recitationRecords/${evaluationId}`)).createdAt;
  assert.ok(raw instanceof Timestamp, "createdAt must be a server timestamp");
  return raw.toDate();
}

test("PH02 B1: Teacher edits inside 24h, denied at/after 24h (server anchor)", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const { evaluationId } = await evaluate("teacher1", { sessionId });
  const createdAt = await createdAtOf(evaluationId);

  const justBefore = new Date(createdAt.getTime() + 24 * HOUR - 1);
  await evaluate("teacher1", { sessionId, grade: "veryGood" }, justBefore);
  assert.equal(
    (await data(`recitationRecords/${evaluationId}`)).grade,
    records.GRADE_LABELS.veryGood,
  );
  // A correction never moves the anchor.
  assert.equal((await createdAtOf(evaluationId)).getTime(), createdAt.getTime());

  for (const at of [24 * HOUR, 24 * HOUR + 1, 72 * HOUR]) {
    await expectCode(
      evaluate("teacher1", { sessionId, grade: "good" }, new Date(createdAt.getTime() + at)),
      "failed-precondition",
    );
  }
  assert.equal(
    (await data(`recitationRecords/${evaluationId}`)).grade,
    records.GRADE_LABELS.veryGood,
  );
  assert.equal((await evaluationAudits()).length, 2);
});

test("PH02 B1: client-supplied timestamps cannot reopen the window", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const { evaluationId } = await evaluate("teacher1", { sessionId });
  const createdAt = await createdAtOf(evaluationId);
  const late = new Date(createdAt.getTime() + 25 * HOUR);
  const forged = {
    sessionId,
    grade: "good",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    now: createdAt.toISOString(),
    date: MONDAY,
  };
  await expectCode(evaluate("teacher1", forged, late), "failed-precondition");

  // Inside the window the forged fields are simply ignored.
  await evaluate("teacher1", { ...forged, grade: "veryGood" });
  assert.equal((await createdAtOf(evaluationId)).getTime(), createdAt.getTime());
});

test("PH02 B1: an evaluation without a server anchor is Admin-correct only", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const evaluationId = `${sessionId}_student1_memorization`;
  await seed({
    [`recitationRecords/${evaluationId}`]: {
      studentId: "student1",
      halaqaId: "h1",
      teacherId: "teacher1",
      type: "memorization",
      sessionId,
      grade: records.GRADE_LABELS.good,
      behaviorGrade: records.GRADE_LABELS.good,
      reviewStatus: "reviewed",
    },
  });
  await expectCode(evaluate("teacher1", { sessionId }), "failed-precondition");
  await evaluate("admin1", { sessionId });
  assert.equal((await data(`recitationRecords/${evaluationId}`)).createdAt, undefined);
});

test("PH02 B1: a non-live document at the evaluation id is never adopted", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const evaluationId = `${sessionId}_student1_memorization`;
  const squat = {
    studentId: "student1",
    halaqaId: "h1",
    type: "memorization",
    createdAt: Timestamp.fromDate(new Date(2030, 0, 1)),
  };
  for (const variant of [
    { ...squat, assignmentId: "hw1", reviewStatus: "reviewed", sessionId },
    { ...squat, reviewStatus: "pending", sessionId },
    { ...squat, reviewStatus: "reviewed" },
  ]) {
    await db.doc(`recitationRecords/${evaluationId}`).set(variant);
    for (const uid of ["teacher1", "admin1"]) {
      await expectCode(evaluate(uid, { sessionId }), "failed-precondition");
    }
  }
  assert.equal((await evaluationAudits()).length, 0);
});

test("PH02 B2: Admin creates and corrects after the Teacher window, audited", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
    { studentId: "student2", status: "late" },
  ]);
  // Admin create: ownership stays with the halaqa Teacher.
  const adminCreated = await evaluate("admin1", { sessionId, studentId: "student2" });
  const adminDoc = await data(`recitationRecords/${adminCreated.evaluationId}`);
  assert.equal(adminDoc.teacherId, "teacher1");
  assert.ok(adminDoc.createdAt instanceof Timestamp);

  const { evaluationId } = await evaluate("teacher1", { sessionId });
  const createdAt = await createdAtOf(evaluationId);
  const afterWindow = new Date(createdAt.getTime() + 48 * HOUR);
  await expectCode(
    evaluate("teacher1", { sessionId, grade: "good" }, afterWindow),
    "failed-precondition",
  );
  await evaluate(
    "admin1",
    { sessionId, grade: "needsRetry", actorRole: "teacher" },
    afterWindow,
  );
  const doc = await data(`recitationRecords/${evaluationId}`);
  assert.equal(doc.grade, records.GRADE_LABELS.needsRetry);
  assert.equal(doc.teacherId, "teacher1");
  assert.equal((await createdAtOf(evaluationId)).getTime(), createdAt.getTime());

  const logs = await evaluationAudits();
  assert.deepEqual(
    logs.map((l) => [l.actorRole, l.metadata.operation, l.metadata.studentId]),
    [
      ["admin", "create", "student2"],
      ["teacher", "create", "student1"],
      ["admin", "correct", "student1"],
    ],
  );
  const adminLog = logs[2];
  assert.equal(adminLog.actorId, "admin1");
  assert.equal(adminLog.targetId, evaluationId);
  assert.equal(adminLog.metadata.sessionId, sessionId);
  assert.ok(!("grade" in adminLog.metadata) && !("notes" in adminLog.metadata));

  // Identical Admin replay: no change, no second audit.
  await evaluate("admin1", { sessionId, grade: "needsRetry" }, afterWindow);
  assert.equal((await evaluationAudits()).length, 3);
});

test("PH02 B2: Admin correction keeps every session / attendance / roster gate", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
    { studentId: "student2", status: "absent" },
  ]);
  await expectCode(evaluate("admin1", { sessionId, studentId: "student2" }), "failed-precondition");
  await expectCode(evaluate("admin1", { sessionId, studentId: "student3" }), "invalid-argument");
  await expectCode(evaluate("admin1", { sessionId: "h1_20260928" }), "invalid-argument");
  await expectCode(evaluate("admin1", { sessionId: "sess_ghost" }), "not-found");
  await seed({
    "sessions/sess_foreign": { halaqaId: "h2", date: MONDAY, status: "scheduled" },
  });
  await expectCode(evaluate("admin1", { sessionId: "sess_foreign" }), "failed-precondition");
  await db.doc(`sessions/${sessionId}`).update({ status: "cancelled" });
  await expectCode(evaluate("admin1", { sessionId }), "failed-precondition");
  assert.equal((await db.collection("recitationRecords").get()).size, 0);
  assert.equal((await evaluationAudits()).length, 0);
});

test("PH02 B1/B2: concurrent corrections stay transactional and audit once per change", async () => {
  const { sessionId } = await attendance("teacher1", [
    { studentId: "student1", status: "present" },
  ]);
  const { evaluationId } = await evaluate("teacher1", { sessionId });

  // Duplicate Teacher correction fired twice at once → one effective change.
  await Promise.all([
    evaluate("teacher1", { sessionId, grade: "veryGood" }),
    evaluate("teacher1", { sessionId, grade: "veryGood" }),
  ]);
  assert.equal((await evaluationAudits()).length, 2);

  // Two different Admin corrections after the window serialize: both commit,
  // each audited, and the document holds exactly one of the outcomes.
  const afterWindow = new Date((await createdAtOf(evaluationId)).getTime() + 30 * HOUR);
  await Promise.all([
    evaluate("admin1", { sessionId, grade: "good" }, afterWindow),
    evaluate("admin1", { sessionId, grade: "needsRetry" }, afterWindow),
  ]);
  const logs = await evaluationAudits();
  assert.equal(logs.length, 4);
  assert.ok(
    [records.GRADE_LABELS.good, records.GRADE_LABELS.needsRetry].includes(
      (await data(`recitationRecords/${evaluationId}`)).grade,
    ),
  );
  assert.equal(
    (await db.collection("recitationRecords").where("studentId", "==", "student1").get()).size,
    1,
  );
});

// ── C11 FCM fan-out ────────────────────────────────────────────────────────

function fakeSender() {
  const calls = [];
  const sender = async ({ notification, tokens }) => {
    calls.push({ notification, tokens });
    return tokens.map((t) => ({
      deviceId: t.deviceId,
      success: t.token !== "tok-dead",
      errorCode: t.token === "tok-dead" ? "messaging/registration-token-not-registered" : undefined,
    }));
  };
  return { calls, sender };
}

const liveEvaluation = {
  studentId: "student1",
  halaqaId: "h1",
  teacherId: "teacher1",
  sessionId: "sess_x",
  type: "memorization",
  grade: "excellent-label",
  reviewStatus: "reviewed",
};

async function seedDevices() {
  const token = (value, extra = {}) => ({ token: value, platform: "android", ...extra });
  await seed({
    "fcmTokens/parent1/devices/d1": token("tok-a"),
    "fcmTokens/parent1/devices/d2": token("tok-dead"),
    "fcmTokens/parent1/devices/d3": token("tok-off", { disabled: true }),
    "fcmTokens/parent1/devices/d4": token("tok-a"),
    "fcmTokens/parent2/devices/e1": token("tok-p2"),
  });
}

test("PH02 FCM: evaluation reaches the linked parent's devices only", async () => {
  await seedDevices();
  const { calls, sender } = fakeSender();
  await evalFanOut.handleRecitationRecordWrite({
    db,
    recordId: "rec1",
    before: null,
    after: liveEvaluation,
    sender,
  });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].notification.audience, "parent1");
  // Disabled device skipped; duplicate token sent once.
  assert.deepEqual(
    calls[0].tokens.map((t) => t.deviceId),
    ["d1", "d2"],
  );
  const payload = Object.values(calls[0].notification.data).join("|");
  assert.ok(!payload.includes("Student One"));
  assert.ok(!payload.includes("excellent-label"));
  assert.ok(!(await db.collection("notifications").where("audience", "==", "parent2").get()).size);

  // Invalid token disabled, delivery terminal.
  assert.equal((await data("fcmTokens/parent1/devices/d2")).disabled, true);
  assert.equal((await data("fcmTokens/parent1/devices/d1")).disabled, undefined);
  const delivery = await data(`notificationDeliveries/${calls[0].notification.notificationId}`);
  assert.equal(delivery.status, "sent");
  assert.deepEqual(delivery.sentDeviceIds, ["d1"]);
});

test("PH02 FCM: redelivered / edited events never push twice", async () => {
  await seedDevices();
  const { calls, sender } = fakeSender();
  const args = { db, recordId: "rec1", before: null, after: liveEvaluation, sender };
  await evalFanOut.handleRecitationRecordWrite(args);
  await evalFanOut.handleRecitationRecordWrite(args);
  await evalFanOut.handleRecitationRecordWrite({
    ...args,
    before: liveEvaluation,
    after: { ...liveEvaluation, grade: "changed" },
  });
  assert.equal(calls.length, 1);
  assert.equal((await db.collection("notifications").get()).size, 1);
});

test("PH02 FCM: retry after a transient failure skips devices already reached", async () => {
  await seedDevices();
  let first = true;
  const calls = [];
  const sender = async ({ tokens }) => {
    calls.push(tokens.map((t) => t.deviceId));
    const outcome = tokens.map((t) => ({
      deviceId: t.deviceId,
      success: t.deviceId === "d1" || !first,
      errorCode: t.deviceId === "d1" || !first ? undefined : "messaging/internal-error",
    }));
    first = false;
    return outcome;
  };
  const args = { db, recordId: "rec2", before: null, after: liveEvaluation, sender };
  await evalFanOut.handleRecitationRecordWrite(args);
  await evalFanOut.handleRecitationRecordWrite(args);
  assert.deepEqual(calls, [["d1", "d2"], ["d2"]]);
});

test("PH02 FCM: no linked parent → nothing sent; forged recipient impossible", async () => {
  await seedDevices();
  const { calls, sender } = fakeSender();
  await evalFanOut.handleRecitationRecordWrite({
    db,
    recordId: "rec3",
    before: null,
    // Client-supplied recipient hints are not part of the recipient chain.
    after: { ...liveEvaluation, studentId: "student3", parentId: "parent1", audience: "parent1" },
    sender,
  });
  assert.equal(calls.length, 0);
  assert.equal((await db.collection("notifications").get()).size, 0);
});

test("PH02 FCM: homework review fans out in-app to student + parents (no push)", async () => {
  const { calls, sender } = fakeSender();
  const before = { ...liveEvaluation, assignmentId: "hw1", reviewStatus: "pending" };
  await evalFanOut.handleRecitationRecordWrite({
    db,
    recordId: "sub1",
    before,
    after: { ...before, reviewStatus: "reviewed" },
    sender,
  });
  assert.equal(calls.length, 0);
  const audiences = (await db.collection("notifications").get()).docs
    .map((d) => d.data().audience)
    .sort();
  assert.deepEqual(audiences, ["parent1", "student1"]);
});

test("PH02 fan-out: assignment author must be the halaqa teacher", async () => {
  const forged = await assignmentFanOut.fanOutAssignmentCreated(db, "a1", {
    halaqaId: "h1",
    assignedBy: "teacher2",
    studentId: "student1",
    kind: "lessonHomework",
  });
  assert.equal(forged.written, 0);
  assert.equal(forged.skipped, "author_not_halaqa_teacher");

  const offRoster = await assignmentFanOut.fanOutAssignmentCreated(db, "a2", {
    halaqaId: "h1",
    assignedBy: "teacher1",
    studentId: "student3",
    kind: "lessonHomework",
  });
  assert.equal(offRoster.written, 0);

  const homework = await assignmentFanOut.fanOutAssignmentCreated(db, "a3", {
    halaqaId: "h1",
    assignedBy: "teacher1",
    studentId: "student1",
    kind: "lessonHomework",
  });
  assert.equal(homework.written, 2);

  const activity = await assignmentFanOut.fanOutAssignmentCreated(db, "act1", {
    halaqaId: "h1",
    assignedBy: "teacher1",
    studentId: "",
    kind: "halaqaActivity",
    prompt: "p",
  });
  assert.equal(activity.written, 4);
  const again = await assignmentFanOut.fanOutAssignmentCreated(db, "act1", {
    halaqaId: "h1",
    assignedBy: "teacher1",
    studentId: "",
    kind: "halaqaActivity",
    prompt: "p",
  });
  assert.equal(again.written, 4);
  assert.equal((await db.collection("notifications").get()).size, 6);
});

// ── Halaqa membership (max 2) ──────────────────────────────────────────────

test("PH02 membership: 1st + 2nd allowed, 3rd rejected, duplicate rejected", async () => {
  const first = await membership.admitStudentToHalaqaCore(db, "admin1", {
    studentId: "student3",
    halaqaId: "h2",
  });
  assert.equal(first.membershipCount, 1);
  assert.equal(first.primaryHalaqaId, "h2");
  assert.equal((await data("studentProfiles/student3")).halaqaId, "h2");

  await expectCode(
    membership.admitStudentToHalaqaCore(db, "admin1", { studentId: "student3", halaqaId: "h2" }),
    "already-exists",
  );

  const second = await membership.admitStudentToHalaqaCore(db, "admin1", {
    studentId: "student3",
    halaqaId: "h1",
  });
  assert.equal(second.membershipCount, 2);
  assert.equal((await data("studentProfiles/student3")).halaqaId, "h2");

  await expectCode(
    membership.admitStudentToHalaqaCore(db, "admin1", { studentId: "student3", halaqaId: "h3" }),
    "failed-precondition",
  );
  assert.deepEqual((await data("halaqat/h3")).studentIds, []);
  assert.equal(await auditCount("student_admit"), 2);
});

test("PH02 membership: Supervisor scoped; other roles / non-students rejected", async () => {
  await expectCode(
    membership.admitStudentToHalaqaCore(db, "sup1", { studentId: "student3", halaqaId: "h2" }),
    "permission-denied",
  );
  for (const uid of ["teacher1", "parent1", "student1"]) {
    await expectCode(
      membership.admitStudentToHalaqaCore(db, uid, { studentId: "student3", halaqaId: "h1" }),
      "permission-denied",
    );
  }
  await expectCode(
    membership.admitStudentToHalaqaCore(db, "admin1", { studentId: "parent1", halaqaId: "h1" }),
    "failed-precondition",
  );
  await expectCode(
    membership.admitStudentToHalaqaCore(db, "admin1", { studentId: "ghost", halaqaId: "h1" }),
    "not-found",
  );
  const ok = await membership.admitStudentToHalaqaCore(db, "sup1", {
    studentId: "student3",
    halaqaId: "h1",
  });
  assert.equal(ok.membershipCount, 1);
  const [log] = (await db.collection("auditLogs").get()).docs;
  assert.equal(log.data().actorRole, "supervisor");
  // Supervisor admission does not activate accounts (Admin-only).
  assert.equal((await data("users/student3")).isActive, true);
});

test("PH02 membership: concurrent admissions cannot exceed the cap", async () => {
  const results = await Promise.allSettled(
    ["h1", "h2", "h3"].map((halaqaId) =>
      membership.admitStudentToHalaqaCore(db, "admin1", { studentId: "student3", halaqaId }),
    ),
  );
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 2);
  const joined = (
    await db.collection("halaqat").where("studentIds", "array-contains", "student3").get()
  ).size;
  assert.equal(joined, 2);
});

test("PH02 membership: Admin transfer is atomic; unscoped Supervisor denied", async () => {
  // h2 is supervised by sup2, so sup1 cannot move a student into it.
  await expectCode(
    membership.adminTransferStudentCore(db, "sup1", {
      studentId: "student1",
      fromHalaqaId: "h1",
      toHalaqaId: "h2",
    }),
    "permission-denied",
  );
  const moved = await membership.adminTransferStudentCore(db, "admin1", {
    studentId: "student1",
    fromHalaqaId: "h1",
    toHalaqaId: "h2",
  });
  assert.equal(moved.primaryHalaqaId, "h2");
  assert.deepEqual((await data("halaqat/h1")).studentIds, ["student2"]);
  assert.deepEqual((await data("halaqat/h2")).studentIds, ["student1"]);
  assert.equal(await auditCount("student_transfer"), 1);
  await expectCode(
    membership.adminTransferStudentCore(db, "admin1", {
      studentId: "student1",
      fromHalaqaId: "h1",
      toHalaqaId: "h3",
    }),
    "failed-precondition",
  );
});

test("PH02 membership: Supervisor transfers only between halaqat they supervise", async () => {
  await seed({
    "halaqat/h4": {
      name: "H4",
      teacherId: "teacher2",
      supervisorId: "sup1",
      studentIds: [],
      schedule: [{ slotId: "slot-thu", day: "thursday", startTime: "16:00", endTime: "17:00" }],
    },
  });
  const move = (uid, fromHalaqaId, toHalaqaId) =>
    membership.adminTransferStudentCore(db, uid, {
      studentId: "student1",
      fromHalaqaId,
      toHalaqaId,
    });

  // Source supervised but target not / neither supervised / non-staff roles.
  await expectCode(move("sup1", "h1", "h3"), "permission-denied");
  await expectCode(move("sup2", "h1", "h4"), "permission-denied");
  for (const uid of ["teacher1", "parent1", "student1"]) {
    await expectCode(move(uid, "h1", "h4"), "permission-denied");
  }
  assert.equal(await auditCount("student_transfer"), 0);
  assert.deepEqual((await data("halaqat/h1")).studentIds, ["student1", "student2"]);

  const moved = await move("sup1", "h1", "h4");
  assert.equal(moved.primaryHalaqaId, "h4");
  assert.deepEqual((await data("halaqat/h1")).studentIds, ["student2"]);
  assert.deepEqual((await data("halaqat/h4")).studentIds, ["student1"]);
  const logs = (
    await db.collection("auditLogs").where("action", "==", "student_transfer").get()
  ).docs.map((d) => d.data());
  assert.equal(logs.length, 1);
  assert.equal(logs[0].actorId, "sup1");
  assert.equal(logs[0].actorRole, "supervisor");
  assert.deepEqual(logs[0].metadata, {
    studentId: "student1",
    fromHalaqaId: "h1",
    toHalaqaId: "h4",
  });
  // Transfer never reactivates or otherwise edits the account.
  assert.equal((await data("users/student1")).isActive, true);
});

// ── Economy ────────────────────────────────────────────────────────────────

async function seedHomework(id, overrides = {}) {
  await seed({
    [`assignments/${id}`]: {
      studentId: "student1",
      halaqaId: "h1",
      assignedBy: "teacher1",
      kind: "lessonHomework",
      isSubmitted: false,
      status: "pending",
      tasks: [
        { id: "t1", kind: "reading", points: 999, isCompleted: true },
        { id: "t2", kind: "listening", points: 999, isCompleted: true },
        { id: "t3", kind: "recitation", points: 999, isCompleted: true, recitationRecordId: "r1" },
      ],
      ...overrides,
    },
    "recitationRecords/r1": {
      studentId: "student1",
      halaqaId: "h1",
      assignmentId: id,
      reviewStatus: "pending",
    },
  });
}

test("PH02 homework: reward derived server-side, credited exactly once", async () => {
  await seedHomework("hw1");
  const result = await economy.completeHomeworkCore(db, "student1", { assignmentId: "hw1" });
  // P0-05: recitation is not required while audio uploads are disabled.
  assert.equal(result.awardedCoins, 35);
  assert.equal(result.awardedPoints, 35);
  const profile = await data("studentProfiles/student1");
  assert.equal(profile.points, 0, "points are quarantined (never credited)");
  assert.equal(profile.coins, 35);
  assert.equal(profile.lastCompletedHomeworkId, "hw1");
  assert.equal((await data("assignments/hw1")).status, "completed");

  const replay = await economy.completeHomeworkCore(db, "student1", { assignmentId: "hw1" });
  assert.equal(replay.alreadyRewarded, true);
  assert.equal(replay.awardedCoins, 0);
  assert.equal((await data("studentProfiles/student1")).coins, 35);
});

test("PH02 homework: concurrent completion credits once", async () => {
  await seedHomework("hw1");
  const results = await Promise.allSettled([
    economy.completeHomeworkCore(db, "student1", { assignmentId: "hw1" }),
    economy.completeHomeworkCore(db, "student1", { assignmentId: "hw1" }),
  ]);
  const fresh = results.filter(
    (r) => r.status === "fulfilled" && r.value.alreadyRewarded === false,
  );
  assert.equal(fresh.length, 1);
  assert.equal((await data("studentProfiles/student1")).coins, 35);
});

test("PH02 homework: incomplete / unsent recitation / foreign / role denied", async () => {
  await seedHomework("hwOpen", {
    tasks: [{ id: "t1", kind: "reading", isCompleted: false }],
  });
  await expectCode(
    economy.completeHomeworkCore(db, "student1", { assignmentId: "hwOpen" }),
    "failed-precondition",
  );
  await seedHomework("hwNoAudio", {
    tasks: [{ id: "t3", kind: "recitation", isCompleted: true, recitationRecordId: "missing" }],
  });
  await expectCode(
    economy.completeHomeworkCore(db, "student1", { assignmentId: "hwNoAudio" }),
    "failed-precondition",
  );
  await seedHomework("hwOther", { studentId: "student2" });
  await expectCode(
    economy.completeHomeworkCore(db, "student1", { assignmentId: "hwOther" }),
    "permission-denied",
  );
  await expectCode(
    economy.completeHomeworkCore(db, "teacher1", { assignmentId: "hwOther" }),
    "permission-denied",
  );
  await seedHomework("act", { kind: "halaqaActivity" });
  await expectCode(
    economy.completeHomeworkCore(db, "student1", { assignmentId: "act" }),
    "failed-precondition",
  );
  assert.equal((await data("studentProfiles/student1")).coins, 0);
});

test("PH02 avatar: valid purchase debits the trusted price atomically", async () => {
  await db.doc("studentProfiles/student1").update({ coins: 600 });
  const result = await economy.purchaseAvatarCore(db, "student1", {
    avatarId: "wizard",
    price: 0,
    coins: 99999,
  });
  assert.equal(result.debited, 500);
  assert.equal(result.coins, 100);
  const profile = await data("studentProfiles/student1");
  assert.equal(profile.coins, 100);
  assert.equal(profile.avatarId, "wizard");
  assert.ok(profile.unlockedAvatarIds.includes("wizard"));
});

test("PH02 avatar: replay selects without charging again", async () => {
  await db.doc("studentProfiles/student1").update({ coins: 600 });
  await economy.purchaseAvatarCore(db, "student1", { avatarId: "wizard" });
  const replay = await economy.purchaseAvatarCore(db, "student1", { avatarId: "wizard" });
  assert.equal(replay.debited, 0);
  assert.equal((await data("studentProfiles/student1")).coins, 100);
  const free = await economy.purchaseAvatarCore(db, "student1", { avatarId: "fox" });
  assert.equal(free.debited, 0);
});

test("PH02 avatar: insufficient / unknown / unauthorized fail; never negative", async () => {
  await db.doc("studentProfiles/student1").update({ coins: 100 });
  await expectCode(
    economy.purchaseAvatarCore(db, "student1", { avatarId: "star" }),
    "failed-precondition",
  );
  await expectCode(
    economy.purchaseAvatarCore(db, "student1", { avatarId: "dragon" }),
    "not-found",
  );
  await expectCode(
    economy.purchaseAvatarCore(db, "student1", { avatarId: "__proto__" }),
    "not-found",
  );
  await expectCode(
    economy.purchaseAvatarCore(db, "teacher1", { avatarId: "fox" }),
    "permission-denied",
  );
  await expectCode(
    economy.purchaseAvatarCore(db, undefined, { avatarId: "fox" }),
    "unauthenticated",
  );
  assert.equal((await data("studentProfiles/student1")).coins, 100);
});

test("PH02 avatar: concurrent purchases never overdraw", async () => {
  await db.doc("studentProfiles/student1").update({ coins: 800 });
  const results = await Promise.allSettled([
    economy.purchaseAvatarCore(db, "student1", { avatarId: "wizard" }),
    economy.purchaseAvatarCore(db, "student1", { avatarId: "camel" }),
  ]);
  const profile = await data("studentProfiles/student1");
  assert.ok(profile.coins >= 0);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
});

// ── Staff awards (points / totalStars) ─────────────────────────────────────

const grant = (overrides = {}) => ({
  awardId: "award_0001",
  halaqaId: "h1",
  halaqaIds: ["h1"],
  recipientStudentIds: ["student1", "student2"],
  type: "performance",
  title: "Award",
  ...overrides,
});

test("PH02 award: Teacher grant writes the award and credits +1 star once (points quarantined)", async () => {
  const result = await awards.grantAwardCore(db, "teacher1", grant({
    points: 999,
    totalStars: 99,
    grantedBy: "admin1",
  }));
  assert.deepEqual(result, { awardId: "award_0001", recipientCount: 2, alreadyGranted: false });
  const award = await data("achievements/award_0001");
  assert.equal(award.grantedBy, "teacher1");
  assert.equal(award.issuedBy, "teacher1");
  assert.deepEqual(award.recipientStudentIds, ["student1", "student2"]);
  assert.equal(award.recipientCount, 2);
  assert.equal(award.halaqaName, "H1");
  assert.equal("points" in award, false);
  for (const id of ["student1", "student2"]) {
    const profile = await data(`studentProfiles/${id}`);
    assert.equal(profile.points, 0);
    assert.equal(profile.totalStars, 1);
  }
});

test("PH02 award: replaying the same awardId never credits twice", async () => {
  await awards.grantAwardCore(db, "teacher1", grant());
  const replay = await awards.grantAwardCore(db, "teacher1", grant());
  assert.equal(replay.alreadyGranted, true);
  assert.equal((await data("studentProfiles/student1")).totalStars, 1);
  await expectCode(awards.grantAwardCore(db, "sup1", grant()), "already-exists");
  assert.equal((await data("studentProfiles/student1")).totalStars, 1);
});

test("PH02 award: concurrent replays of one grant credit exactly once", async () => {
  await Promise.allSettled([
    awards.grantAwardCore(db, "teacher1", grant()),
    awards.grantAwardCore(db, "teacher1", grant()),
    awards.grantAwardCore(db, "teacher1", grant()),
  ]);
  const profile = await data("studentProfiles/student1");
  assert.equal(profile.points, 0);
  assert.equal(profile.totalStars, 1);
});

test("PH02 award: separate grants accumulate (awards are repeatable)", async () => {
  await awards.grantAwardCore(db, "teacher1", grant());
  await awards.grantAwardCore(db, "teacher1", grant({ awardId: "award_0002" }));
  const profile = await data("studentProfiles/student1");
  assert.equal(profile.points, 0);
  assert.equal(profile.totalStars, 2);
});

test("PH02 award: scoped Supervisor and Admin may grant", async () => {
  await awards.grantAwardCore(db, "sup1", grant({ awardId: "award_sup1" }));
  await awards.grantAwardCore(db, "admin1", grant({ awardId: "award_adm1" }));
  assert.equal((await data("studentProfiles/student2")).totalStars, 2);
});

test("PH02 award: out-of-scope staff / other roles / off-roster students denied", async () => {
  await expectCode(awards.grantAwardCore(db, "teacher2", grant()), "permission-denied");
  await expectCode(awards.grantAwardCore(db, "sup2", grant()), "permission-denied");
  for (const uid of ["parent1", "student1"]) {
    await expectCode(awards.grantAwardCore(db, uid, grant()), "permission-denied");
  }
  await expectCode(
    awards.grantAwardCore(db, "teacher1", grant({ recipientStudentIds: ["student3"] })),
    "permission-denied",
  );
  await expectCode(
    awards.grantAwardCore(db, "teacher1", grant({ halaqaIds: ["h1", "h2"] })),
    "permission-denied",
  );
  await expectCode(awards.grantAwardCore(db, undefined, grant()), "unauthenticated");
  assert.equal((await db.doc("achievements/award_0001").get()).exists, false);
  assert.equal((await data("studentProfiles/student1")).totalStars, undefined);
});

test("PH02 award: bad input fails closed", async () => {
  const bad = [
    grant({ awardId: "x" }),
    grant({ awardId: "../evil_id" }),
    grant({ type: "coins" }),
    grant({ title: "" }),
    grant({ recipientStudentIds: [] }),
    grant({ halaqaId: "", halaqaIds: [] }),
    grant({ imageStoragePath: "awards/teacher2/a.jpg" }),
  ];
  for (const input of bad) {
    await expectCode(awards.grantAwardCore(db, "teacher1", input), "invalid-argument");
  }
  await expectCode(
    awards.grantAwardCore(db, "teacher1", grant({ halaqaId: "ghost", halaqaIds: ["ghost"] })),
    "not-found",
  );
});
