/**
 * Admin finance journey against the Firestore + Storage emulators:
 * parent proof → supervisor review → verified record visible to Admin,
 * lifecycle notifications, and server-side counters (the same
 * count/sum aggregates the Admin dashboard runs). Synthetic data only.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage \
 *     "node --test --test-concurrency=1 functions/test/admin_finance.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { randomBytes } from "node:crypto";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const STORAGE = process.env.FIREBASE_STORAGE_EMULATOR_HOST;

if (!FIRESTORE || !STORAGE || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("admin finance suite requires firestore + storage emulators and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket();
const { AggregateField, Timestamp } = admin.firestore;

const review = require("../lib/billing/paymentReview.js");
const submission = require("../lib/billing/paymentProofSubmission.js");
const notify = require("../lib/notifications/paymentNotificationFunctions.js");

async function clearFirestore() {
  const res = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed(entries) {
  const batch = db.batch();
  for (const [path, value] of Object.entries(entries)) batch.set(db.doc(path), value);
  await batch.commit();
}

const data = async (path) => (await db.doc(path).get()).data();
const user = (role, name = role) => ({ name, role, isActive: true });
const newPaymentId = () => `pay_${randomBytes(6).toString("hex")}`;

async function upload(parentId, paymentId, fileName) {
  await bucket
    .file(`payment_proofs/${parentId}/${paymentId}/${fileName}`)
    .save(Buffer.alloc(64, 7), { contentType: "image/jpeg", resumable: false });
}

/** Runs the trigger body for one write, exactly as `notifyOnPaymentUpdated`. */
async function fireTrigger(paymentId, before) {
  const after = await data(`payments/${paymentId}`);
  const list = await notify.paymentTransitionNotifications(db, paymentId, before, after);
  const store = require("../lib/notifications/academyNotificationStore.js");
  if (list.length > 0) await store.writeInAppNotifications(db, list);
  return list;
}

/** Mirrors AdminPaymentsLedger.summary(): optional fields get their own query. */
async function totals(status) {
  const q = db.collection("payments").where("status", "==", status);
  const invoices = await q
    .aggregate({ count: AggregateField.count(), amount: AggregateField.sum("amount") })
    .get();
  const confirmed = await q.aggregate({ confirmed: AggregateField.sum("amountPaidConfirmed") }).get();
  return { ...invoices.data(), confirmed: confirmed.data().confirmed };
}

test("a multi-field aggregate skips documents missing a field (why the ledger splits queries)", async () => {
  await seed({
    "payments/m1": invoice({ status: "paid", amount: 500 }),
    "payments/m2": invoice({ status: "paid", amount: 100, amountPaidConfirmed: 100 }),
  });
  const combined = await db
    .collection("payments")
    .where("status", "==", "paid")
    .aggregate({ count: AggregateField.count(), confirmed: AggregateField.sum("amountPaidConfirmed") })
    .get();
  assert.equal(combined.data().count, 1);
  assert.deepEqual(await totals("paid"), { count: 2, amount: 600, confirmed: 100 });
});

const invoice = (overrides = {}) => ({
  parentId: "parent1",
  studentId: "student1",
  amount: 300,
  status: "due",
  currency: "EGP",
  dueDate: Timestamp.fromDate(new Date("2026-11-01T00:00:00Z")),
  ...overrides,
});

test.beforeEach(async () => {
  await clearFirestore();
  await seed({
    "users/admin1": user("admin", "المدير"),
    "users/sup1": user("supervisor", "المشرف خالد"),
    "users/parent1": user("parent", "محمد"),
    "users/student1": user("student", "أحمد"),
    "halaqat/h1": { name: "حلقة النور", supervisorId: "sup1", studentIds: ["student1"] },
    "studentProfiles/student1": { uid: "student1", halaqaId: "h1" },
    "parentProfiles/parent1": { uid: "parent1", childrenIds: ["student1"] },
  });
});

