/**
 * Admin group: membership projected from users/ by the backend only
 * (pure decision, transactional ensure, users/{uid} trigger, access denial).
 * No emulator; in-memory Firestore double with optimistic transaction retry.
 *
 * Run: cd functions && npx tsc && node --test test/admin_group_sync.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const pure = require("../lib/chat/adminGroupSync.js");
const fns = require("../lib/chat/adminGroupFunctions.js");
const { sendChatMessageCore } = require("../lib/chat/chatMessageFunctions.js");

const GROUP = "conversations/admin_internal_group";

/** Path-keyed Firestore double: docs, subcollections, == queries, transactions. */
function fakeDb(seed = {}) {
  const store = new Map(Object.entries(structuredClone(seed)));
  const writes = [];
  const versions = new Map();
  const bump = (path) => versions.set(path, (versions.get(path) ?? 0) + 1);

  const snap = (path) => {
    const data = store.get(path);
    return { id: path.split("/").pop(), ref: docRef(path), exists: data !== undefined, data: () => data };
  };
  function docRef(path) {
    return {
      id: path.split("/").pop(),
      path,
      async get() {
        return snap(path);
      },
      collection: (name) => collectionRef(`${path}/${name}`),
    };
  }
  function query(col, filters) {
    return {
      where: (field, op, value) => query(col, [...filters, { field, op, value }]),
      run() {
        const docs = [];
        for (const [path, data] of store) {
          const parent = path.slice(0, path.lastIndexOf("/"));
          if (parent !== col) continue;
          if (filters.every(({ field, op, value }) => op === "==" && data[field] === value)) docs.push(snap(path));
        }
        return { docs };
      },
      async get() {
        return this.run();
      },
    };
  }
  function collectionRef(col) {
    return {
      doc: (id) => docRef(`${col}/${id}`),
      where: (field, op, value) => query(col, [{ field, op, value }]),
    };
  }

  async function attempt(fn) {
    const read = new Map();
    const pending = [];
    let wrote = false;
    const tx = {
      async get(target) {
        if (wrote) throw new Error("transaction read after write");
        if (typeof target.run === "function") return target.run();
        read.set(target.path, versions.get(target.path) ?? 0);
        return snap(target.path);
      },
      create: (ref, data) => ((wrote = true), pending.push(["create", ref.path, data])),
      update: (ref, data) => ((wrote = true), pending.push(["update", ref.path, data])),
      set: (ref, data, opts) => ((wrote = true), pending.push([opts?.merge ? "merge" : "set", ref.path, data])),
      delete: (ref) => ((wrote = true), pending.push(["delete", ref.path])),
    };
    const result = await fn(tx);
    // Yield so concurrent transactions interleave between read and commit.
    await new Promise((r) => setImmediate(r));
    for (const [path, v] of read) if ((versions.get(path) ?? 0) !== v) return { conflict: true };
    for (const [kind, path] of pending) {
      const before = store.get(path);
      if (kind === "create" && before !== undefined) return { conflict: true };
      if (kind === "update" && before === undefined) throw new Error(`update missing ${path}`);
    }
    for (const [kind, path, data] of pending) {
      const before = store.get(path);
      if (kind === "delete") store.delete(path);
      else if (kind === "update" || kind === "merge") store.set(path, { ...before, ...structuredClone(data) });
      else store.set(path, structuredClone(data));
      bump(path);
      writes.push({ kind, path, data });
    }
    return { result };
  }

  return {
    store,
    writes,
    collection: collectionRef,
    doc: docRef,
    async runTransaction(fn) {
      for (let i = 0; i < 10; i++) {
        const out = await attempt(fn);
        if (!out.conflict) return out.result;
      }
      throw new Error("transaction contention");
    },
  };
}

const admin = (name, extra = {}) => ({ role: "admin", name, isActive: true, ...extra });

function seedUsers() {
  return {
    "users/a1": admin("مدير أول"),
    "users/a2": admin("مدير ثان"),
    "users/a3": admin("مدير معطل", { isActive: false }),
    "users/a4": admin("مدير جديد", { passwordChangeRequired: true }),
    "users/t1": { role: "teacher", name: "معلم", isActive: true },
  };
}

async function rejectsWith(promise, code) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code, `expected ${code}, got ${e.code}: ${e.message}`);
    return true;
  });
}

// ── Pure decision ───────────────────────────────────────────────────────────

