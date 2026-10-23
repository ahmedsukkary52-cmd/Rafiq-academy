/**
 * Proof-cycle identity — submitPaymentProof + reviewPaymentProof cores
 * against the Firestore + Storage emulators (transactions, stale cycles,
 * idempotency, races). Never touches a real project.
 *
 * Every test uses its own payment id, so Storage objects are never deleted;
 * only the emulator's Firestore is cleared between tests.
 *
 * Run (after `npm --prefix functions run build`) only inside an isolated
 * emulator session (auth + firestore + storage, demo- project), e.g. the
 * D:\rafiq_test_env preflight runner.
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
  throw new Error(
    "Proof-cycle suite requires firestore + storage emulators and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket();
const { Timestamp } = admin.firestore;

const review = require("../lib/billing/paymentReview.js");
const submission = require("../lib/billing/paymentProofSubmission.js");

const MB = 1024 * 1024;
const deps = { db, bucket };

async function clearFirestore() {
  const res = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed(entries) {
  const batch = db.batch();
  for (const [path, data] of Object.entries(entries)) batch.set(db.doc(path), data);
  await batch.commit();
}

async function data(path) {
  return (await db.doc(path).get()).data();
}

async function expectHttps(promise, code, message) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `expected ${code}, got ${err.code}: ${err.message}`);
    if (message) assert.equal(err.message, message);
    return true;
  });
}

const user = (role) => ({ name: role, role, isActive: true });

/** Unique per test: objects from earlier tests can never be picked up. */
function newPaymentId() {
  return `pay_${randomBytes(6).toString("hex")}`;
}

/** Client upload as storage.rules allow it (create-only, owner folder). */
async function upload(parentId, paymentId, fileName, { contentType = "image/jpeg", size = 64 } = {}) {
  const bytes = Buffer.alloc(size, 7);
  await bucket.file(`payment_proofs/${parentId}/${paymentId}/${fileName}`).save(bytes, {
    contentType,
    resumable: false,
  });
}

function submit(uid, paymentId, fileName) {
  return submission.submitPaymentProofCore(deps, uid, { paymentId, fileName });
}

function reviewWith(uid, paymentId, overrides = {}) {
  return review.reviewPaymentProofCore(db, uid, {
    paymentId,
    decision: "partial",
    requestId: "req_aaaaaaaaaaaaaaaa",
    amountMode: "receipt",
    amountValue: 60,
    ...overrides,
  });
}

/** Review bound to the payment's current proof as a reviewer would see it. */
async function reviewCurrent(uid, paymentId, overrides = {}) {
  const p = await data(`payments/${paymentId}`);
  return reviewWith(uid, paymentId, {
    expectedProofFileName: p.proofFileName,
    expectedProofCycleId: p.proofCycleId,
    ...overrides,
  });
}