test("payment journey: proof → supervisor notified → approval → parent + admin notified, record verified", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });

  const beforeSubmit = await data(`payments/${id}`);
  await upload("parent1", id, "A.jpg");
  await submission.submitPaymentProofCore({ db, bucket }, "parent1", { paymentId: id, fileName: "A.jpg" });
  const submitted = await data(`payments/${id}`);
  assert.equal(submitted.reviewStatus, "pending_review");

  const sentOnSubmit = await fireTrigger(id, beforeSubmit);
  assert.deepEqual(sentOnSubmit.map((n) => n.audience), ["sup1"]);
  const supNote = await data(`notifications/sup1_payment_proof_${id}_${submitted.proofCycleId}`);
  assert.equal(supNote.type, "payment");
  assert.equal(supNote.data.paymentId, id);
  assert.match(supNote.body, /أحمد/);
  assert.match(supNote.body, /300 جنيه/);

  const pending = await db.collection("payments").where("reviewStatus", "==", "pending_review").count().get();
  assert.equal(pending.data().count, 1);

  await review.reviewPaymentProofCore(db, "sup1", {
    paymentId: id,
    decision: "approve",
    requestId: "req_finance_aaaaaaaa",
    expectedProofFileName: submitted.proofFileName,
    expectedProofCycleId: submitted.proofCycleId,
  });
  const approved = await data(`payments/${id}`);
  assert.equal(approved.status, "paid");
  assert.equal(approved.reviewStatus, "approved");
  assert.equal(approved.reviewedBy, "sup1");

  const sentOnReview = await fireTrigger(id, submitted);
  assert.deepEqual(sentOnReview.map((n) => n.audience).sort(), ["admin", "parent1"]);
  const parentNote = await data(`notifications/parent1_payment_review_${id}_${submitted.proofCycleId}`);
  assert.equal(parentNote.title, "تم اعتماد الدفعة");
  const adminNote = await data(`notifications/admin_payment_paid_${id}`);
  assert.equal(adminNote.audience, "admin");

  const audits = await db.collection("auditLogs").where("targetId", "==", id).get();
  assert.equal(audits.size, 1);
  assert.equal(audits.docs[0].get("actorId"), "sup1");
  assert.equal(audits.docs[0].get("metadata").decision, "approve");

  // Retried trigger delivery is idempotent (deterministic ids).
  await fireTrigger(id, submitted);
  const parentNotes = await db.collection("notifications").where("audience", "==", "parent1").get();
  assert.equal(parentNotes.size, 1);
});

test("financial counters follow the lifecycle without reading documents", async () => {
  const a = newPaymentId();
  const b = newPaymentId();
  const c = newPaymentId();
  await seed({
    [`payments/${a}`]: invoice({ amount: 300 }),
    [`payments/${b}`]: invoice({ amount: 200, status: "overdue" }),
    [`payments/${c}`]: invoice({ amount: 500, status: "paid" }),
  });
  assert.deepEqual(await totals("paid"), { count: 1, amount: 500, confirmed: 0 });
  assert.deepEqual(await totals("due"), { count: 1, amount: 300, confirmed: 0 });

  await upload("parent1", a, "P.jpg");
  await submission.submitPaymentProofCore({ db, bucket }, "parent1", { paymentId: a, fileName: "P.jpg" });
  const submitted = await data(`payments/${a}`);
  await review.reviewPaymentProofCore(db, "sup1", {
    paymentId: a,
    decision: "partial",
    requestId: "req_finance_partial_a",
    amountMode: "receipt",
    amountValue: 100,
    expectedProofFileName: submitted.proofFileName,
    expectedProofCycleId: submitted.proofCycleId,
  });
  const partialNotes = await fireTrigger(a, submitted);
  assert.equal(partialNotes.find((n) => n.audience === "parent1").title, "تم اعتماد دفعة جزئية");

  // Partial: still due, 100 confirmed → revenue 600, outstanding 200 on due.
  assert.deepEqual(await totals("due"), { count: 1, amount: 300, confirmed: 100 });
  assert.deepEqual(await totals("paid"), { count: 1, amount: 500, confirmed: 0 });
  assert.deepEqual(await totals("overdue"), { count: 1, amount: 200, confirmed: 0 });
});

test("overdue transition notifies the parent once; no-op writes notify nobody", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  const before = await data(`payments/${id}`);
  await db.doc(`payments/${id}`).update({ status: "overdue" });
  const sent = await fireTrigger(id, before);
  assert.deepEqual(sent.map((n) => n.notificationId), [`parent1_payment_overdue_${id}`]);

  const same = await data(`payments/${id}`);
  await db.doc(`payments/${id}`).update({ updatedAt: Timestamp.now() });
  assert.deepEqual(await fireTrigger(id, same), []);
});

test("rejected proof tells the parent to re-upload and never notifies admin", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "R.jpg");
  await submission.submitPaymentProofCore({ db, bucket }, "parent1", { paymentId: id, fileName: "R.jpg" });
  const submitted = await data(`payments/${id}`);
  await review.reviewPaymentProofCore(db, "sup1", {
    paymentId: id,
    decision: "reject",
    requestId: "req_finance_reject_aa",
    expectedProofFileName: submitted.proofFileName,
    expectedProofCycleId: submitted.proofCycleId,
  });
  const sent = await fireTrigger(id, submitted);
  assert.deepEqual(sent.map((n) => n.audience), ["parent1"]);
  assert.equal(sent[0].title, "تم رفض إيصال الدفع");
});