test("eligibility follows activeRoleOf: only an active Admin with a completed first login", () => {
  const { isAdminGroupEligible } = pure;
  assert.equal(isAdminGroupEligible(admin("x")), true);
  assert.equal(isAdminGroupEligible({ role: "admin", name: "legacy" }), true, "missing isActive is active");
  assert.equal(isAdminGroupEligible(admin("x", { isActive: false })), false);
  assert.equal(isAdminGroupEligible(admin("x", { passwordChangeRequired: true })), false);
  assert.equal(isAdminGroupEligible({ role: "teacher", isActive: true }), false);
  assert.equal(isAdminGroupEligible(undefined), false);
});

test("members are derived from user records only, deduplicated and sorted", () => {
  const members = pure.buildAdminGroupMembers([
    { uid: "b", data: admin("ب") },
    { uid: "a", data: admin("أ") },
    { uid: "a", data: admin("أ") },
    { uid: "c", data: admin("ج", { isActive: false }) },
    { uid: "  ", data: admin("فارغ") },
    { uid: "t", data: { role: "teacher" } },
  ]);
  assert.deepEqual(members, [
    { uid: "a", role: "admin", name: "أ" },
    { uid: "b", role: "admin", name: "ب" },
  ]);
});

test("only eligibility or name changes of an Admin are relevant", () => {
  const { adminGroupRelevantChange: changed } = pure;
  assert.equal(changed(undefined, admin("x")), true, "new active Admin");
  assert.equal(changed(undefined, admin("x", { passwordChangeRequired: true })), false, "provisioned, not yet active");
  assert.equal(changed(admin("x", { passwordChangeRequired: true }), admin("x")), true, "first login completed");
  assert.equal(changed(admin("x"), admin("x", { isActive: false })), true, "deactivated");
  assert.equal(changed(admin("x"), { ...admin("x"), role: "teacher" }), true, "demoted");
  assert.equal(changed(admin("x"), undefined), true, "deleted");
  assert.equal(changed(admin("x"), admin("y")), true, "renamed");
  assert.equal(changed(admin("x"), { ...admin("x"), phone: "1" }), false, "unrelated field");
  assert.equal(changed({ role: "teacher", name: "a" }, { role: "teacher", name: "b" }), false, "not an Admin");
});

test("decide: absent without create permission, create, noop, update and foreign kind", () => {
  const users = [
    { uid: "a1", data: admin("أ") },
    { uid: "a2", data: admin("ب") },
  ];
  assert.equal(pure.decideAdminGroupSync({ users, existing: null, allowCreate: false }).action, "absent");
  const created = pure.decideAdminGroupSync({ users, existing: null, allowCreate: true });
  assert.equal(created.action, "create");
  assert.deepEqual(created.participantIds, ["a1", "a2"]);

  const existing = {
    kind: "admin_group",
    title: "مجموعة الإدارة",
    participantIds: ["a2", "a1"],
    participants: created.participants,
    unreadCounts: { a1: 3, a2: 0 },
  };
  assert.equal(pure.decideAdminGroupSync({ users, existing, allowCreate: false }).action, "noop");

  const shrunk = pure.decideAdminGroupSync({ users: users.slice(0, 1), existing, allowCreate: false });
  assert.equal(shrunk.action, "update");
  assert.deepEqual(shrunk.participantIds, ["a1"]);
  assert.deepEqual(shrunk.unreadCounts, { a1: 3 }, "removed member's counter dropped, others kept");

  assert.throws(
    () => pure.decideAdminGroupSync({ users, existing: { ...existing, kind: "custom_group" }, allowCreate: true }),
    /not an admin group/,
  );
});

// ── ensureAdminGroupConversation ────────────────────────────────────────────

test("ensure creates the group once with exactly the active Admins", async () => {
  const db = fakeDb(seedUsers());
  const res = await fns.ensureAdminGroupConversationCore(db, "a1", {});
  assert.deepEqual(res, { conversationId: "admin_internal_group", action: "create", participantCount: 2 });
  const doc = db.store.get(GROUP);
  assert.equal(doc.kind, "admin_group");
  assert.equal(doc.title, "مجموعة الإدارة");
  assert.deepEqual(doc.participantIds, ["a1", "a2"]);
  assert.deepEqual(doc.unreadCounts, { a1: 0, a2: 0 });
  assert.equal(doc.createdBy, "a1");

  const again = await fns.ensureAdminGroupConversationCore(db, "a2", undefined);
  assert.equal(again.action, "noop");
  assert.equal(db.writes.filter((w) => w.path === GROUP).length, 1);
});