async function auditsFor(paymentId) {
  const snap = await db.collection("auditLogs").where("targetId", "==", paymentId).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function requestsFor(paymentId) {
  const snap = await db.collection("paymentReviewRequests").where("paymentId", "==", paymentId).get();
  return snap.docs.map((d) => d.data());
}

function invoice(overrides = {}) {
  return { parentId: "parent1", studentId: "student1", amount: 200, status: "due", ...overrides };
}

test.beforeEach(async () => {
  await clearFirestore();
  await seed({
    "users/admin1": user("admin"),
    "users/sup1": user("supervisor"),
    "users/teacher1": user("teacher"),
    "users/parent1": user("parent"),
    "users/parent2": user("parent"),
    "halaqat/h1": { name: "H1", supervisorId: "sup1", studentIds: ["student1"] },
    "studentProfiles/student1": { uid: "student1", halaqaId: "h1" },
    "parentProfiles/parent1": { uid: "parent1", childrenIds: ["student1"] },
    "parentProfiles/parent2": { uid: "parent2", childrenIds: ["student2"] },
  });
});

// ── Submission ──────────────────────────────────────────────────────────────

test("Submit: verified object opens a new server cycle; confirmed amounts untouched", async () => {
  const id = newPaymentId();
  await seed({
    [`payments/${id}`]: invoice({
      reviewStatus: "partial",
      reviewedBy: "admin1",
      amountPaidConfirmed: 60,
      remainingAmount: 140,
    }),
  });
  await upload("parent1", id, "A.jpg");
  const result = await submit("parent1", id, "A.jpg");
  assert.equal(result.replayed, false);
  assert.match(result.proofCycleId, review.PROOF_CYCLE_ID_PATTERN);

  const p = await data(`payments/${id}`);
  assert.equal(p.proofCycleId, result.proofCycleId);
  assert.equal(p.proofFileName, "A.jpg");
  assert.equal(p.proofStoragePath, `payment_proofs/parent1/${id}/A.jpg`);
  assert.equal(p.reviewStatus, "pending_review");
  assert.equal(p.proofSubmittedBy, "parent1");
  assert.equal(p.method, "vodafone_cash");
  assert.ok(p.proofSubmittedAt instanceof Timestamp);
  assert.deepEqual(p.proofFileNameHistory, ["A.jpg"]);
  assert.equal(p.amountPaidConfirmed, 60);
  assert.equal(p.remainingAmount, 140);
  assert.equal(p.reviewedBy, "admin1");
  assert.equal(p.status, "due");
  assert.equal(p.amount, 200);
});

test("Submit: missing object, other folder, wrong owner, non-parent → nothing written", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await expectHttps(submit("parent1", id, "never.jpg"), "failed-precondition", submission.PROOF_NOT_UPLOADED_MESSAGE);

  // Object in another parent's folder is not this parent's upload.
  await upload("parent2", id, "foreign.jpg");
  await expectHttps(submit("parent1", id, "foreign.jpg"), "failed-precondition", submission.PROOF_NOT_UPLOADED_MESSAGE);
  await expectHttps(submit("parent2", id, "foreign.jpg"), "permission-denied");

  await upload("parent1", id, "staff.jpg");
  for (const uid of ["admin1", "sup1", "teacher1"]) {
    await expectHttps(submit(uid, id, "staff.jpg"), "permission-denied");
  }
  await expectHttps(submit(undefined, id, "staff.jpg"), "unauthenticated");
  for (const fileName of ["../x.jpg", "a/b.jpg", "a.gif", "a", "", "a b.jpg"]) {
    await expectHttps(submit("parent1", id, fileName), "invalid-argument");
  }
  await expectHttps(submit("parent1", "nope", "staff.jpg"), "failed-precondition");

  const p = await data(`payments/${id}`);
  assert.equal(p.proofCycleId, undefined);
  assert.equal(p.reviewStatus, undefined);
});

test("Submit: type and size are re-checked on the stored object", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "t.jpg", { contentType: "image/png" });
  await upload("parent1", id, "z.jpg", { size: 0 });
  await upload("parent1", id, "big.jpg", { size: 10 * MB });
  await upload("parent1", id, "g.png", { contentType: "image/gif" });
  for (const name of ["t.jpg", "z.jpg", "big.jpg", "g.png"]) {
    await expectHttps(submit("parent1", id, name), "failed-precondition", submission.PROOF_INVALID_OBJECT_MESSAGE);
  }
  assert.equal((await data(`payments/${id}`)).proofCycleId, undefined);
});

test("Submit: paid / approved invoices are locked", async () => {
  const paid = newPaymentId();
  const approved = newPaymentId();
  await seed({
    [`payments/${paid}`]: invoice({ status: "paid" }),
    [`payments/${approved}`]: invoice({ reviewStatus: "approved" }),
  });
  await upload("parent1", paid, "A.jpg");
  await upload("parent1", approved, "A.jpg");
  await expectHttps(submit("parent1", paid, "A.jpg"), "failed-precondition");
  await expectHttps(submit("parent1", approved, "A.jpg"), "failed-precondition");
  assert.equal((await data(`payments/${paid}`)).proofCycleId, undefined);
});

