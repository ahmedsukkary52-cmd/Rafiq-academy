/**
 * P0 completion — pure helper contract tests (no emulator).
 *
 * Covers: homework required-kind derivation + reward, weekly schedule slot
 * parsing / conflict engine, parent link children math, and the messaging
 * scope decisions (halaqa group excludes parents/admin; parent 1:1 by graph).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function load(path) {
  const resolved = require.resolve(path);
  delete require.cache[resolved];
  return require(path);
}

const economy = () => load("../lib/economy/economyFunctions.js");
const schedule = () => load("../lib/halaqa/halaqaScheduleFunctions.js");
const parentLink = () => load("../lib/relationships/parentLinkFunctions.js");
const groupSync = () => load("../lib/chat/halaqaGroupSync.js");
const chatRel = () => load("../lib/chat/chatRelationship.js");

// ── P0-05 homework economy ──────────────────────────────────────────

test("required kinds exclude recitation while audio uploads are disabled", () => {
  const { requiredHomeworkKinds, SERVER_CAPABILITIES } = economy();
  assert.equal(SERVER_CAPABILITIES.audioUploadsEnabled, false);
  assert.deepEqual(requiredHomeworkKinds(), ["reading", "listening"]);
  assert.deepEqual(
    requiredHomeworkKinds({ audioUploadsEnabled: true }),
    ["reading", "listening", "recitation"],
  );
});

test("reward derives from server kinds only, capped at 100", () => {
  const { rewardForRequiredKinds } = economy();
  assert.equal(rewardForRequiredKinds(["reading", "listening"]), 35);
  assert.equal(rewardForRequiredKinds(["reading", "listening", "recitation"]), 65);
  assert.equal(rewardForRequiredKinds([]), 0);
  assert.equal(rewardForRequiredKinds(["unknown"]), 0);
});

test("homework reward marker collection is stable", () => {
  const { HOMEWORK_REWARDS_COLLECTION, LESSON_HOMEWORK_KINDS } = economy();
  assert.equal(HOMEWORK_REWARDS_COLLECTION, "homeworkRewards");
  assert.ok(LESSON_HOMEWORK_KINDS.includes("lessonHomework"));
  assert.ok(!LESSON_HOMEWORK_KINDS.includes("quiz"));
});

// ── P0-04 schedule engine ───────────────────────────────────────────

test("parseSlotInput canonicalizes Arabic/English days and HH:mm", () => {
  const { parseSlotInput } = schedule();
  assert.deepEqual(parseSlotInput({ day: "السبت", startTime: "9:05", endTime: "10:00" }), {
    day: "السبت",
    startTime: "09:05",
    endTime: "10:00",
  });
  assert.equal(parseSlotInput({ day: "monday", startTime: "16:00", endTime: "17:00" }).day, "الاثنين");
});

test("parseSlotInput rejects malformed / inverted slots", () => {
  const { parseSlotInput } = schedule();
  for (const bad of [
    null,
    [],
    { day: "", startTime: "10:00", endTime: "11:00" },
    { day: "يوم", startTime: "10:00", endTime: "11:00" },
    { day: "السبت", startTime: "25:00", endTime: "26:00" },
    { day: "السبت", startTime: "11:00", endTime: "11:00" },
    { day: "السبت", startTime: "12:00", endTime: "11:00" },
  ]) {
    assert.throws(() => parseSlotInput(bad), (e) => e.code === "invalid-argument");
  }
});

test("weekly conflicts: same halaqa, same teacher, roster; adjacent and supervisor allowed", () => {
  const { evaluateWeeklyConflicts } = schedule();
  const slot = (day, s, e) => ({ day, startTime: s, endTime: e });
  const others = [
    { id: "hT", teacherId: "t1", studentIds: [], schedule: [slot("السبت", "10:00", "11:00")] },
    { id: "hS", teacherId: "t9", studentIds: ["s1"], schedule: [slot("الأحد", "10:00", "11:00")] },
    { id: "hX", teacherId: "t8", studentIds: ["s7"], schedule: [slot("الاثنين", "10:00", "11:00")] },
  ];
  const base = { halaqaId: "new", teacherId: "t1", studentIds: ["s1"], otherHalaqat: others };

  const sameHalaqa = evaluateWeeklyConflicts({
    ...base,
    existingSlots: [slot("الخميس", "10:00", "11:00")],
    newSlots: [slot("الخميس", "10:30", "11:30")],
  });
  assert.deepEqual(sameHalaqa.map((c) => c.reason), ["same_halaqa"]);

  const teacher = evaluateWeeklyConflicts({ ...base, existingSlots: [], newSlots: [slot("السبت", "10:30", "11:30")] });
  assert.deepEqual(teacher.map((c) => c.reason), ["same_teacher"]);

  const roster = evaluateWeeklyConflicts({ ...base, existingSlots: [], newSlots: [slot("الأحد", "10:00", "11:00")] });
  assert.deepEqual(roster.map((c) => c.reason), ["student_roster_intersection"]);

  const adjacent = evaluateWeeklyConflicts({ ...base, existingSlots: [], newSlots: [slot("السبت", "11:00", "12:00")] });
  assert.deepEqual(adjacent, []);

  // Different teacher, disjoint roster (supervisor sharing is not modelled as a conflict).
  const unrelated = evaluateWeeklyConflicts({ ...base, existingSlots: [], newSlots: [slot("الاثنين", "10:00", "11:00")] });
  assert.deepEqual(unrelated, []);
});

// ── P0-01 parent linking ────────────────────────────────────────────

test("parent link operation parsing", () => {
  const { parseParentLinkOperation } = parentLink();
  assert.equal(parseParentLinkOperation(undefined), "link");
  assert.equal(parseParentLinkOperation("unlink"), "unlink");
  assert.throws(() => parseParentLinkOperation("delete"), (e) => e.code === "invalid-argument");
});

test("nextChildrenIds is idempotent for link and unlink", () => {
  const { nextChildrenIds } = parentLink();
  assert.deepEqual(nextChildrenIds([], "s1", "link"), { childrenIds: ["s1"], changed: true });
  assert.deepEqual(nextChildrenIds(["s1"], "s1", "link"), { childrenIds: ["s1"], changed: false });
  assert.deepEqual(nextChildrenIds(["s1", "s2"], "s1", "unlink"), { childrenIds: ["s2"], changed: true });
  assert.deepEqual(nextChildrenIds(["s2"], "s1", "unlink"), { childrenIds: ["s2"], changed: false });
});

// ── §6 messaging scope ──────────────────────────────────────────────

test("halaqa group membership = teacher + supervisor + students only", () => {
  const { buildHalaqaGroupMembership } = groupSync();
  const m = buildHalaqaGroupMembership({
    teacherId: "t1",
    supervisorId: "sup1",
    studentIds: ["s1", "s2"],
  });
  assert.deepEqual([...m.participantIds].sort(), ["s1", "s2", "sup1", "t1"]);
  assert.ok(m.participants.every((p) => p.role !== "parent" && p.role !== "admin"));
});

test("parent 1:1 chats require a real relationship (admin always allowed)", () => {
  const { isDirectChatRelationshipAllowed, emptyRelationshipContext } = chatRel();
  const h1 = { id: "h1", teacherId: "t1", supervisorId: "sup1", studentIds: ["s1"] };
  const h2 = { id: "h2", teacherId: "t2", supervisorId: "sup2", studentIds: ["s9"] };
  const parent = { ...emptyRelationshipContext(), parentChildrenIds: ["s1"] };
  const unlinkedParent = emptyRelationshipContext();
  const teacher1 = { ...emptyRelationshipContext(), teacherHalaqat: [h1] };
  const teacher2 = { ...emptyRelationshipContext(), teacherHalaqat: [h2] };
  const sup1 = { ...emptyRelationshipContext(), supervisorHalaqat: [h1] };
  const sup2 = { ...emptyRelationshipContext(), supervisorHalaqat: [h2] };
  const admin = emptyRelationshipContext();

  const allowed = (roleB, uidB, ctxB, ctxA = parent) =>
    isDirectChatRelationshipAllowed({ roleA: "parent", uidA: "p1", roleB, uidB, ctxA, ctxB });

  assert.equal(allowed("teacher", "t1", teacher1), true);
  assert.equal(allowed("supervisor", "sup1", sup1), true);
  assert.equal(allowed("admin", "a1", admin), true);
  assert.equal(allowed("teacher", "t2", teacher2), false);
  assert.equal(allowed("supervisor", "sup2", sup2), false);
  assert.equal(allowed("teacher", "t1", teacher1, unlinkedParent), false);
  assert.equal(allowed("student", "s1", emptyRelationshipContext()), false);
});