test("concurrent ensure calls never create a second group", async () => {
  const db = fakeDb(seedUsers());
  const results = await Promise.all(
    ["a1", "a2", "a1", "a2", "a1"].map((uid) => fns.ensureAdminGroupConversationCore(db, uid, {})),
  );
  assert.equal(results.filter((r) => r.action === "create").length, 1);
  assert.equal(db.writes.filter((w) => w.kind === "create").length, 1);
  assert.equal([...db.store.keys()].filter((k) => k.startsWith("conversations/")).length, 1);
});

test("ensure denies unauthenticated, non-Admin, deactivated and first-login Admins", async () => {
  const db = fakeDb(seedUsers());
  await rejectsWith(fns.ensureAdminGroupConversationCore(db, undefined, {}), "unauthenticated");
  await rejectsWith(fns.ensureAdminGroupConversationCore(db, "t1", {}), "permission-denied");
  await rejectsWith(fns.ensureAdminGroupConversationCore(db, "a3", {}), "permission-denied");
  await rejectsWith(fns.ensureAdminGroupConversationCore(db, "a4", {}), "permission-denied");
  await rejectsWith(fns.ensureAdminGroupConversationCore(db, "ghost", {}), "permission-denied");
  assert.equal(db.store.has(GROUP), false);
});

test("ensure rejects any client-supplied membership", async () => {
  const db = fakeDb(seedUsers());
  for (const field of pure.ADMIN_GROUP_CLIENT_FORBIDDEN_FIELDS) {
    await rejectsWith(fns.ensureAdminGroupConversationCore(db, "a1", { [field]: ["t1"] }), "invalid-argument");
  }
  assert.equal(db.store.has(GROUP), false);
});

test("ensure refuses to take over the reserved id when it holds another kind", async () => {
  const db = fakeDb({
    ...seedUsers(),
    [GROUP]: { kind: "custom_group", participantIds: ["t1"], title: "x" },
  });
  await rejectsWith(fns.ensureAdminGroupConversationCore(db, "a1", {}), "failed-precondition");
  assert.deepEqual(db.store.get(GROUP).participantIds, ["t1"]);
});

test("ensure re-syncs a stale group and keeps the conversation history fields", async () => {
  const db = fakeDb({
    ...seedUsers(),
    [GROUP]: {
      kind: "admin_group",
      title: "قديم",
      participantIds: ["a1", "a3", "t1"],
      participants: [],
      unreadCounts: { a1: 2, a3: 5, t1: 1 },
      lastMessage: "مرحبا",
      lastMessageAt: "ts",
      lastMessageSenderId: "a1",
      createdAt: "created",
      createdBy: "a1",
    },
  });
  const res = await fns.ensureAdminGroupConversationCore(db, "a2", {});
  assert.equal(res.action, "update");
  const doc = db.store.get(GROUP);
  assert.deepEqual(doc.participantIds, ["a1", "a2"]);
  assert.deepEqual(doc.unreadCounts, { a1: 2, a2: 0 });
  assert.equal(doc.title, "مجموعة الإدارة");
  assert.equal(doc.lastMessage, "مرحبا");
  assert.equal(doc.lastMessageSenderId, "a1");
  assert.equal(doc.createdAt, "created");
  assert.equal(doc.createdBy, "a1");
});

// ── users/{uid} trigger ─────────────────────────────────────────────────────

async function withGroup() {
  const db = fakeDb(seedUsers());
  await fns.ensureAdminGroupConversationCore(db, "a1", {});
  db.writes.length = 0;
  return db;
}

async function writeUser(db, uid, after) {
  const path = `users/${uid}`;
  const before = db.store.get(path);
  if (after === undefined) db.store.delete(path);
  else db.store.set(path, after);
  return fns.handleAdminGroupUserWrite(db, before, after);
}

test("trigger: a new Admin joins only after completing first login", async () => {
  const db = await withGroup();
  assert.equal(await writeUser(db, "a5", admin("مدير خامس", { passwordChangeRequired: true })), null);
  assert.deepEqual(db.store.get(GROUP).participantIds, ["a1", "a2"]);
  assert.equal(await writeUser(db, "a5", admin("مدير خامس")), "update");
  assert.deepEqual(db.store.get(GROUP).participantIds, ["a1", "a2", "a5"]);
  assert.equal(db.store.get(GROUP).unreadCounts.a5, 0);
});