test("Submit: same-name resubmission never opens a cycle and A → B → A is refused", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  const a = await submit("parent1", id, "A.jpg");
  await reviewCurrent("admin1", id, { decision: "reject", amountMode: undefined, amountValue: undefined });

  // The same object again is the same submission: replayed, still rejected.
  const again = await submit("parent1", id, "A.jpg");
  assert.equal(again.replayed, true);
  assert.equal(again.proofCycleId, a.proofCycleId);
  assert.equal((await data(`payments/${id}`)).reviewStatus, "rejected");

  await upload("parent1", id, "B.jpg");
  const b = await submit("parent1", id, "B.jpg");
  assert.notEqual(b.proofCycleId, a.proofCycleId);
  await expectHttps(submit("parent1", id, "A.jpg"), "failed-precondition", submission.PROOF_REUSED_MESSAGE);

  const p = await data(`payments/${id}`);
  assert.equal(p.proofCycleId, b.proofCycleId);
  assert.equal(p.proofFileName, "B.jpg");
  assert.deepEqual([...p.proofFileNameHistory].sort(), ["A.jpg", "B.jpg"]);
});

test("Submit: an object created before the current cycle can never become a new cycle", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "old.jpg");
  await new Promise((r) => setTimeout(r, 1100));
  await upload("parent1", id, "cur.jpg");
  await submit("parent1", id, "cur.jpg");
  await expectHttps(submit("parent1", id, "old.jpg"), "failed-precondition", submission.PROOF_REUSED_MESSAGE);

  // Legacy record (no cycle, no history) pointing at an old object: re-pointing
  // it at any object older than its submission time is refused too.
  const legacy = newPaymentId();
  await upload("parent1", legacy, "pre.jpg");
  await seed({
    [`payments/${legacy}`]: invoice({
      reviewStatus: "rejected",
      proofFileName: "x.jpg",
      proofSubmittedAt: Timestamp.fromMillis(Date.now() + 60_000),
    }),
  });
  await expectHttps(submit("parent1", legacy, "pre.jpg"), "failed-precondition", submission.PROOF_REUSED_MESSAGE);
});

test("Submit: retry after a lost response replays the established cycle", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  const first = await submit("parent1", id, "A.jpg");
  const before = await data(`payments/${id}`);
  const retry = await submit("parent1", id, "A.jpg");
  assert.equal(retry.replayed, true);
  assert.equal(retry.proofCycleId, first.proofCycleId);
  const after = await data(`payments/${id}`);
  assert.ok(after.proofSubmittedAt.isEqual(before.proofSubmittedAt), "replay must not rewrite");
  assert.ok(after.updatedAt.isEqual(before.updatedAt));
});

/** Submits A, applies [decide], then retries A as after a lost response. */
async function retryAfterReview(decide) {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  const first = await submit("parent1", id, "A.jpg");
  await decide(id);
  const reviewed = await data(`payments/${id}`);
  const retry = await submit("parent1", id, "A.jpg");
  const after = await data(`payments/${id}`);
  return { id, first, reviewed, retry, after };
}

function assertReplayedUnchanged({ first, reviewed, retry, after }) {
  assert.equal(retry.replayed, true);
  assert.equal(retry.proofCycleId, first.proofCycleId);
  assert.equal(retry.proofFileName, "A.jpg");
  assert.deepEqual(after, reviewed, "a replay writes nothing");
}

const noAmount = { amountMode: undefined, amountValue: undefined };

test("Submit: retry after the cycle was rejected replays it, never reopens it", async () => {
  const r = await retryAfterReview((id) =>
    reviewCurrent("admin1", id, { decision: "reject", ...noAmount }));
  assertReplayedUnchanged(r);
  assert.equal(r.after.reviewStatus, "rejected");
  assert.deepEqual(r.after.proofFileNameHistory, ["A.jpg"]);
  // Nothing is reviewable again for the same receipt.
  await expectHttps(
    reviewCurrent("sup1", r.id, { requestId: "req_bbbbbbbbbbbbbbbb" }),
    "failed-precondition",
  );
  assert.equal((await auditsFor(r.id)).length, 1);
});

test("Submit: retry after a partial review replays it; the receipt is not re-reviewable", async () => {
  const r = await retryAfterReview((id) => reviewCurrent("sup1", id));
  assertReplayedUnchanged(r);
  assert.equal(r.after.reviewStatus, "partial");
  assert.equal(r.after.amountPaidConfirmed, 60);
  await expectHttps(
    reviewCurrent("admin1", r.id, { requestId: "req_bbbbbbbbbbbbbbbb" }),
    "failed-precondition",
  );
  assert.equal((await data(`payments/${r.id}`)).amountPaidConfirmed, 60);
  assert.equal((await auditsFor(r.id)).length, 1);
});

