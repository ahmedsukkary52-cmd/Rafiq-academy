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
    "recordSessionAttendance",
    "upsertSessionEvaluation",
    "notifyOnAssignmentCreated",
    "admitStudentToHalaqa",
    "adminTransferStudent",
    "completeHomework",
    "purchaseAvatar",
    "grantAward",
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
