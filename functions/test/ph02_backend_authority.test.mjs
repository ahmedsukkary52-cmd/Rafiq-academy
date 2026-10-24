/**
 * PRODUCTION-HARDENING-02 — pure backend-authority contracts (no emulator).
 *
 * Transactional behaviour is covered by ph02_backend_authority.emulator.test.mjs.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..", "..");

const review = require("../lib/billing/paymentReview.js");
const economy = require("../lib/economy/economyFunctions.js");
const records = require("../lib/sessions/sessionRecords.js");
const membership = require("../lib/halaqa/membershipFunctions.js");
const notifications = require("../lib/notifications/academyNotifications.js");
const audit = require("../lib/audit/auditLogContract.js");
const auditWrite = require("../lib/audit/auditLogWrite.js");
const awards = require("../lib/awards/awardFunctions.js");

// ── C4 / C16 payment review ────────────────────────────────────────────────

test("PH02 payment review: only pending_review is reviewable", () => {
  for (const reviewStatus of [undefined, "approved", "rejected", "partial"]) {
    const outcome = review.decidePaymentReview({
      payment: { amount: 100, status: "due", reviewStatus },
      decision: "approve",
    });
    assert.equal(outcome.ok, false);
    assert.equal(outcome.code, "failed-precondition");
  }
  const paid = review.decidePaymentReview({
    payment: { amount: 100, status: "paid", reviewStatus: "pending_review" },
    decision: "approve",
  });
  assert.equal(paid.ok, false);
});

test("PH02 payment review: approve derives paid + amounts from the invoice", () => {
  const outcome = review.decidePaymentReview({
    payment: { amount: 250, status: "overdue", reviewStatus: "pending_review" },
    decision: "approve",
    amountPaidConfirmed: 1,
  });
  assert.equal(outcome.ok, true);
  assert.equal(outcome.previousStatus, "overdue");
  assert.deepEqual(outcome.patch, {
    reviewStatus: "approved",
    status: "paid",
    amountPaidConfirmed: 250,
    remainingAmount: 0,
  });
});

test("PH02 payment review: reject keeps status; partial bounds the amount", () => {
  const pending = { amount: 100, status: "due", reviewStatus: "pending_review" };
  const reject = review.decidePaymentReview({ payment: pending, decision: "reject" });
  assert.deepEqual(reject.patch, { reviewStatus: "rejected" });

  const partial = review.decidePaymentReview({
    payment: pending,
    decision: "partial",
    amountPaidConfirmed: 40,
  });
  assert.deepEqual(partial.patch, {
    reviewStatus: "partial",
    amountPaidConfirmed: 40,
    remainingAmount: 60,
  });
  for (const bad of [0, -5, 100, 150, "40", Number.NaN, undefined]) {
    const outcome = review.decidePaymentReview({
      payment: pending,
      decision: "partial",
      amountPaidConfirmed: bad,
    });
    assert.equal(outcome.ok, false, `partial ${String(bad)} must fail`);
  }
});

test("PH02 payment review: invalid invoice amount fails closed", () => {
  for (const amount of [0, -1, "100", undefined]) {
    const outcome = review.decidePaymentReview({
      payment: { amount, status: "due", reviewStatus: "pending_review" },
      decision: "approve",
    });
    assert.equal(outcome.ok, false);
  }
});

test("PH02 payment review: decisions are an allowlist", () => {
  assert.equal(review.parseDecision("approve"), "approve");
  for (const bad of ["paid", "APPROVE", "", null, 1]) {
    assert.throws(() => review.parseDecision(bad));
  }
});

test("PH02 payment review: one audit id per review cycle", () => {
  assert.equal(review.paymentReviewAuditId("p1", undefined), "payment_review_p1_initial");
  assert.equal(
    review.paymentReviewAuditId("p1", undefined),
    review.paymentReviewAuditId("p1", null),
  );
});

test("Proof cycle: audit id is keyed by the server-issued cycle when present", () => {
  const cycle = "pc_AAAAAAAAAAAAAAAAAAAAAAAA";
  assert.equal(review.paymentReviewAuditId("p1", undefined, cycle), `payment_review_p1_c_${cycle}`);
  assert.equal(review.paymentReviewAuditId("p1", undefined, ""), "payment_review_p1_initial");
  assert.notEqual(
    review.paymentReviewAuditId("p1", undefined, cycle),
    review.paymentReviewAuditId("p1", undefined, "pc_BBBBBBBBBBBBBBBBBBBBBBBB"),
  );
});

test("Proof cycle: server cycle ids are random, prefixed and never repeat", () => {
  const submission = require("../lib/billing/paymentProofSubmission.js");
  const ids = new Set();
  for (let i = 0; i < 500; i++) {
    const id = submission.newProofCycleId();
    assert.match(id, review.PROOF_CYCLE_ID_PATTERN);
    ids.add(id);
  }
  assert.equal(ids.size, 500);
  assert.equal(
    submission.paymentProofObjectPath("par1", "pay1", "1.jpg"),
    "payment_proofs/par1/pay1/1.jpg",
  );
});

// ── Repeated partial payments (receipt / cumulative, minor units) ─────────

function pendingWith(previous, amount = 100) {
  return {
    amount,
    status: "due",
    reviewStatus: "pending_review",
    ...(previous === undefined ? {} : { amountPaidConfirmed: previous }),
  };
}

function partial(payment, mode, value) {
  return review.decidePaymentReview({
    payment,
    decision: "partial",
    amountInput: { mode, value },
  });
}

test("PH02 partial receipt: first then second receipt add to the confirmed total", () => {
  const first = partial(pendingWith(undefined), "receipt", 60);
  assert.equal(first.ok, true);
  assert.deepEqual(first.patch, {
    reviewStatus: "partial",
    amountPaidConfirmed: 60,
    remainingAmount: 40,
  });
  assert.deepEqual(first.amounts, {
    mode: "receipt", invoice: 10000, previous: 0, total: 6000, remaining: 4000, receipt: 6000,
  });

  const second = partial(pendingWith(60), "receipt", 20);
  assert.deepEqual(second.patch, {
    reviewStatus: "partial",
    amountPaidConfirmed: 80,
    remainingAmount: 20,
  });
  assert.equal(second.amounts.previous, 6000);
  assert.equal(second.amounts.receipt, 2000);
});

test("PH02 partial cumulative: totals are entered, receipt is the difference", () => {
  const first = partial(pendingWith(undefined), "cumulative", 60);
  assert.deepEqual(first.patch.amountPaidConfirmed, 60);
  assert.equal(first.amounts.receipt, 6000);

  const second = partial(pendingWith(60), "cumulative", 80);
  assert.deepEqual(second.patch, {
    reviewStatus: "partial",
    amountPaidConfirmed: 80,
    remainingAmount: 20,
  });
  assert.equal(second.amounts.mode, "cumulative");
  assert.equal(second.amounts.receipt, 2000);
});

test("PH02 partial: switching modes between consecutive reviews", () => {
  const toCumulative = partial(pendingWith(60), "cumulative", 90);
  assert.equal(toCumulative.patch.amountPaidConfirmed, 90);
  assert.equal(toCumulative.amounts.receipt, 3000);
  const toReceipt = partial(pendingWith(90), "receipt", 5);
  assert.equal(toReceipt.patch.amountPaidConfirmed, 95);
  assert.equal(toReceipt.patch.remainingAmount, 5);
});

test("PH02 approve after partials: invoice total, client amount ignored", () => {
  const outcome = review.decidePaymentReview({
    payment: pendingWith(80),
    decision: "approve",
    amountPaidConfirmed: 1,
  });
  assert.deepEqual(outcome.patch, {
    reviewStatus: "approved",
    status: "paid",
    amountPaidConfirmed: 100,
    remainingAmount: 0,
  });
  assert.deepEqual(outcome.amounts, {
    mode: "approve_remaining", invoice: 10000, previous: 8000, total: 10000, remaining: 0, receipt: 2000,
  });
});

test("PH02 reject never moves the confirmed totals", () => {
  const outcome = review.decidePaymentReview({
    payment: pendingWith(60),
    decision: "reject",
    amountPaidConfirmed: 99,
  });
  assert.deepEqual(outcome.patch, { reviewStatus: "rejected" });
  assert.deepEqual(outcome.amounts, {
    mode: "reject_unchanged", invoice: 10000, previous: 6000, total: 6000, remaining: 4000, receipt: null,
  });
});

test("PH02 partial: exceeding or reaching the invoice is refused", () => {
  for (const [mode, value] of [["receipt", 41], ["cumulative", 101], ["receipt", 1000]]) {
    const outcome = partial(pendingWith(60), mode, value);
    assert.equal(outcome.ok, false, `${mode} ${value}`);
    assert.equal(outcome.code, "invalid-argument");
    assert.match(outcome.message, /يتجاوز المتبقي/);
  }
  for (const [mode, value] of [["receipt", 40], ["cumulative", 100]]) {
    const outcome = partial(pendingWith(60), mode, value);
    assert.equal(outcome.ok, false, `${mode} ${value}`);
    assert.match(outcome.message, /استخدم الاعتماد/);
  }
});

test("PH02 partial: zero, negative, non-number and >2 decimals are refused", () => {
  for (const mode of ["receipt", "cumulative", "legacy_cumulative"]) {
    for (const bad of [0, -5, Number.NaN, Infinity, "20", null, undefined, 10.005]) {
      const outcome = partial(pendingWith(undefined), mode, bad);
      assert.equal(outcome.ok, false, `${mode} ${String(bad)} must fail`);
      assert.equal(outcome.code, "invalid-argument");
    }
  }
});

test("PH02 partial: a cumulative / legacy total cannot shrink or repeat", () => {
  for (const mode of ["cumulative", "legacy_cumulative"]) {
    for (const value of [60, 50, 0.01]) {
      const outcome = partial(pendingWith(60), mode, value);
      assert.equal(outcome.ok, false, `${mode} ${value}`);
      assert.match(outcome.message, /أكبر من الإجمالي المؤكد سابقاً/);
    }
  }
  const legacy = review.decidePaymentReview({
    payment: pendingWith(60),
    decision: "partial",
    amountPaidConfirmed: 70,
  });
  assert.equal(legacy.amounts.mode, "legacy_cumulative");
  assert.equal(legacy.patch.amountPaidConfirmed, 70);
  assert.equal(legacy.amounts.receipt, 1000);
});

test("PH02 partial: minor-unit math has no floating drift", () => {
  const a = partial(pendingWith(undefined), "receipt", 33.33);
  const b = partial(pendingWith(a.patch.amountPaidConfirmed), "receipt", 33.33);
  assert.equal(b.patch.amountPaidConfirmed, 66.66);
  assert.equal(b.patch.remainingAmount, 33.34);
  const close = review.decidePaymentReview({
    payment: pendingWith(b.patch.amountPaidConfirmed),
    decision: "approve",
  });
  assert.equal(close.amounts.receipt, 3334);
  const tiny = partial(pendingWith(0.1, 1), "receipt", 0.2);
  assert.equal(tiny.patch.amountPaidConfirmed, 0.3);
  assert.equal(tiny.patch.remainingAmount, 0.7);
});

test("PH02 partial: a corrupt stored total fails closed", () => {
  for (const previous of [100, 150, -1, "60", 10.001]) {
    const outcome = partial(pendingWith(previous), "receipt", 1);
    assert.equal(outcome.ok, false, `previous ${String(previous)}`);
    assert.equal(outcome.code, "failed-precondition");
  }
});

function expectInvalid(fn, pattern) {
  assert.throws(fn, (err) => {
    assert.equal(err.code, "invalid-argument");
    if (pattern) assert.match(err.message, pattern);
    return true;
  });
}

const current = (overrides = {}) => ({
  paymentId: "p1",
  decision: "partial",
  requestId: "req_0123456789abcdef",
  expectedProofFileName: "1760000000000.jpg",
  amountMode: "receipt",
  amountValue: 20,
  ...overrides,
});

test("PH02 request: legacy shape keeps working without idempotency", () => {
  const parsed = review.parseReviewRequest({
    paymentId: "p1",
    decision: "partial",
    amountPaidConfirmed: 40,
  });
  assert.equal(parsed.idempotency, undefined);
  assert.equal(parsed.legacyAmountPaidConfirmed, 40);
  const approve = review.parseReviewRequest({
    paymentId: "p1",
    decision: "approve",
    amountPaidConfirmed: 40,
  });
  assert.equal(approve.legacyAmountPaidConfirmed, undefined);
});

test("PH02 request: current contract requires requestId + expectedProofFileName", () => {
  const parsed = review.parseReviewRequest(current());
  assert.equal(parsed.idempotency.requestId, "req_0123456789abcdef");
  assert.equal(parsed.idempotency.expectedProofFileName, "1760000000000.jpg");
  assert.deepEqual(parsed.amountInput, { mode: "receipt", value: 20 });
  assert.match(parsed.idempotency.fingerprint, /^[0-9a-f]{64}$/);

  for (const requestId of [undefined, "", "short", "has space 0123456789", "x".repeat(65), 42]) {
    expectInvalid(() => review.parseReviewRequest(current({ requestId })));
  }
  for (const expectedProofFileName of [undefined, "", "a/b.jpg", "../x.jpg", 7]) {
    expectInvalid(() => review.parseReviewRequest(current({ expectedProofFileName })));
  }
  // Any single current-contract key opts into the full contract.
  expectInvalid(() =>
    review.parseReviewRequest({ paymentId: "p1", decision: "approve", requestId: "req_0123456789abcdef" }),
  );
});

test("PH02 request: amounts are partial-only and never mixed with the legacy field", () => {
  expectInvalid(() => review.parseReviewRequest(current({ amountPaidConfirmed: 20 })));
  for (const amountMode of [undefined, "total", "RECEIPT"]) {
    expectInvalid(() => review.parseReviewRequest(current({ amountMode })));
  }
  for (const amountValue of [undefined, 0, -1, "20", 1.234]) {
    expectInvalid(() => review.parseReviewRequest(current({ amountValue })));
  }
  for (const decision of ["approve", "reject"]) {
    expectInvalid(() => review.parseReviewRequest(current({ decision })), /الاعتماد أو الرفض/);
    const ok = review.parseReviewRequest(
      current({ decision, amountMode: undefined, amountValue: undefined }),
    );
    assert.equal(ok.amountInput, undefined);
  }
});

test("PH02 request: fingerprint is stable and covers every intent field", () => {
  const base = review.parseReviewRequest(current()).idempotency.fingerprint;
  assert.equal(review.parseReviewRequest(current({ notes: "  " })).idempotency.fingerprint, base);
  assert.equal(review.parseReviewRequest(current({ amountValue: 20.0 })).idempotency.fingerprint, base);
  for (const change of [
    { paymentId: "p2" },
    { amountMode: "cumulative" },
    { amountValue: 21 },
    { notes: "x" },
    { expectedProofFileName: "1760000000001.jpg" },
  ]) {
    assert.notEqual(
      review.parseReviewRequest(current(change)).idempotency.fingerprint,
      base,
      JSON.stringify(change),
    );
  }
  // requestId is the lookup key, not part of the intent.
  assert.equal(
    review.parseReviewRequest(current({ requestId: "req_fedcba9876543210" })).idempotency.fingerprint,
    base,
  );
});

test("Proof cycle: expectedProofCycleId is validated and fingerprinted", () => {
  const cycleA = "pc_AAAAAAAAAAAAAAAAAAAAAAAA";
  const cycleB = "pc_BBBBBBBBBBBBBBBBBBBBBBBB";
  const parsed = review.parseReviewRequest(current({ expectedProofCycleId: cycleA }));
  assert.equal(parsed.idempotency.expectedProofCycleId, cycleA);
  assert.equal(review.parseReviewRequest(current()).idempotency.expectedProofCycleId, "");
  assert.equal(
    review.parseReviewRequest(current({ expectedProofCycleId: null })).idempotency.expectedProofCycleId,
    "",
  );
  for (const expectedProofCycleId of ["", "pc_short", "AAAAAAAAAAAAAAAAAAAAAAAA", "pc_has space aaaaaaaaaaa", 7, {}]) {
    expectInvalid(() => review.parseReviewRequest(current({ expectedProofCycleId })));
  }
  // The cycle alone opts into the full (idempotent, proof-bound) contract.
  expectInvalid(() =>
    review.parseReviewRequest({ paymentId: "p1", decision: "approve", expectedProofCycleId: cycleA }),
  );

  const base = review.parseReviewRequest(current()).idempotency.fingerprint;
  const withA = parsed.idempotency.fingerprint;
  const withB = review.parseReviewRequest(current({ expectedProofCycleId: cycleB })).idempotency.fingerprint;
  assert.notEqual(withA, base);
  assert.notEqual(withA, withB);
  // Pre-cycle fingerprints are unchanged (stored records keep replaying).
  assert.equal(
    base,
    review.paymentReviewFingerprint({
      paymentId: "p1",
      decision: "partial",
      amountMode: "receipt",
      amountValueMinor: 2000,
      notes: "",
      expectedProofFileName: "1760000000000.jpg",
    }),
  );
});

test("PH02 audit: payment review amount keys are allowlisted", () => {
  for (const key of [
    "amount",
    "amountMode",
    "receiptAmount",
    "previousAmountPaidConfirmed",
    "amountPaidConfirmed",
    "remainingAmount",
    "requestId",
  ]) {
    assert.ok(audit.AUDIT_METADATA_ALLOWLIST.has(key), `${key} must be auditable`);
  }
  for (const key of ["proofStoragePath", "proofDownloadUrl", "proofFileName", "fingerprint"]) {
    assert.ok(!audit.AUDIT_METADATA_ALLOWLIST.has(key), `${key} must not be auditable`);
  }
});

test("PH02 audit: payment/admission/transfer/correction actions are active", () => {
  assert.equal(audit.AUDIT_ACTION.paymentReview, "payment_review");
  assert.equal(audit.AUDIT_ACTION.studentAdmit, "student_admit");
  assert.equal(audit.AUDIT_ACTION.studentTransfer, "student_transfer");
  assert.equal(audit.AUDIT_ACTION.attendanceCorrect, "attendance_correct");
  for (const key of ["phone", "email", "password", "token"]) {
    assert.ok(!audit.AUDIT_METADATA_ALLOWLIST.has(key), `${key} must not be auditable`);
  }
});

test("PH02 C16: evaluation_create_or_correct is active, no longer deferred", () => {
  assert.equal(audit.AUDIT_ACTION.evaluationCreateOrCorrect, "evaluation_create_or_correct");
  assert.ok(!Object.values(audit.AUDIT_ACTION_DEFERRED).includes("evaluation_create_or_correct"));
  assert.equal(audit.AUDIT_TARGET_TYPE.evaluation, "evaluation");
  for (const key of ["evaluationType", "versesRange", "operation"]) {
    assert.ok(audit.AUDIT_METADATA_ALLOWLIST.has(key), `${key} must be auditable`);
  }
});

test("PH02 C16: actor roles are admin/system/supervisor/teacher only", () => {
  const input = (actorRole) => ({
    actor: { actorId: "u1", actorRole },
    action: "evaluation_create_or_correct",
    targetType: "evaluation",
    targetId: "e1",
    metadata: {},
    source: "test",
  });
  for (const role of ["admin", "system", "supervisor", "teacher"]) {
    assert.equal(auditWrite.buildAuditLogEntry(input(role), "ts").actorRole, role);
  }
  for (const role of ["parent", "student", "Teacher", "", "owner"]) {
    assert.throws(() => auditWrite.buildAuditLogEntry(input(role), "ts"), `${role} must be rejected`);
  }
});

test("PH02 B1: Teacher edit window is 24h from the server creation anchor", () => {
  assert.equal(records.EVALUATION_TEACHER_EDIT_WINDOW_MS, 24 * 60 * 60 * 1000);
  const createdAt = new Date("2026-09-28T13:00:00Z");
  const at = (ms) => new Date(createdAt.getTime() + ms);
  const H = 60 * 60 * 1000;
  assert.equal(records.isWithinTeacherEditWindow(createdAt, at(0)), true);
  assert.equal(records.isWithinTeacherEditWindow(createdAt, at(24 * H - 1)), true);
  assert.equal(records.isWithinTeacherEditWindow(createdAt, at(24 * H)), false);
  assert.equal(records.isWithinTeacherEditWindow(createdAt, at(24 * H + 1)), false);
  // Missing / invalid anchor fails closed.
  assert.equal(records.isWithinTeacherEditWindow(null, at(0)), false);
  assert.equal(records.isWithinTeacherEditWindow(new Date("nope"), at(0)), false);
});

test("PH02 B1: the evaluation callable never takes the clock from the request", () => {
  const src = readFileSync(
    join(repoRoot, "functions/src/sessions/sessionRecordFunctions.ts"),
    "utf8",
  );
  const wrapper = /export const upsertSessionEvaluation = onCall\([\s\S]*?\n\);/.exec(src)[0];
  assert.match(
    wrapper,
    /upsertSessionEvaluationCore\(\s*admin\.firestore\(\),\s*request\.auth\?\.uid,\s*\(request\.data \?\? \{\}\) as Record<string, unknown>,\s*\)/,
  );
  assert.ok(!/data\.(createdAt|now|updatedAt)/.test(src), "no client timestamp is read");
});

test("PH02 C16: caller actor is derived from the server-loaded role", () => {
  assert.deepEqual(auditWrite.actorForCallerRole("t1", "teacher"), {
    actorId: "t1",
    actorRole: "teacher",
  });
  assert.equal(auditWrite.actorForCallerRole("s1", "supervisor").actorRole, "supervisor");
  assert.equal(auditWrite.actorForCallerRole("a1", "admin").actorRole, "admin");
  for (const role of ["parent", "student", "system", "", undefined]) {
    assert.throws(() => auditWrite.actorForCallerRole("x1", role));
  }
  assert.throws(() => auditWrite.teacherActor(""));
});

// ── Economy ────────────────────────────────────────────────────────────────

test("PH02 economy: server avatar catalog matches the Dart catalog", () => {
  const dart = readFileSync(
    join(repoRoot, "lib/features/student/domain/entities/avatar_catalog.dart"),
    "utf8",
  );
  const entries = [...dart.matchAll(/AvatarDefinition\(([\s\S]*?)\),/g)].map((m) => {
    const body = m[1];
    const id = /id:\s*'([^']+)'/.exec(body)[1];
    const cost = /unlockCost:\s*(\d+)/.exec(body);
    return [id, cost ? Number(cost[1]) : 0];
  });
  assert.ok(entries.length > 0);
  assert.deepEqual(Object.fromEntries(entries), { ...economy.AVATAR_CATALOG });
});

test("PH02 awards: server type keys match the Dart AwardType keys", () => {
  const dart = readFileSync(
    join(repoRoot, "lib/features/awards/domain/entities/award_entities.dart"),
    "utf8",
  );
  const block = /get firestoreKey => switch \(this\) \{([\s\S]*?)\};/.exec(dart)[1];
  const keys = [...block.matchAll(/=>\s*'([^']+)'/g)].map((m) => m[1]);
  assert.deepEqual([...keys].sort(), [...awards.AWARD_TYPE_KEYS].sort());
});

test("PH02 awards: fixed per-recipient credit keeps the pre-PH02 product values", () => {
  const dart = readFileSync(
    join(repoRoot, "lib/features/awards/data/datasources/award_remote_datasource_impl.dart"),
    "utf8",
  );
  assert.ok(!dart.includes("FieldValue.increment"), "client must not credit counters");
  assert.equal(awards.AWARD_POINTS_PER_RECIPIENT, 10);
  assert.equal(awards.AWARD_STARS_PER_RECIPIENT, 1);
  assert.ok(awards.MAX_AWARD_RECIPIENTS + 1 <= 500, "fits one transaction");
});

test("PH02 awards: grant scope per role (spec §2 awards row)", () => {
  const halaqa = { teacherId: "t1", supervisorId: "s1" };
  assert.equal(awards.canGrantInHalaqa("admin", "a1", halaqa), true);
  assert.equal(awards.canGrantInHalaqa("teacher", "t1", halaqa), true);
  assert.equal(awards.canGrantInHalaqa("teacher", "t2", halaqa), false);
  assert.equal(awards.canGrantInHalaqa("supervisor", "s1", halaqa), true);
  assert.equal(awards.canGrantInHalaqa("supervisor", "s2", halaqa), false);
  assert.equal(awards.canGrantInHalaqa("parent", "t1", halaqa), false);
  assert.equal(awards.canGrantInHalaqa("student", "t1", halaqa), false);
});

test("PH02 awards: image path is bound to the grantor folder", () => {
  assert.equal(awards.awardImagePathOk("awards/t1/1.jpg", "t1"), true);
  assert.equal(awards.awardImagePathOk("awards/t2/1.jpg", "t1"), false);
  assert.equal(awards.awardImagePathOk("awards/t1/../t2/1.jpg", "t1"), false);
  assert.equal(awards.awardImagePathOk("payment_proofs/t1/1.jpg", "t1"), false);
});

test("PH02 economy: homework reward is derived from canonical kinds, capped", () => {
  const task = (kind, isCompleted = true) => ({ kind, isCompleted, recitationRecordId: "" });
  assert.equal(
    economy.homeworkReward([task("reading"), task("listening"), task("recitation")]),
    65,
  );
  // Client-editable `points` never matters; duplicate kinds credit once.
  assert.equal(economy.homeworkReward([task("reading"), task("reading")]), 20);
  assert.equal(economy.homeworkReward([task("reading", false)]), 0);
  assert.equal(economy.homeworkReward([task("bonus"), task("quiz")]), 0);
  assert.ok(economy.MAX_HOMEWORK_CREDIT <= 100);
});

// ── Sessions ───────────────────────────────────────────────────────────────

test("PH02 sessions: legacy synthetic ids are recognised, real ids are not", () => {
  assert.equal(records.isLegacySyntheticSessionId("h1_20260928"), true);
  assert.equal(records.isLegacySyntheticSessionId("sess_abc123"), false);
  assert.equal(records.attendanceDocId("sess_x", "s1"), "sess_x_s1");
  assert.equal(records.evaluationDocId("sess_x", "s1", "review"), "sess_x_s1_review");
});

test("PH02 sessions: slots without slotId fail closed", () => {
  assert.throws(
    () =>
      records.operationalSlotsForDate(
        [{ day: "monday", startTime: "16:00", endTime: "17:00" }],
        "2026-09-28",
      ),
    /slotId is required/,
  );
});

test("PH02 sessions: operational day spans earliest start to latest end", () => {
  const slots = records.operationalSlotsForDate(
    [
      { slotId: "late", day: "monday", startTime: "18:00", endTime: "19:00" },
      { slotId: "early", day: "monday", startTime: "16:00", endTime: "17:00" },
      { slotId: "other", day: "tuesday", startTime: "16:00", endTime: "17:00" },
    ],
    "2026-09-28",
  );
  const day = records.operationalDay(slots);
  assert.equal(day.primarySlotId, "early");
  assert.equal(slots.length, 2);
  assert.ok(day.endAt > slots.find((s) => s.slotId === "early").endAt);
  assert.equal(
    records.isWithinAttendanceWindow({
      now: new Date(day.endAt.getTime() - 60_000),
      dateYmd: "2026-09-28",
      dayEndAt: day.endAt,
    }),
    true,
  );
  assert.equal(
    records.isWithinAttendanceWindow({
      now: new Date(day.endAt.getTime() + 60_000),
      dateYmd: "2026-09-28",
      dayEndAt: day.endAt,
    }),
    false,
  );
});

test("PH02 sessions: grades are a wire-enum allowlist", () => {
  assert.deepEqual(Object.keys(records.GRADE_LABELS).sort(), [
    "excellent",
    "good",
    "needsRetry",
    "veryGood",
  ]);
});

// ── Membership ─────────────────────────────────────────────────────────────

test("PH02 membership: cap is two halaqat; primary pointer rules", () => {
  assert.equal(membership.MAX_HALAQAT_PER_STUDENT, 2);
  assert.equal(
    membership.shouldSetPrimaryOnEstablish({ currentPrimary: "", otherMembershipIds: [] }),
    true,
  );
  assert.equal(
    membership.shouldSetPrimaryOnEstablish({ currentPrimary: "", otherMembershipIds: ["h1"] }),
    false,
  );
  assert.equal(
    membership.primaryAfterTransfer({
      currentPrimary: "h1",
      source: "h1",
      target: "h3",
      remaining: ["h2", "h3"],
    }),
    "h3",
  );
  assert.equal(
    membership.primaryAfterTransfer({
      currentPrimary: "h2",
      source: "h1",
      target: "h3",
      remaining: ["h2", "h3"],
    }),
    "h2",
  );
});

// ── C11 notifications ──────────────────────────────────────────────────────

test("PH02 notifications: payloads carry ids only (no names / free text)", () => {
  const absence = notifications.buildAbsenceNotification({
    parentId: "parent1",
    transition: {
      kind: "absent",
      studentId: "student1",
      attendanceDocumentId: "sess_x_student1",
    },
    studentName: "Student Name",
    halaqaId: "h1",
    sessionId: "sess_x",
    dateYmd: "2026-09-28",
  });
  const values = Object.values(absence.data).join("|");
  assert.ok(!values.includes("Student Name"));
  assert.equal(absence.audience, "parent1");
  assert.equal(absence.data.sessionId, "sess_x");

  const reviewed = notifications.buildHomeworkReviewedNotification({
    observerId: "parent1",
    recordId: "rec1",
    studentId: "student1",
    halaqaId: "h1",
    studentName: "Student Name",
    grade: "excellent-label",
  });
  assert.ok(!Object.values(reviewed.data).join("|").includes("excellent-label"));
});

test("PH02 notifications: homework-reviewed fires only pending → reviewed", () => {
  const before = { assignmentId: "hw1", reviewStatus: "pending", studentId: "s1", halaqaId: "h1" };
  const after = { ...before, reviewStatus: "reviewed", grade: "g" };
  assert.equal(notifications.decideHomeworkReviewed({ before, after }).notify, true);
  assert.equal(notifications.decideHomeworkReviewed({ before: after, after }).notify, false);
  assert.equal(
    notifications.decideHomeworkReviewed({
      before: { ...before, assignmentId: "" },
      after: { ...after, assignmentId: "" },
    }).notify,
    false,
  );
});

test("PH02 index exports every new callable / trigger", () => {
  const index = readFileSync(join(__dirname, "..", "src", "index.ts"), "utf8");
  for (const name of [
    "reviewPaymentProof",
    "submitPaymentProof",
    "recordSessionAttendance",
    "upsertSessionEvaluation",
    "notifyOnAssignmentCreated",
    "admitStudentToHalaqa",
    "adminTransferStudent",
    "completeHomework",
    "purchaseAvatar",
    "grantAward",
    "issueAchievement",
  ]) {
    assert.ok(index.includes(name), `${name} must be exported`);
  }
});

test("PH02 composite indexes for callable day-range queries exist", () => {
  const { indexes } = JSON.parse(
    readFileSync(join(repoRoot, "firestore.indexes.json"), "utf8"),
  );
  const shape = (i) =>
    `${i.collectionGroup}:${i.fields.map((f) => `${f.fieldPath}/${f.order}`).join(",")}`;
  const present = new Set(indexes.map(shape));
  for (const required of [
    "attendanceRecords:halaqaId/ASCENDING,date/ASCENDING",
    "attendanceRecords:halaqaId/ASCENDING,studentId/ASCENDING,date/ASCENDING",
    "recitationRecords:halaqaId/ASCENDING,studentId/ASCENDING,date/ASCENDING",
    "sessions:date/ASCENDING,startAt/ASCENDING",
  ]) {
    assert.ok(present.has(required), `missing index ${required}`);
  }
});

test("PH02 callables are behind the production backend gate", () => {
  const files = [
    "billing/paymentReview.ts",
    "billing/paymentProofSubmission.ts",
    "sessions/sessionRecordFunctions.ts",
    "halaqa/membershipFunctions.ts",
    "economy/economyFunctions.ts",
    "awards/awardFunctions.ts",
  ];
  for (const file of files) {
    const src = readFileSync(join(__dirname, "..", "src", file), "utf8");
    const onCalls = src.split("onCall(").length - 1;
    const gates = src.split("assertBackendAllowed(").length - 1;
    assert.ok(onCalls > 0, `${file} has callables`);
    assert.equal(gates, onCalls, `${file}: every callable is gated`);
  }
  const trigger = readFileSync(
    join(__dirname, "..", "src", "notifications/assignmentNotificationFunctions.ts"),
    "utf8",
  );
  assert.ok(trigger.includes('resolvePushSendMode() === "blocked"'));
});

test("H2 ownership trigger: a closed gate never throws; retry is bounded by the runner", () => {
  const src = readFileSync(
    join(__dirname, "..", "src", "notifications/fcmTokenOwnership.ts"),
    "utf8",
  );
  const trigger = src.slice(src.indexOf("export const reconcileFcmTokenOwnership"));
  assert.ok(!src.includes("assertBackendAllowed("), "triggers must not throw on a closed gate");
  assert.match(trigger, /retry: true/);
  assert.match(trigger, /await runOwnershipTrigger\(\{/);
  assert.match(trigger, /gateOpen: isProductionBackendEnabled\(\) \|\| isEmulatorBackendAllowed\(\)/);
  assert.match(trigger, /eventTime: event\.time/);
});