test("Submit: retry after full approval replays it instead of reporting a lock", async () => {
  const r = await retryAfterReview((id) =>
    reviewCurrent("admin1", id, { decision: "approve", ...noAmount }));
  assertReplayedUnchanged(r);
  assert.equal(r.after.reviewStatus, "approved");
  assert.equal(r.after.status, "paid");

  // A different upload is still refused by the lock.
  await upload("parent1", r.id, "B.jpg");
  await expectHttps(submit("parent1", r.id, "B.jpg"), "failed-precondition");
  assert.equal((await data(`payments/${r.id}`)).proofCycleId, r.first.proofCycleId);
});

test("Submit: a genuinely new upload after a rejection opens a new cycle", async () => {
  const r = await retryAfterReview((id) =>
    reviewCurrent("admin1", id, { decision: "reject", ...noAmount }));
  await upload("parent1", r.id, "B.jpg");
  const b = await submit("parent1", r.id, "B.jpg");
  assert.equal(b.replayed, false);
  assert.notEqual(b.proofCycleId, r.first.proofCycleId);
  const p = await data(`payments/${r.id}`);
  assert.equal(p.proofCycleId, b.proofCycleId);
  assert.equal(p.reviewStatus, "pending_review");
  assert.deepEqual([...p.proofFileNameHistory].sort(), ["A.jpg", "B.jpg"]);
});

test("Submit: same name but another object / submitter / cycle is never taken for a retry", async () => {
  const unverified = (id) =>
    expectHttps(submit("parent1", id, "A.jpg"), "failed-precondition", submission.PROOF_RETRY_UNVERIFIED_MESSAGE);

  // Another object generation under the same path (re-created out of band).
  const regenerated = await retryAfterReview((id) =>
    reviewCurrent("admin1", id, { decision: "reject", ...noAmount }));
  await upload("parent1", regenerated.id, "A.jpg");
  await unverified(regenerated.id);
  assert.deepEqual(await data(`payments/${regenerated.id}`), regenerated.after);

  // Submitted by someone else, or recorded under another path.
  for (const patch of [
    { proofSubmittedBy: "parent2" },
    { proofStoragePath: "payment_proofs/parent1/other/A.jpg" },
  ]) {
    const id = newPaymentId();
    await seed({ [`payments/${id}`]: invoice() });
    await upload("parent1", id, "A.jpg");
    await submit("parent1", id, "A.jpg");
    await db.doc(`payments/${id}`).update(patch);
    const before = await data(`payments/${id}`);
    await unverified(id);
    assert.deepEqual(await data(`payments/${id}`), before);
  }

  // Legacy record pointing at the same name without a server-issued cycle.
  const legacy = newPaymentId();
  await upload("parent1", legacy, "A.jpg");
  await seed({
    [`payments/${legacy}`]: invoice({
      reviewStatus: "rejected",
      proofFileName: "A.jpg",
      proofStoragePath: `payment_proofs/parent1/${legacy}/A.jpg`,
      proofSubmittedBy: "parent1",
    }),
  });
  await unverified(legacy);
  assert.equal((await data(`payments/${legacy}`)).proofCycleId, undefined);
});

test("Submit: upload succeeded but the callable failed → payment unchanged; later submit works", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice({ status: "paid" }) });
  await upload("parent1", id, "A.jpg");
  await expectHttps(submit("parent1", id, "A.jpg"), "failed-precondition");
  assert.equal((await data(`payments/${id}`)).proofFileName, undefined);
  // Orphan object only becomes current through a successful submission.
  await db.doc(`payments/${id}`).update({ status: "due" });
  const ok = await submit("parent1", id, "A.jpg");
  assert.equal((await data(`payments/${id}`)).proofCycleId, ok.proofCycleId);
});

// ── Review bound to the cycle ───────────────────────────────────────────────

test("Review: cycle-bound review applies once, audit + request record carry the cycle", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  const { proofCycleId } = await submit("parent1", id, "A.jpg");
  const result = await reviewCurrent("sup1", id);
  assert.equal(result.amountPaidConfirmed, 60);
  assert.equal(result.replayed, false);

  const audits = await auditsFor(id);
  assert.equal(audits.length, 1);
  assert.equal(audits[0].id, `payment_review_${id}_c_${proofCycleId}`);
  assert.equal(audits[0].metadata.proofCycleId, proofCycleId);
  const requests = await requestsFor(id);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].proofCycleId, proofCycleId);
});

