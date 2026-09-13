/**
 * WA-11 — 1:1 relationship authorization + soft-delete/edit pure helpers.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import fs from "node:fs";

const require = createRequire(import.meta.url);

function load() {
  const resolved = require.resolve("../lib/chat/chatRelationship.js");
  delete require.cache[resolved];
  return require("../lib/chat/chatRelationship.js");
}

function ctx(partial = {}) {
  const { emptyRelationshipContext } = load();
  return { ...emptyRelationshipContext(), ...partial };
}

function halaqa(overrides = {}) {
  return {
    id: "h1",
    teacherId: "teacher-own",
    supervisorId: "supervisor-own",
    studentIds: ["student-own"],
    ...overrides,
  };
}

test("deterministic direct conversation id", () => {
  const { directConversationId } = load();
  assert.equal(directConversationId("b", "a"), "a_b");
  assert.equal(directConversationId("a", "b"), "a_b");
  assert.throws(() => directConversationId("a", "a"));
});

test("student → own teacher succeeds", () => {
  const { isDirectChatRelationshipAllowed } = load();
  const h = halaqa();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "student",
      uidA: "student-own",
      roleB: "teacher",
      uidB: "teacher-own",
      ctxA: ctx({ studentHalaqat: [h] }),
      ctxB: ctx({ teacherHalaqat: [h] }),
    }),
    true,
  );
});

test("student → unrelated teacher denied", () => {
  const { isDirectChatRelationshipAllowed } = load();
  const h = halaqa();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "student",
      uidA: "student-own",
      roleB: "teacher",
      uidB: "teacher-other",
      ctxA: ctx({ studentHalaqat: [h] }),
      ctxB: ctx({
        teacherHalaqat: [halaqa({ teacherId: "teacher-other", studentIds: ["x"] })],
      }),
    }),
    false,
  );
});

test("parent → linked child teacher succeeds", () => {
  const { isDirectChatRelationshipAllowed } = load();
  const h = halaqa();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "parent",
      uidA: "parent-1",
      roleB: "teacher",
      uidB: "teacher-own",
      ctxA: ctx({ parentChildrenIds: ["student-own"] }),
      ctxB: ctx({ teacherHalaqat: [h] }),
    }),
    true,
  );
});

test("parent → unrelated teacher denied", () => {
  const { isDirectChatRelationshipAllowed } = load();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "parent",
      uidA: "parent-1",
      roleB: "teacher",
      uidB: "teacher-other",
      ctxA: ctx({ parentChildrenIds: ["student-own"] }),
      ctxB: ctx({
        teacherHalaqat: [
          halaqa({
            teacherId: "teacher-other",
            studentIds: ["other-student"],
          }),
        ],
      }),
    }),
    false,
  );
});

test("parent → linked child supervisor succeeds", () => {
  const { isDirectChatRelationshipAllowed } = load();
  const h = halaqa();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "parent",
      uidA: "parent-1",
      roleB: "supervisor",
      uidB: "supervisor-own",
      ctxA: ctx({ parentChildrenIds: ["student-own"] }),
      ctxB: ctx({ supervisorHalaqat: [h] }),
    }),
    true,
  );
});

test("parent → unrelated supervisor denied", () => {
  const { isDirectChatRelationshipAllowed } = load();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "parent",
      uidA: "parent-1",
      roleB: "supervisor",
      uidB: "supervisor-other",
      ctxA: ctx({ parentChildrenIds: ["student-own"] }),
      ctxB: ctx({
        supervisorHalaqat: [
          halaqa({
            supervisorId: "supervisor-other",
            studentIds: ["other-student"],
          }),
        ],
      }),
    }),
    false,
  );
});

test("teacher → assigned student succeeds", () => {
  const { isDirectChatRelationshipAllowed } = load();
  const h = halaqa();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "teacher",
      uidA: "teacher-own",
      roleB: "student",
      uidB: "student-own",
      ctxA: ctx({ teacherHalaqat: [h] }),
      ctxB: ctx({ studentHalaqat: [h] }),
    }),
    true,
  );
});

test("teacher → unrelated student denied", () => {
  const { isDirectChatRelationshipAllowed } = load();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "teacher",
      uidA: "teacher-own",
      roleB: "student",
      uidB: "student-other",
      ctxA: ctx({ teacherHalaqat: [halaqa()] }),
      ctxB: ctx({
        studentHalaqat: [
          halaqa({
            id: "h2",
            teacherId: "teacher-other",
            studentIds: ["student-other"],
          }),
        ],
      }),
    }),
    false,
  );
});

test("supervisor → authorized halaqa student succeeds", () => {
  const { isDirectChatRelationshipAllowed } = load();
  const h = halaqa();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "supervisor",
      uidA: "supervisor-own",
      roleB: "student",
      uidB: "student-own",
      ctxA: ctx({ supervisorHalaqat: [h] }),
      ctxB: ctx({ studentHalaqat: [h] }),
    }),
    true,
  );
});

test("supervisor → unrelated student denied", () => {
  const { isDirectChatRelationshipAllowed } = load();
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "supervisor",
      uidA: "supervisor-own",
      roleB: "student",
      uidB: "student-other",
      ctxA: ctx({ supervisorHalaqat: [halaqa()] }),
      ctxB: ctx({
        studentHalaqat: [
          halaqa({
            supervisorId: "supervisor-other",
            studentIds: ["student-other"],
          }),
        ],
      }),
    }),
    false,
  );
});

test("arbitrary role-pair alone is denied without graph", () => {
  const { isDirectChatRelationshipAllowed, rolesMayDirectChat } = load();
  assert.equal(rolesMayDirectChat("student", "teacher"), true);
  assert.equal(
    isDirectChatRelationshipAllowed({
      roleA: "student",
      uidA: "s1",
      roleB: "teacher",
      uidB: "t1",
      ctxA: ctx(),
      ctxB: ctx(),
    }),
    false,
  );
  assert.equal(rolesMayDirectChat("student", "admin"), false);
  assert.equal(rolesMayDirectChat("student", "parent"), false);
});

test("soft-delete payload records deleted/deletedBy", () => {
  const { softDeletePayload } = load();
  const now = new Date("2026-09-13T10:00:00Z");
  const p = softDeletePayload({ deletedBy: "u1", now });
  assert.equal(p.deleted, true);
  assert.equal(p.deletedBy, "u1");
  assert.equal(p.deletedAt.toISOString(), now.toISOString());
  assert.equal(p.text, "");
});

test("sender can soft-delete own; cannot soft-delete another", () => {
  const { canSoftDeleteMessage } = load();
  assert.equal(
    canSoftDeleteMessage({
      senderId: "u1",
      callerUid: "u1",
      callerRole: "student",
    }),
    true,
  );
  assert.equal(
    canSoftDeleteMessage({
      senderId: "u1",
      callerUid: "u2",
      callerRole: "teacher",
    }),
    false,
  );
  assert.equal(
    canSoftDeleteMessage({
      senderId: "u1",
      callerUid: "admin1",
      callerRole: "admin",
    }),
    true,
  );
  assert.equal(
    canSoftDeleteMessage({
      senderId: "u1",
      callerUid: "u1",
      callerRole: "student",
      alreadyDeleted: true,
    }),
    false,
  );
});

test("sender can edit own within window; not another's; editedAt path", () => {
  const { canEditMessage, MESSAGE_EDIT_WINDOW_MS } = load();
  const sentAt = new Date("2026-09-13T10:00:00Z");
  assert.equal(
    canEditMessage({
      senderId: "u1",
      callerUid: "u1",
      sentAt,
      now: new Date(sentAt.getTime() + 60_000),
    }),
    true,
  );
  assert.equal(
    canEditMessage({
      senderId: "u1",
      callerUid: "u2",
      sentAt,
      now: new Date(sentAt.getTime() + 60_000),
    }),
    false,
  );
  assert.equal(
    canEditMessage({
      senderId: "u1",
      callerUid: "u1",
      sentAt,
      now: new Date(sentAt.getTime() + MESSAGE_EDIT_WINDOW_MS + 1),
    }),
    false,
  );
  assert.equal(
    canEditMessage({
      senderId: "u1",
      callerUid: "u1",
      sentAt,
      now: new Date(sentAt.getTime() + 60_000),
      alreadyDeleted: true,
    }),
    false,
  );
});

test("WA-10 group id still deterministic and distinct from direct", () => {
  const group = require("../lib/chat/halaqaGroupSync.js");
  const { directConversationId } = load();
  assert.equal(group.halaqaGroupConversationId("h1"), "halaqa_group_h1");
  assert.equal(group.isHalaqaGroupConversationId("halaqa_group_h1"), true);
  assert.equal(
    group.isHalaqaGroupConversationId(directConversationId("a", "b")),
    false,
  );
  const membership = group.buildHalaqaGroupMembership({
    teacherId: "t1",
    supervisorId: "sv1",
    studentIds: ["s1"],
    parentId: "p1",
  });
  assert.equal(membership.participantIds.includes("p1"), false);
  assert.equal(membership.participantIds.includes("admin"), false);
});

test("index exports WA-11 chat auth callables", () => {
  const src = fs.readFileSync(
    join(dirname(fileURLToPath(import.meta.url)), "../src/index.ts"),
    "utf8",
  );
  assert.match(src, /createDirectConversation/);
  assert.match(src, /softDeleteChatMessage/);
  assert.match(src, /editChatMessage/);
});
