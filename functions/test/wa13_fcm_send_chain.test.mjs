/**
 * WA-13 / C11 FCM token + send chain unit tests (no Firebase emulator).
 *
 * Run: cd functions && npm run build && npm run test:wa13
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const srcDir = join(dirname(fileURLToPath(import.meta.url)), "..", "src");

const tokens = require("../lib/notifications/fcmTokenContract.js");
const chain = require("../lib/notifications/evaluationNotification.js");
const gate = require("../lib/notifications/pushGate.js");

function withEnv(overrides, run) {
  const keys = ["PRODUCTION_BACKEND_ENABLED", "FUNCTIONS_EMULATOR"];
  const previous = {};
  for (const key of keys) previous[key] = process.env[key];
  for (const key of keys) delete process.env[key];
  for (const [key, value] of Object.entries(overrides)) {
    process.env[key] = value;
  }
  try {
    run();
  } finally {
    for (const key of keys) {
      if (previous[key] === undefined) delete process.env[key];
      else process.env[key] = previous[key];
    }
  }
}

// ── Token contract / upsert shape ──────────────────────────────────────────

test("WA-13 token contract pins the frozen C11 schema", () => {
  assert.deepEqual(tokens.FCM_PLATFORMS, ["android", "ios", "web"]);
  assert.deepEqual(tokens.FCM_CLIENT_FIELDS, [
    "token",
    "platform",
    "createdAt",
    "updatedAt",
    "disabled",
  ]);
  for (const field of tokens.FCM_SERVER_FIELDS) {
    assert.ok(!tokens.FCM_CLIENT_FIELDS.includes(field));
  }
});

test("WA-13 multiple devices are all selected, deterministically", () => {
  const selected = tokens.selectSendableTokens([
    { deviceId: "dev_b", token: "tok-b", platform: "ios", disabled: false },
    { deviceId: "dev_a", token: "tok-a", platform: "android", disabled: false },
  ]);
  assert.deepEqual(
    selected.map((s) => s.deviceId),
    ["dev_a", "dev_b"],
  );
});

test("WA-13 disabled and malformed tokens are never sent to", () => {
  const selected = tokens.selectSendableTokens([
    { deviceId: "dev_off", token: "tok-off", disabled: true },
    { deviceId: "dev_empty", token: "   ", disabled: false },
    { deviceId: "dev_missing", disabled: false },
    { deviceId: "dev_ok", token: "tok-ok", disabled: false },
  ]);
  assert.deepEqual(selected, [{ deviceId: "dev_ok", token: "tok-ok" }]);
});

test("WA-13 same token on two device docs is de-duplicated and capped", () => {
  const duplicated = tokens.selectSendableTokens([
    { deviceId: "dev_a", token: "same", disabled: false },
    { deviceId: "dev_b", token: "same", disabled: false },
  ]);
  assert.equal(duplicated.length, 1);

  const many = Array.from({ length: 40 }, (_, i) => ({
    deviceId: `dev_${String(i).padStart(3, "0")}`,
    token: `tok-${i}`,
    disabled: false,
  }));
  assert.equal(
    tokens.selectSendableTokens(many).length,
    tokens.MAX_TOKENS_PER_RECIPIENT,
  );
});

// ── Send outcomes: partial failure + stale token cleanup ───────────────────

test("WA-13 unregistered tokens are disabled; other errors stay retriable", () => {
  const summary = tokens.summarizeSendOutcomes([
    { deviceId: "dev_ok", success: true },
    {
      deviceId: "dev_dead",
      success: false,
      errorCode: "messaging/registration-token-not-registered",
    },
    {
      deviceId: "dev_flaky",
      success: false,
      errorCode: "messaging/server-unavailable",
    },
  ]);

  assert.equal(summary.status, "partial");
  assert.equal(summary.successCount, 1);
  assert.equal(summary.failureCount, 2);
  assert.deepEqual(summary.invalidDeviceIds, ["dev_dead"]);
  assert.deepEqual(summary.retriableDeviceIds, ["dev_flaky"]);
});

test("WA-13 payload errors never mass-disable devices", () => {
  const summary = tokens.summarizeSendOutcomes([
    {
      deviceId: "dev_a",
      success: false,
      errorCode: "messaging/invalid-argument",
    },
  ]);
  assert.equal(summary.status, "failed");
  assert.deepEqual(summary.invalidDeviceIds, []);
  assert.deepEqual(summary.retriableDeviceIds, ["dev_a"]);
});

test("WA-13 no tokens is a distinct terminal state, not a failure", () => {
  assert.equal(tokens.summarizeSendOutcomes([]).status, "no_tokens");
});

// ── Live evaluation → event → notification ─────────────────────────────────

const liveEval = {
  studentId: "student1",
  halaqaId: "h1",
  sessionId: "h1_20260101",
  grade: "ممتاز",
  reviewStatus: "reviewed",
};

test("WA-13 live evaluation create notifies with the frozen event identity", () => {
  const decision = chain.decideEvaluationNotification({
    recordId: "h1_20260101_student1_memorization",
    before: null,
    after: liveEval,
  });

  assert.equal(decision.notify, true);
  assert.equal(
    decision.eventId,
    "homework_reviewed_h1_20260101_student1_memorization",
  );
  assert.equal(
    decision.facts.evaluationId,
    "h1_20260101_student1_memorization",
  );
  assert.equal(decision.facts.studentId, "student1");
  assert.equal(decision.facts.sessionId, "h1_20260101");
});

test("WA-13 duplicate trigger for the same fact does not notify twice", () => {
  const decision = chain.decideEvaluationNotification({
    recordId: "rec1",
    before: liveEval,
    after: { ...liveEval, grade: "جيد" },
  });
  assert.equal(decision.notify, false);
  assert.equal(decision.reason, "already_notified_fact");
});

test("WA-13 pending reviews, assignment submissions and deletes are skipped", () => {
  assert.equal(
    chain.decideEvaluationNotification({
      recordId: "rec1",
      before: null,
      after: { ...liveEval, reviewStatus: "pending" },
    }).notify,
    false,
  );
  assert.equal(
    chain.decideEvaluationNotification({
      recordId: "rec1",
      before: null,
      after: { ...liveEval, assignmentId: "a1" },
    }).notify,
    false,
  );
  assert.equal(
    chain.decideEvaluationNotification({
      recordId: "rec1",
      before: liveEval,
      after: null,
    }).notify,
    false,
  );
});

test("WA-13 notification carries the real persisted evaluation id only", () => {
  const decision = chain.decideEvaluationNotification({
    recordId: "rec42",
    before: null,
    after: liveEval,
  });
  const notification = chain.buildParentEvaluationNotification({
    parentId: "parent1",
    eventId: decision.eventId,
    facts: decision.facts,
    studentName: "أحمد",
  });

  assert.equal(
    notification.notificationId,
    "parent1_homework_reviewed_rec42",
  );
  assert.equal(notification.audience, "parent1");
  assert.equal(notification.data.evaluationId, "rec42");
  assert.equal(notification.data.studentId, "student1");
  assert.equal(notification.data.sessionId, "h1_20260101");
  assert.match(notification.body, /أحمد/);
  assert.doesNotThrow(() => chain.assertSafeDataPayload(notification.data));
});

test("WA-13 private data and oversized payloads are rejected", () => {
  assert.throws(() => chain.assertSafeDataPayload({ parentPhone: "0100" }));
  assert.throws(() =>
    chain.assertSafeDataPayload({ note: "x".repeat(2000) }),
  );
});

// ── Idempotency of delivery ────────────────────────────────────────────────

test("WA-13 a delivered notification is never re-sent on function retry", () => {
  assert.deepEqual(chain.decideDeliveryAttempt({ status: "sent" }), {
    proceed: false,
    reason: "already_sent",
  });
  assert.deepEqual(chain.decideDeliveryAttempt({ status: "no_tokens" }), {
    proceed: false,
    reason: "already_no_tokens",
  });
});

test("WA-13 transient failures retry within a bounded attempt budget", () => {
  assert.deepEqual(chain.decideDeliveryAttempt(null), {
    proceed: true,
    attempt: 1,
  });
  assert.deepEqual(
    chain.decideDeliveryAttempt({ status: "partial", attempts: 1 }),
    { proceed: true, attempt: 2 },
  );
  assert.deepEqual(
    chain.decideDeliveryAttempt({
      status: "failed",
      attempts: chain.MAX_DELIVERY_ATTEMPTS,
    }),
    { proceed: false, reason: "max_attempts_reached" },
  );
});

// ── Production gate ────────────────────────────────────────────────────────

test("WA-13 production sending stays blocked until B-BILLING is verified", () => {
  withEnv({}, () => {
    assert.equal(gate.resolvePushSendMode(), "blocked");
    assert.equal(gate.isPushSendAllowed(gate.resolvePushSendMode()), false);
  });
});

test("WA-13 emulator remains testable and explicit production opt-in works", () => {
  withEnv({ FUNCTIONS_EMULATOR: "true" }, () => {
    assert.equal(gate.resolvePushSendMode(), "emulator");
    assert.equal(gate.isPushSendAllowed(gate.resolvePushSendMode()), true);
  });
  withEnv({ PRODUCTION_BACKEND_ENABLED: "true" }, () => {
    assert.equal(gate.resolvePushSendMode(), "production");
  });
  // ALLOW_EMULATOR_BACKEND must not open the gate (WA-0 semantics unchanged).
  withEnv({ ALLOW_EMULATOR_BACKEND: "true" }, () => {
    assert.equal(gate.resolvePushSendMode(), "blocked");
  });
});

// ── Source contracts ───────────────────────────────────────────────────────

test("WA-13 trigger is gated, server-authored and exported", () => {
  const trigger = readFileSync(
    join(srcDir, "notifications", "evaluationNotificationFunctions.ts"),
    "utf8",
  );
  assert.match(trigger, /resolvePushSendMode\(\)/);
  assert.match(trigger, /if \(mode === "blocked"\)/);
  assert.match(trigger, /recitationRecords\/\{recordId\}/);
  assert.match(trigger, /sendEachForMulticast/);
  assert.match(trigger, /collapseKey/);

  const index = readFileSync(join(srcDir, "index.ts"), "utf8");
  assert.match(index, /notifyParentsOnEvaluation/);
});

test("WA-13 client never receives FCM server credentials (no client send path)", () => {
  const rules = readFileSync(join(srcDir, "..", "..", "firestore.rules"), "utf8");
  assert.match(rules, /match \/notificationDeliveries\/\{notificationId\}/);
  assert.match(rules, /match \/fcmTokens\/\{userId\}/);
});