test("Review: stale cycle (A → B) is refused before any write", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  const a = await submit("parent1", id, "A.jpg");
  await upload("parent1", id, "B.jpg");
  await submit("parent1", id, "B.jpg");

  await expectHttps(
    reviewWith("admin1", id, { expectedProofFileName: "A.jpg", expectedProofCycleId: a.proofCycleId }),
    "failed-precondition",
    review.PROOF_CHANGED_MESSAGE,
  );
  const p = await data(`payments/${id}`);
  assert.equal(p.reviewStatus, "pending_review");
  assert.equal(p.amountPaidConfirmed, undefined);
  assert.equal((await auditsFor(id)).length, 0);
  assert.equal((await requestsFor(id)).length, 0);
});

test("Review: the cycle, not the file name, decides (same name under a new cycle)", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  const a = await submit("parent1", id, "A.jpg");
  // Server-side state with the same file name but another cycle (A → B → A
  // as seen by a reviewer that only compared names).
  await db.doc(`payments/${id}`).update({ proofCycleId: "pc_ZZZZZZZZZZZZZZZZZZZZZZZZ" });
  await expectHttps(
    reviewWith("admin1", id, { expectedProofFileName: "A.jpg", expectedProofCycleId: a.proofCycleId }),
    "failed-precondition",
    review.PROOF_CHANGED_MESSAGE,
  );
  assert.equal((await auditsFor(id)).length, 0);
});

test("Review: retry with the same requestId after a resubmission replays, never reviews B", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  const a = await submit("parent1", id, "A.jpg");
  const first = await reviewCurrent("admin1", id);
  await upload("parent1", id, "B.jpg");
  const b = await submit("parent1", id, "B.jpg");

  const retry = await reviewWith("admin1", id, {
    expectedProofFileName: "A.jpg",
    expectedProofCycleId: a.proofCycleId,
  });
  assert.equal(retry.replayed, true);
  assert.equal(retry.amountPaidConfirmed, first.amountPaidConfirmed);
  const p = await data(`payments/${id}`);
  assert.equal(p.proofCycleId, b.proofCycleId);
  assert.equal(p.reviewStatus, "pending_review");
  assert.equal(p.amountPaidConfirmed, 60);
  assert.equal((await auditsFor(id)).length, 1);

  // Same requestId with the new cycle is a different request.
  await expectHttps(
    reviewWith("admin1", id, { expectedProofFileName: "B.jpg", expectedProofCycleId: b.proofCycleId }),
    "failed-precondition",
    review.REQUEST_ID_REUSED_MESSAGE,
  );
  assert.equal((await data(`payments/${id}`)).reviewStatus, "pending_review");
});

test("Review: legacy / cycle-less requests fail closed on a cycle record", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  await submit("parent1", id, "A.jpg");
  await expectHttps(
    review.reviewPaymentProofCore(db, "admin1", { paymentId: id, decision: "approve" }),
    "failed-precondition",
    review.PROOF_CYCLE_REQUIRED_MESSAGE,
  );
  await expectHttps(
    reviewWith("admin1", id, { expectedProofFileName: "A.jpg" }),
    "failed-precondition",
    review.PROOF_CYCLE_REQUIRED_MESSAGE,
  );
  const p = await data(`payments/${id}`);
  assert.equal(p.status, "due");
  assert.equal(p.reviewStatus, "pending_review");
  assert.equal((await auditsFor(id)).length, 0);
});

test("Review: a cycle is never inferred for a legacy record", async () => {
  const id = newPaymentId();
  await seed({
    [`payments/${id}`]: invoice({
      reviewStatus: "pending_review",
      proofFileName: "L.jpg",
      proofSubmittedAt: Timestamp.fromMillis(1_790_000_000_000),
    }),
  });
  await expectHttps(
    reviewWith("admin1", id, { expectedProofFileName: "L.jpg", expectedProofCycleId: "pc_AAAAAAAAAAAAAAAAAAAAAAAA" }),
    "failed-precondition",
    review.PROOF_CHANGED_MESSAGE,
  );
  // Existing pre-cycle behaviour stays for legacy records.
  const ok = await reviewWith("admin1", id, { expectedProofFileName: "L.jpg" });
  assert.equal(ok.amountPaidConfirmed, 60);
  assert.equal((await auditsFor(id))[0].id, `payment_review_${id}_1790000000000`);
});

