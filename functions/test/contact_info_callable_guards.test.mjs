/**
 * Server-side contact-info guards on free-text callable inputs (no emulator).
 *
 * Run: cd functions && npm run build && node --test test/contact_info_callable_guards.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const policy = require("../lib/privacy/contactInfoPolicy.js");
const review = require("../lib/billing/paymentReview.js");

const read = (...p) => readFileSync(join(repoRoot, ...p), "utf8");
const phone = "تواصل معي 0501234567";
const wa = "https://wa.me/966501234567";
const academic = "سورة البقرة 1-20، الدرجة 95/100، تمرين 3، الموعد 2026-10-15";

function assertRejected(fn) {
  try {
    fn();
    assert.fail("expected contact-info rejection");
  } catch (e) {
    assert.equal(e.code, "invalid-argument", e.message);
    assert.equal(e.message, policy.CONTACT_INFO_REJECTION_MESSAGE);
  }
}

test("contactInfoViolation mirrors detectContactInfo for free text", () => {
  assert.equal(policy.contactInfoViolation(phone), policy.CONTACT_INFO_REJECTION_MESSAGE);
  assert.equal(policy.contactInfoViolation(wa), policy.CONTACT_INFO_REJECTION_MESSAGE);
  assert.equal(policy.contactInfoViolation(""), null);
  assert.equal(policy.contactInfoViolation(null), null);
  assert.equal(policy.contactInfoViolation(academic), null);
  assert.equal(policy.contactInfoViolation("أحسنت! الدرجة 18 من 20"), null);
});

test("parseReviewRequest rejects contact notes and accepts academic notes", () => {
  assertRejected(() =>
    review.parseReviewRequest({
      paymentId: "pay1",
      decision: "approve",
      notes: phone,
    }),
  );
  assertRejected(() =>
    review.parseReviewRequest({
      paymentId: "pay1",
      decision: "reject",
      notes: wa,
    }),
  );
  const ok = review.parseReviewRequest({
    paymentId: "pay1",
    decision: "approve",
    notes: academic,
  });
  assert.equal(ok.notes, academic);
  assert.equal(
    review.parseReviewRequest({ paymentId: "pay1", decision: "approve" }).notes,
    "",
  );
});

test("award, evaluation, halaqa and reinstate cores guard free-text fields", () => {
  const awards = read("functions", "src", "awards", "awardFunctions.ts");
  const sessions = read("functions", "src", "sessions", "sessionRecordFunctions.ts");
  const halaqa = read("functions", "src", "halaqa", "halaqaScheduleFunctions.ts");
  const billing = read("functions", "src", "admin", "adminBilling.ts");
  const payment = read("functions", "src", "billing", "paymentReview.ts");

  for (const [label, src] of [
    ["grantAwardCore", awards],
    ["issueAchievementCore", awards],
    ["upsertSessionEvaluationCore", sessions],
    ["adminCreateHalaqaCore", halaqa],
    ["adminReinstatePaymentAccess", billing],
    ["parseReviewRequest", payment],
  ]) {
    assert.match(src, /contactInfoViolation/, `${label} must import/use contactInfoViolation`);
  }

  assert.match(awards, /contactInfoViolation\(title\)/);
  assert.match(awards, /contactInfoViolation\(description\)/);
  assert.match(sessions, /contactInfoViolation\(notes\)/);
  assert.match(halaqa, /contactInfoViolation\(name\)/);
  // Meeting links go through the shared URL policy, which applies the
  // contact detector itself (see meeting_link_policy.test.mjs).
  assert.match(halaqa, /optionalMeetingLink\(data\.meetingLink\)/);
  const meetingLink = read("functions", "src", "halaqa", "meetingLinkFunctions.ts");
  assert.match(meetingLink, /detectContactInfo\(value\)/);
  assert.match(meetingLink, /detectContactInfo\(rest\)/);
  assert.match(billing, /contactInfoViolation\(reason\)/);
  assert.match(payment, /contactInfoViolation\(notes\)/);
});

test("firestore.rules: recitation create and parent achievement/absence fixes", () => {
  const rules = read("firestore.rules");
  assert.match(
    rules,
    /function studentSubmissionOk\(\)[\s\S]*!hasContactField\(d\)/,
  );
  assert.match(rules, /resource == null\s*\n\s*\? isParent\(\)/);
  assert.match(rules, /function isLinkedParentOfAnyRecipient\(\)/);
  assert.match(rules, /isLinkedParentOfAnyRecipient\(\)/);
});