test("trigger: deactivation, demotion and deletion remove the Admin", async () => {
  const db = await withGroup();
  await writeUser(db, "a5", admin("خامس"));
  await writeUser(db, "a1", { ...db.store.get("users/a1"), isActive: false });
  assert.deepEqual(db.store.get(GROUP).participantIds, ["a2", "a5"]);
  assert.equal("a1" in db.store.get(GROUP).unreadCounts, false);
  await writeUser(db, "a2", { ...db.store.get("users/a2"), role: "teacher" });
  assert.deepEqual(db.store.get(GROUP).participantIds, ["a5"]);
  await writeUser(db, "a5", undefined);
  assert.deepEqual(db.store.get(GROUP).participantIds, []);
});

test("trigger: reactivation restores membership and a rename refreshes the stub", async () => {
  const db = await withGroup();
  assert.equal(await writeUser(db, "a3", { ...db.store.get("users/a3"), isActive: true }), "update");
  assert.deepEqual(db.store.get(GROUP).participantIds, ["a1", "a2", "a3"]);
  await writeUser(db, "a2", { ...db.store.get("users/a2"), name: "اسم جديد" });
  assert.equal(db.store.get(GROUP).participants.find((p) => p.uid === "a2").name, "اسم جديد");
});

test("trigger: unrelated writes and non-Admin users never touch the group", async () => {
  const db = await withGroup();
  assert.equal(await writeUser(db, "a1", { ...db.store.get("users/a1"), phone: "x" }), null);
  assert.equal(await writeUser(db, "t1", { ...db.store.get("users/t1"), name: "جديد" }), null);
  assert.equal(await writeUser(db, "t2", { role: "teacher", isActive: true }), null);
  assert.deepEqual(db.writes, []);
});

test("trigger: never creates the group (seeding a fresh project writes nothing)", async () => {
  const db = fakeDb(seedUsers());
  assert.equal(await writeUser(db, "a9", admin("تاسع")), "absent");
  assert.equal(db.store.has(GROUP), false);
  assert.deepEqual(db.writes, []);
});

// ── Access after removal (existing sendChatMessage guards) ──────────────────

test("a deactivated or demoted former member cannot send to the group", async () => {
  const db = await withGroup();
  const deps = { db, bucket: {} };
  const msg = (n) => ({ conversationId: "admin_internal_group", messageId: `msg_admin_${n}0000`, text: "مرحبا" });

  await writeUser(db, "a1", { ...db.store.get("users/a1"), isActive: false });
  await rejectsWith(sendChatMessageCore(deps, "a1", msg(1)), "permission-denied");

  await writeUser(db, "a2", { ...db.store.get("users/a2"), role: "teacher" });
  await rejectsWith(sendChatMessageCore(deps, "a2", msg(2)), "permission-denied");
  await rejectsWith(sendChatMessageCore(deps, "t1", msg(3)), "permission-denied");
});

// ── Source contracts ────────────────────────────────────────────────────────

const src = (rel) => readFileSync(join(here, "..", "src", rel), "utf8");

test("index exports both entrypoints; the callable is gated, the trigger never throws on a closed gate", () => {
  const index = src("index.ts");
  assert.match(index, /ensureAdminGroupConversation,\s*\n\s*syncAdminGroupOnUserWrite,\s*\n\} from "\.\/chat\/adminGroupFunctions";/);
  const file = src("chat/adminGroupFunctions.ts");
  assert.equal(file.split("onCall(").length - 1, 1);
  assert.match(file, /assertBackendAllowed\("ensureAdminGroupConversation"\)/);
  const trigger = file.slice(file.indexOf("export const syncAdminGroupOnUserWrite"));
  assert.doesNotMatch(trigger, /assertBackendAllowed\(/);
  assert.match(trigger, /isProductionBackendEnabled\(\) && !isEmulatorBackendAllowed\(\)/);
  assert.match(file, /region: "europe-west1"/);
});

test("rules keep conversations backend-created and readable only by participants or an active Admin", () => {
  const rules = readFileSync(join(here, "..", "..", "firestore.rules"), "utf8");
  const block = rules.slice(rules.indexOf("match /conversations/{conversationId}"));
  assert.match(block, /return hasActiveProfile\(\)\s*&& uid\(\) in resource\.data\.participantIds;/);
  assert.match(block, /allow read: if canAccessConversation\(\);/);
  assert.match(block, /allow create: if false;/);
  assert.match(block, /allow update: if isConversationParticipant\(\) && onlyResetsOwnUnreadCount\(\);/);
  assert.match(block, /allow delete: if false;/);
});

test("custom-group callables cannot edit the admin group", () => {
  const file = src("chat/chatGroupFunctions.ts");
  assert.match(file, /custom_group/);
  assert.doesNotMatch(file, /admin_group|admin_internal_group/);
});