test("Review: two reviewers on the same cycle → exactly one transition", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  await submit("parent1", id, "A.jpg");
  const results = await Promise.allSettled([
    reviewCurrent("admin1", id, { requestId: "req_admin_aaaaaaaaaa" }),
    reviewCurrent("sup1", id, { requestId: "req_super_aaaaaaaaaa", amountValue: 70 }),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal((await auditsFor(id)).length, 1);
  const p = await data(`payments/${id}`);
  assert.ok([60, 70].includes(p.amountPaidConfirmed));
});

test("Race: review of A concurrent with submission of B stays consistent", async () => {
  for (let round = 0; round < 5; round++) {
    const id = newPaymentId();
    await seed({ [`payments/${id}`]: invoice() });
    await upload("parent1", id, "A.jpg");
    const a = await submit("parent1", id, "A.jpg");
    await upload("parent1", id, "B.jpg");
    const [reviewed, submitted] = await Promise.allSettled([
      reviewWith("admin1", id, {
        requestId: `req_race_${round}_aaaaaaaaaa`,
        expectedProofFileName: "A.jpg",
        expectedProofCycleId: a.proofCycleId,
      }),
      submit("parent1", id, "B.jpg"),
    ]);
    assert.equal(submitted.status, "fulfilled", String(submitted.reason));
    const p = await data(`payments/${id}`);
    const audits = await auditsFor(id);
    assert.equal(p.proofCycleId, submitted.value.proofCycleId);
    assert.equal(p.reviewStatus, "pending_review", "B must stay pending");
    if (reviewed.status === "fulfilled") {
      // Review committed first, on A only; B kept its confirmed amount.
      assert.equal(p.amountPaidConfirmed, 60);
      assert.equal(audits.length, 1);
      assert.equal(audits[0].metadata.proofCycleId, a.proofCycleId);
    } else {
      assert.equal(reviewed.reason.message, review.PROOF_CHANGED_MESSAGE);
      assert.equal(p.amountPaidConfirmed, undefined);
      assert.equal(audits.length, 0);
      assert.equal((await requestsFor(id)).length, 0);
    }
  }
});

test("Partials accumulate across reject / resubmit cycles", async () => {
  const id = newPaymentId();
  await seed({ [`payments/${id}`]: invoice() });
  await upload("parent1", id, "A.jpg");
  await submit("parent1", id, "A.jpg");
  await reviewCurrent("admin1", id, { requestId: "req_cycle_a_aaaaaaaa" });

  await upload("parent1", id, "B.jpg");
  await submit("parent1", id, "B.jpg");
  assert.equal((await data(`payments/${id}`)).amountPaidConfirmed, 60);
  await reviewCurrent("admin1", id, {
    requestId: "req_cycle_b_aaaaaaaa",
    decision: "reject",
    amountMode: undefined,
    amountValue: undefined,
  });

  await upload("parent1", id, "C.png", { contentType: "image/png" });
  await submit("parent1", id, "C.png");
  const third = await reviewCurrent("sup1", id, { requestId: "req_cycle_c_aaaaaaaa", amountValue: 50 });
  assert.equal(third.previousAmountPaidConfirmed, 60);
  assert.equal(third.amountPaidConfirmed, 110);
  assert.equal(third.remainingAmount, 90);

  await upload("parent1", id, "D.webp", { contentType: "image/webp" });
  await submit("parent1", id, "D.webp");
  const done = await reviewCurrent("admin1", id, {
    requestId: "req_cycle_d_aaaaaaaa",
    decision: "approve",
    amountMode: undefined,
    amountValue: undefined,
  });
  assert.equal(done.status, "paid");
  assert.equal(done.amountPaidConfirmed, 200);
  await upload("parent1", id, "E.jpg");
  await expectHttps(submit("parent1", id, "E.jpg"), "failed-precondition");
  assert.equal((await auditsFor(id)).length, 4);
});
