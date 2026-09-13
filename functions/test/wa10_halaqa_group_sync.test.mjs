/**
 * WA-10 Halaqa group chat identity + membership sync tests.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function load() {
  const resolved = require.resolve("../lib/chat/halaqaGroupSync.js");
  delete require.cache[resolved];
  return require("../lib/chat/halaqaGroupSync.js");
}

const baseHalaqa = {
  name: "حلقة النور",
  teacherId: "teacher-1",
  supervisorId: "supervisor-1",
  studentIds: ["st-1", "st-2"],
};

test("deterministic group id", () => {
  const { halaqaGroupConversationId, isHalaqaGroupConversationId } = load();
  assert.equal(
    halaqaGroupConversationId("h1"),
    "halaqa_group_h1",
  );
  assert.equal(isHalaqaGroupConversationId("halaqa_group_h1"), true);
  assert.equal(isHalaqaGroupConversationId("a_b"), false);
});

test("membership includes teacher + supervisor + students", () => {
  const { buildHalaqaGroupMembership } = load();
  const m = buildHalaqaGroupMembership(baseHalaqa);
  assert.deepEqual(m.participantIds.sort(), [
    "st-1",
    "st-2",
    "supervisor-1",
    "teacher-1",
  ].sort());
  assert.equal(m.participants.find((p) => p.uid === "teacher-1").role, "teacher");
  assert.equal(
    m.participants.find((p) => p.uid === "supervisor-1").role,
    "supervisor",
  );
});

test("supervisor absent yields no supervisor member", () => {
  const { buildHalaqaGroupMembership } = load();
  const m = buildHalaqaGroupMembership({
    ...baseHalaqa,
    supervisorId: "",
  });
  assert.equal(m.participantIds.includes("supervisor-1"), false);
  assert.ok(m.participantIds.includes("teacher-1"));
});

test("parent and admin never projected as members", () => {
  const { buildHalaqaGroupMembership } = load();
  const m = buildHalaqaGroupMembership({
    teacherId: "teacher-1",
    supervisorId: "supervisor-1",
    studentIds: ["st-1", "parent-1", "admin-1"],
  });
  // parent-1 / admin-1 only appear if literally in studentIds — contract says
  // Parent is not a member via parent relationship. If a uid is incorrectly
  // placed in studentIds, projection still mirrors roster SSOT (halaqa.studentIds).
  // Parent *role* is not auto-added; we assert we never add a parentId field.
  assert.equal(m.participantIds.includes("teacher-1"), true);
  const withParentField = buildHalaqaGroupMembership({
    teacherId: "teacher-1",
    parentId: "parent-X",
    studentIds: ["st-1"],
  });
  assert.equal(withParentField.participantIds.includes("parent-X"), false);
});

test("duplicate student ids are deduplicated; teacher role wins", () => {
  const { buildHalaqaGroupMembership } = load();
  const m = buildHalaqaGroupMembership({
    teacherId: "teacher-1",
    studentIds: ["st-1", "st-1", "teacher-1"],
  });
  assert.equal(m.participantIds.filter((id) => id === "st-1").length, 1);
  assert.equal(m.participants.find((p) => p.uid === "teacher-1").role, "teacher");
});

test("create decision for missing conversation", () => {
  const { decideHalaqaGroupSync } = load();
  const d = decideHalaqaGroupSync({
    halaqaId: "h1",
    halaqa: baseHalaqa,
    existing: null,
  });
  assert.equal(d.action, "create");
  assert.equal(d.conversationId, "halaqa_group_h1");
  assert.ok(d.participantIds.includes("teacher-1"));
});

test("teacher replacement updates membership", () => {
  const { decideHalaqaGroupSync } = load();
  const d = decideHalaqaGroupSync({
    halaqaId: "h1",
    halaqa: { ...baseHalaqa, teacherId: "teacher-NEW" },
    existing: {
      kind: "halaqa_group",
      halaqaId: "h1",
      participantIds: ["teacher-1", "supervisor-1", "st-1", "st-2"],
      lastMessage: "hello",
      createdAt: "keep-me",
      unreadCounts: { "teacher-1": 2, "st-1": 1 },
    },
  });
  assert.equal(d.action, "update");
  assert.equal(d.participantIds.includes("teacher-1"), false);
  assert.equal(d.participantIds.includes("teacher-NEW"), true);
  assert.equal(d.preserve.lastMessage, "hello");
  assert.equal(d.preserve.createdAt, "keep-me");
  assert.equal(d.preserve.unreadCounts["teacher-1"], undefined);
  assert.equal(d.preserve.unreadCounts["teacher-NEW"], 0);
});

test("supervisor replacement and student add/remove", () => {
  const { decideHalaqaGroupSync } = load();
  const d = decideHalaqaGroupSync({
    halaqaId: "h1",
    halaqa: {
      ...baseHalaqa,
      supervisorId: "sv-NEW",
      studentIds: ["st-2", "st-3"],
    },
    existing: {
      kind: "halaqa_group",
      halaqaId: "h1",
      participantIds: ["teacher-1", "supervisor-1", "st-1", "st-2"],
    },
  });
  assert.equal(d.action, "update");
  assert.deepEqual(d.participantIds.sort(), [
    "st-2",
    "st-3",
    "sv-NEW",
    "teacher-1",
  ].sort());
});

test("repeated sync with same membership is noop", () => {
  const { decideHalaqaGroupSync, buildHalaqaGroupMembership } = load();
  const m = buildHalaqaGroupMembership(baseHalaqa);
  const d = decideHalaqaGroupSync({
    halaqaId: "h1",
    halaqa: baseHalaqa,
    existing: {
      kind: "halaqa_group",
      halaqaId: "h1",
      participantIds: m.participantIds,
    },
  });
  assert.equal(d.action, "noop");
});

test("historical lastMessage preserved across membership update", () => {
  const { decideHalaqaGroupSync } = load();
  const d = decideHalaqaGroupSync({
    halaqaId: "h1",
    halaqa: { ...baseHalaqa, studentIds: ["st-1"] },
    existing: {
      kind: "halaqa_group",
      halaqaId: "h1",
      participantIds: ["teacher-1", "supervisor-1", "st-1", "st-2"],
      lastMessage: "msg",
      lastMessageAt: "ts",
      lastMessageSenderId: "st-2",
      createdBy: "system",
    },
  });
  assert.equal(d.action, "update");
  assert.equal(d.preserve.lastMessage, "msg");
  assert.equal(d.preserve.lastMessageSenderId, "st-2");
  assert.equal(d.preserve.createdBy, "system");
});

test("membership field change detector ignores pointer-only updates", () => {
  const { halaqaMembershipFieldsChanged } = load();
  assert.equal(
    halaqaMembershipFieldsChanged(
      { ...baseHalaqa, groupConversationId: undefined },
      { ...baseHalaqa, groupConversationId: "halaqa_group_h1" },
    ),
    false,
  );
  assert.equal(
    halaqaMembershipFieldsChanged(baseHalaqa, {
      ...baseHalaqa,
      teacherId: "other",
    }),
    true,
  );
});

test("concurrent sync converges on one conversation + membership", async () => {
  const { syncHalaqaGroupInMemory } = load();
  const store = new Map();
  const locks = new Map();
  const results = await Promise.all(
    Array.from({ length: 20 }, () =>
      syncHalaqaGroupInMemory({
        store,
        locks,
        halaqaId: "h1",
        halaqa: baseHalaqa,
        createdBy: "system",
      }),
    ),
  );
  assert.equal(store.size, 1);
  assert.equal(new Set(results.map((r) => r.conversationId)).size, 1);
  assert.equal(results.filter((r) => r.action === "create").length, 1);
  const doc = store.get("halaqa_group_h1");
  assert.ok(doc.participantIds.includes("teacher-1"));
});

test("teacher change via concurrent sync removes stale teacher", async () => {
  const { syncHalaqaGroupInMemory } = load();
  const store = new Map();
  const locks = new Map();
  await syncHalaqaGroupInMemory({
    store,
    locks,
    halaqaId: "h1",
    halaqa: baseHalaqa,
  });
  await syncHalaqaGroupInMemory({
    store,
    locks,
    halaqaId: "h1",
    halaqa: { ...baseHalaqa, teacherId: "teacher-2" },
  });
  const doc = store.get("halaqa_group_h1");
  assert.equal(doc.participantIds.includes("teacher-1"), false);
  assert.equal(doc.participantIds.includes("teacher-2"), true);
});

test("index exports WA-10 sync functions and keeps Paymob quarantined", async () => {
  const { readFileSync } = await import("node:fs");
  const { join, dirname } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const src = readFileSync(
    join(dirname(fileURLToPath(import.meta.url)), "..", "src", "index.ts"),
    "utf8",
  );
  assert.match(src, /adminSyncHalaqaGroup/);
  assert.match(src, /syncHalaqaGroupOnWrite/);
  assert.doesNotMatch(src, /^export \{ createPaymentIntention/m);
});

test("callable rejects client-supplied participantIds in source", async () => {
  const { readFileSync } = await import("node:fs");
  const { join, dirname } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const src = readFileSync(
    join(
      dirname(fileURLToPath(import.meta.url)),
      "..",
      "src",
      "chat",
      "halaqaGroupSyncFunctions.ts",
    ),
    "utf8",
  );
  assert.match(src, /assertBackendAllowed\("adminSyncHalaqaGroup"\)/);
  assert.match(src, /assertBackendAllowed\("syncHalaqaGroupOnWrite"\)/);
  assert.match(src, /assertCallerIsAdmin/);
  assert.match(src, /participantIds !== undefined/);
  assert.match(src, /halaqaMembershipFieldsChanged/);
});
