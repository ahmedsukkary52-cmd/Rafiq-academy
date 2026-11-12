/**
 * B14 — halaqa meeting link: URL policy, setHalaqaMeetingLink authority and
 * adminCreateHalaqa compatibility (no emulator; in-memory Firestore double).
 *
 * Run: cd functions && npx tsc && node --test test/meeting_link_policy.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
const link = require("../lib/halaqa/meetingLinkFunctions.js");
const schedule = require("../lib/halaqa/halaqaScheduleFunctions.js");
const { FieldValue } = require("firebase-admin/firestore");

const VALID = "https://meet.example.test/room-abc";
const VALID_2 = "https://video.example.org/j/room?pwd=x";

/** In-memory Firestore double: docs, equality / array-contains-any queries, transactions. */
function fakeDb(seed) {
  const store = new Map();
  for (const [col, docs] of Object.entries(seed)) {
    for (const [id, data] of Object.entries(docs)) store.set(`${col}/${id}`, structuredClone(data));
  }
  let auto = 0;
  const writes = [];

  const docRef = (col, id) => ({
    id,
    path: `${col}/${id}`,
    async get() {
      const data = store.get(`${col}/${id}`);
      return { id, exists: data !== undefined, data: () => data };
    },
  });
  const query = (col, filters) => ({
    where(field, op, value) {
      return query(col, [...filters, { field, op, value }]);
    },
    run() {
      const docs = [];
      for (const [path, data] of store) {
        const [c, id] = path.split("/");
        if (c !== col) continue;
        const ok = filters.every(({ field, op, value }) =>
          op === "=="
            ? data[field] === value
            : op === "array-contains-any"
              ? Array.isArray(data[field]) && data[field].some((v) => value.includes(v))
              : false,
        );
        if (ok) docs.push({ id, exists: true, data: () => data });
      }
      return { docs };
    },
  });

  return {
    store,
    writes,
    collection(col) {
      return {
        doc(id) {
          return docRef(col, id ?? `auto${++auto}`);
        },
        where(field, op, value) {
          return query(col, [{ field, op, value }]);
        },
        select() {
          return { get: async () => query(col, []).run() };
        },
      };
    },
    async runTransaction(fn) {
      const pending = [];
      const tx = {
        async get(target) {
          return typeof target.run === "function" ? target.run() : target.get();
        },
        async getAll(...refs) {
          return Promise.all(refs.map((ref) => ref.get()));
        },
        create(ref, data) {
          pending.push(["create", ref.path, data]);
        },
        update(ref, data) {
          pending.push(["update", ref.path, data]);
        },
        set(ref, data, opts) {
          pending.push([opts?.merge ? "merge" : "set", ref.path, data]);
        },
        delete(ref) {
          pending.push(["delete", ref.path, undefined]);
        },
      };
      let wrote = false;
      const result = await fn({
        ...tx,
        async get(target) {
          if (wrote) throw new Error("transaction read after write");
          return tx.get(target);
        },
        async getAll(...refs) {
          if (wrote) throw new Error("transaction read after write");
          return tx.getAll(...refs);
        },
        create: (...a) => ((wrote = true), tx.create(...a)),
        update: (...a) => ((wrote = true), tx.update(...a)),
        set: (...a) => ((wrote = true), tx.set(...a)),
        delete: (...a) => ((wrote = true), tx.delete(...a)),
      });
      for (const [kind, path, data] of pending) {
        const before = store.get(path);
        if (kind === "update" && before === undefined) throw new Error(`update missing ${path}`);
        if (kind === "create" && before !== undefined) throw new Error(`create exists ${path}`);
        if (kind === "delete") store.delete(path);
        else if (kind === "update" || kind === "merge") {
          const merged = { ...(before ?? {}), ...data };
          for (const [key, value] of Object.entries(data)) {
            if (value?.isEqual?.(FieldValue.delete())) delete merged[key];
          }
          store.set(path, merged);
        } else store.set(path, data);
        writes.push({ kind, path, data });
      }
      return result;
    },
  };
}

function dataset() {
  return {
    users: {
      admin1: { role: "admin", isActive: true },
      inactiveAdmin: { role: "admin", isActive: false },
      sup1: { role: "supervisor", isActive: true },
      sup2: { role: "supervisor", isActive: true },
      teacher1: { role: "teacher", isActive: true },
      student1: { role: "student", isActive: true },
      parent1: { role: "parent", isActive: true },
    },
    halaqat: {
      h1: {
        name: "حلقة الفجر",
        teacherId: "teacher1",
        supervisorId: "sup1",
        studentIds: ["student1"],
        schedule: [{ slotId: "s1", day: "السبت", startTime: "16:00", endTime: "17:00" }],
        meetingLink: "",
        status: "active",
        createdBy: "admin1",
      },
      h2: {
        name: "حلقة العصر",
        teacherId: "teacher1",
        supervisorId: "sup2",
        studentIds: [],
        schedule: [],
        meetingLink: VALID,
        status: "active",
        createdBy: "admin1",
      },
    },
    halaqaMeetingLinks: {
      h2: { meetingLink: VALID, updatedAt: "seeded" },
    },
  };
}

/** Dataset with h2's canonical doc replaced (or removed when [doc] is undefined). */
function datasetWith(h2Legacy, doc) {
  const d = dataset();
  d.halaqat.h2.meetingLink = h2Legacy;
  if (doc === undefined) delete d.halaqaMeetingLinks.h2;
  else d.halaqaMeetingLinks.h2 = doc;
  return d;
}

const call = (db, uid, data) => link.setHalaqaMeetingLinkCore(db, uid, data);
const auditWrites = (db) => db.writes.filter((w) => w.path.startsWith("auditLogs/"));
const canonical = (db, id) => db.store.get(`halaqaMeetingLinks/${id}`);
const legacy = (db, id) => db.store.get(`halaqat/${id}`).meetingLink;
const hasLegacyKey = (db, id) => Object.prototype.hasOwnProperty.call(db.store.get(`halaqat/${id}`), "meetingLink");

/** Canonical doc holds exactly { meetingLink, updatedAt }; the halaqa carries no copy. */
function assertLinked(db, id, value) {
  const doc = canonical(db, id);
  assert.ok(doc, `canonical doc for ${id}`);
  assert.deepEqual(Object.keys(doc).sort(), ["meetingLink", "updatedAt"]);
  assert.equal(doc.meetingLink, value);
  assert.ok(doc.updatedAt?.isEqual?.(FieldValue.serverTimestamp()), "updatedAt is server-generated");
  assert.equal(hasLegacyKey(db, id), false, `halaqat/${id} carries no meetingLink`);
}

/** The seeded h2 state (canonical doc and legacy field) was not rewritten. */
function assertSeededH2Untouched(db) {
  assert.deepEqual(canonical(db, "h2"), { meetingLink: VALID, updatedAt: "seeded" });
  assert.equal(legacy(db, "h2"), VALID);
}

function assertUnlinked(db, id) {
  assert.equal(canonical(db, id), undefined, `no canonical doc for ${id}`);
  assert.equal(hasLegacyKey(db, id), false, `halaqat/${id} carries no meetingLink`);
}

/** No write to a halaqa document ever stores a link value (J.9). */
function assertNoHalaqaLinkWrites(db) {
  for (const w of db.writes.filter((x) => x.path.startsWith("halaqat/"))) {
    if (!w.data || !Object.prototype.hasOwnProperty.call(w.data, "meetingLink")) continue;
    assert.ok(w.data.meetingLink?.isEqual?.(FieldValue.delete()), `${w.kind} ${w.path} stores a meetingLink value`);
  }
}

async function rejectsWith(promise, code, reason) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code);
    if (reason) assert.equal(e.details?.reason, reason);
    return true;
  });
}

// ── URL policy ─────────────────────────────────────────────────────

test("policy accepts plain HTTPS links from any provider, including digit hosts and ports", () => {
  for (const ok of [
    VALID,
    VALID_2,
    "HTTPS://Meet.Example.test/Room",
    "https://meet.example.test",
    "https://meet.example.test:8443/a#b",
    "https://us02web.example.test/j/83012345678",
    "https://01012345678.example.test/room",
    "  https://meet.example.test/room  ",
  ]) {
    assert.equal(link.meetingLinkIssue(ok), null, ok);
  }
  assert.equal(link.validateMeetingLink("  https://meet.example.test/x "), "https://meet.example.test/x");
});

test("policy rejects malformed, non-HTTPS, credential, whitespace and over-long links", () => {
  const cases = [
    ["", "empty"],
    ["   ", "empty"],
    [null, "malformed"],
    [42, "malformed"],
    ["meet.example.test/room", "not_https"],
    ["http://meet.example.test/room", "not_https"],
    ["javascript:alert(1)", "not_https"],
    ["ftp://meet.example.test", "not_https"],
    ["https:meet.example.test", "not_https"],
    ["https:///meet.example.test", "invalid_host"],
    ["https://user:pass@meet.example.test/room", "credentials"],
    ["https://user@meet.example.test/room", "credentials"],
    ["https://meet.example.test/ro om", "whitespace"],
    ["https://meet.example.test/room\n", null],
    ["https://meet.example.test/\troom", "whitespace"],
    ["https://meet.example.test/\u0000room", "whitespace"],
    ["https://meet.example.test/\u202eroom", "whitespace"],
    ["https://meet.example.test/غرفة", "unsupported_characters"],
    ["https://localhost/room", "invalid_host"],
    ["https://-bad.example.test", "invalid_host"],
    ["https://meet..example.test", "invalid_host"],
    ["https://meet.example.test:99999", "invalid_host"],
    ["https://[::1]/room", "invalid_host"],
    ["https://meet.example.test\\@evil.test", "malformed"],
    [`https://meet.example.test/${"a".repeat(480)}`, "too_long"],
    ["https://wa.me/201012345678", "contact_info"],
    ["https://meet.example.test/call/01012345678", "contact_info"],
  ];
  for (const [raw, reason] of cases) {
    assert.equal(link.meetingLinkIssue(raw), reason, String(raw));
  }
  assert.equal(link.MAX_MEETING_LINK_LENGTH, 500);
});

test("validation errors carry a safe message and reason, never the link", () => {
  const secret = "https://user:hunter2@meet.example.test/private-room";
  try {
    link.validateMeetingLink(secret);
    assert.fail("expected rejection");
  } catch (e) {
    assert.equal(e.code, "invalid-argument");
    assert.deepEqual(e.details, { code: "meeting_link_invalid", reason: "credentials" });
    assert.ok(!e.message.includes("hunter2") && !e.message.includes("private-room"));
  }
});

// ── setHalaqaMeetingLink: admin ────────────────────────────────────

test("admin sets, updates and explicitly clears a link; each change is audited once", async () => {
  const db = fakeDb(dataset());
  assert.deepEqual(await call(db, "admin1", { halaqaId: "h1", meetingLink: VALID }), {
    halaqaId: "h1",
    operation: "set",
  });
  assertLinked(db, "h1", VALID);

  assert.equal((await call(db, "admin1", { halaqaId: "h1", meetingLink: VALID_2 })).operation, "update");
  assertLinked(db, "h1", VALID_2);

  assert.equal((await call(db, "admin1", { halaqaId: "h1", clear: true })).operation, "clear");
  assertUnlinked(db, "h1");
  const deletes = db.writes.filter((w) => w.kind === "delete");
  assert.deepEqual(deletes.map((w) => w.path), ["halaqaMeetingLinks/h1"]);

  const audits = auditWrites(db);
  assert.equal(audits.length, 3);
  assert.deepEqual(
    audits.map((a) => a.data.metadata.operation),
    ["meeting_link_set", "meeting_link_update", "meeting_link_clear"],
  );
  for (const a of audits) {
    assert.equal(a.data.action, "halaqa_meeting_link_change");
    assert.equal(a.data.actorRole, "admin");
    assert.equal(a.data.targetId, "h1");
    assert.equal(a.data.source, "setHalaqaMeetingLink");
  }
  assertNoHalaqaLinkWrites(db);
});

test("set/update writes the canonical doc and removes a legacy copy in one transaction", async () => {
  const db = fakeDb(dataset());
  await call(db, "admin1", { halaqaId: "h2", meetingLink: ` ${VALID_2} ` });
  assertLinked(db, "h2", VALID_2);
  const nonAudit = db.writes.filter((w) => !w.path.startsWith("auditLogs/"));
  assert.deepEqual(
    nonAudit.map((w) => [w.kind, w.path]),
    [["set", "halaqaMeetingLinks/h2"], ["update", "halaqat/h2"]],
  );
  assertNoHalaqaLinkWrites(db);
});

test("a halaqa without a legacy copy is never written by a link change", async () => {
  const d = dataset();
  delete d.halaqat.h1.meetingLink;
  const db = fakeDb(d);
  assert.equal((await call(db, "admin1", { halaqaId: "h1", meetingLink: VALID })).operation, "set");
  assert.equal((await call(db, "admin1", { halaqaId: "h1", meetingLink: VALID_2 })).operation, "update");
  assert.equal((await call(db, "admin1", { halaqaId: "h1", clear: true })).operation, "clear");
  assert.deepEqual(db.writes.filter((w) => w.path.startsWith("halaqat/")), []);
  assertUnlinked(db, "h1");
});

test("re-sending the same link or clearing an empty link writes nothing", async () => {
  const db = fakeDb(dataset());
  assert.equal((await call(db, "admin1", { halaqaId: "h2", meetingLink: VALID })).operation, "unchanged");
  assert.equal((await call(db, "admin1", { halaqaId: "h2", meetingLink: `  ${VALID}` })).operation, "unchanged");
  assert.equal((await call(db, "admin1", { halaqaId: "h1", clear: true })).operation, "unchanged");
  assert.equal((await call(db, "sup1", { halaqaId: "h1", clear: true })).operation, "unchanged");
  assert.equal(db.writes.length, 0);
});

// ── compatibility: canonical doc vs legacy field ───────────────────

test("legacy-only link (before migration): same link backfills the canonical doc, audited once", async () => {
  const db = fakeDb(datasetWith(VALID, undefined));
  assert.equal((await call(db, "admin1", { halaqaId: "h2", meetingLink: VALID })).operation, "update");
  assertLinked(db, "h2", VALID);
  assert.equal(auditWrites(db).length, 1);
});

test("legacy-only link: admin update and clear remove the legacy copy", async () => {
  const db = fakeDb(datasetWith(VALID, undefined));
  assert.equal((await call(db, "admin1", { halaqaId: "h2", meetingLink: VALID_2 })).operation, "update");
  assertLinked(db, "h2", VALID_2);

  const db2 = fakeDb(datasetWith(VALID, undefined));
  assert.equal((await call(db2, "admin1", { halaqaId: "h2", clear: true })).operation, "clear");
  assertUnlinked(db2, "h2");
  assert.equal(auditWrites(db2)[0].data.metadata.operation, "meeting_link_clear");
});

test("canonical equals the request: unchanged and no writes, whatever the legacy copy holds", async () => {
  for (const staleLegacy of ["", VALID_2, null, 7]) {
    const db = fakeDb(datasetWith(staleLegacy, { meetingLink: VALID, updatedAt: "seeded" }));
    assert.equal((await call(db, "admin1", { halaqaId: "h2", meetingLink: VALID })).operation, "unchanged");
    assert.equal(db.writes.length, 0, String(staleLegacy));
    assert.equal(legacy(db, "h2"), staleLegacy, "the copy is left for the strip step");
  }
});

test("stores disagree and the request equals the legacy value: canonical becomes the request, copy removed", async () => {
  const db = fakeDb(datasetWith(VALID_2, { meetingLink: VALID, updatedAt: "seeded" }));
  assert.equal((await call(db, "admin1", { halaqaId: "h2", meetingLink: VALID_2 })).operation, "update");
  assertLinked(db, "h2", VALID_2);
  assert.equal(auditWrites(db).length, 1);
});

test("canonical doc wins over a stale legacy link when clearing", async () => {
  const db = fakeDb(datasetWith("", { meetingLink: VALID, updatedAt: "seeded" }));
  assert.equal((await call(db, "admin1", { halaqaId: "h2", clear: true })).operation, "clear");
  assertUnlinked(db, "h2");
});

test("empty or non-string canonical values: admin may repair or clear, supervisor is denied", async () => {
  for (const bad of ["", "   ", null, 42, { url: VALID }]) {
    const docValue = { meetingLink: bad, updatedAt: "seeded" };

    const sup = fakeDb(datasetWith("", docValue));
    sup.store.get("halaqat/h2").supervisorId = "sup1";
    await rejectsWith(call(sup, "sup1", { halaqaId: "h2", meetingLink: VALID }), "permission-denied");
    await rejectsWith(call(sup, "sup1", { halaqaId: "h2", clear: true }), "permission-denied");
    assert.equal(sup.writes.length, 0);

    const repair = fakeDb(datasetWith("", docValue));
    assert.equal((await call(repair, "admin1", { halaqaId: "h2", meetingLink: VALID })).operation, "update");
    assertLinked(repair, "h2", VALID);

    const clear = fakeDb(datasetWith("", docValue));
    assert.equal((await call(clear, "admin1", { halaqaId: "h2", clear: true })).operation, "clear");
    assertUnlinked(clear, "h2");
    assert.equal(auditWrites(clear).length, 1);
  }
});

test("missing halaqa with a stray canonical doc: no writes for admin or supervisor", async () => {
  const d = dataset();
  d.halaqaMeetingLinks.ghostHalaqa = { meetingLink: VALID, updatedAt: "seeded" };
  const db = fakeDb(d);
  await rejectsWith(call(db, "admin1", { halaqaId: "ghostHalaqa", meetingLink: VALID_2 }), "not-found");
  await rejectsWith(call(db, "admin1", { halaqaId: "ghostHalaqa", clear: true }), "not-found");
  await rejectsWith(call(db, "sup1", { halaqaId: "ghostHalaqa", meetingLink: VALID_2 }), "permission-denied");
  assert.equal(db.writes.length, 0);
  assert.equal(canonical(db, "ghostHalaqa").meetingLink, VALID);
});

test("classifyMeetingLinkChange covers every stored state", () => {
  const s = (canonicalExists, canonicalValue, legacyValue, legacyPresent = legacyValue !== "") => ({
    canonicalExists,
    canonical: canonicalValue,
    legacy: legacyValue,
    legacyPresent,
  });
  const set = { clear: false, link: VALID };
  const clear = { clear: true, link: "" };
  const cases = [
    [s(false, "", ""), set, "set"],
    [s(false, "", ""), clear, "unchanged"],
    [s(false, "", VALID), set, "update"],
    [s(false, "", VALID_2), set, "update"],
    [s(false, "", VALID), clear, "clear"],
    [s(true, VALID, VALID), set, "unchanged"],
    [s(true, VALID, ""), set, "unchanged"],
    [s(true, VALID, VALID_2), set, "unchanged"],
    [s(true, VALID_2, VALID), set, "update"],
    [s(true, "", ""), set, "update"],
    [s(true, "", ""), clear, "clear"],
    [s(true, VALID, VALID), clear, "clear"],
  ];
  for (const [stored, request, expected] of cases) {
    assert.equal(link.classifyMeetingLinkChange(stored, request), expected, JSON.stringify([stored, request]));
  }
  assert.deepEqual(link.resolveStoredMeetingLink(undefined, { meetingLink: ` ${VALID} ` }), s(false, "", VALID));
  assert.deepEqual(link.resolveStoredMeetingLink({ meetingLink: 5 }, { meetingLink: VALID }), s(true, "", VALID));
  assert.deepEqual(link.resolveStoredMeetingLink({ meetingLink: ` ${VALID_2}` }, {}), s(true, VALID_2, ""));
  assert.deepEqual(link.resolveStoredMeetingLink(undefined, { meetingLink: "" }), s(false, "", "", true));
  assert.deepEqual(link.resolveStoredMeetingLink(undefined, { meetingLink: 7 }), s(false, "", "", true));
});

test("only meetingLink and updatedAt change; other halaqa fields are preserved", async () => {
  const db = fakeDb(dataset());
  const before = structuredClone(db.store.get("halaqat/h1"));
  await call(db, "admin1", { halaqaId: "h1", meetingLink: VALID });
  const halaqaWrites = db.writes.filter((w) => w.path === "halaqat/h1");
  assert.equal(halaqaWrites.length, 1);
  assert.equal(halaqaWrites[0].kind, "update");
  assert.deepEqual(Object.keys(halaqaWrites[0].data).sort(), ["meetingLink", "updatedAt"]);
  assert.ok(halaqaWrites[0].data.meetingLink.isEqual(FieldValue.delete()), "the legacy key is deleted, not rewritten");
  const after = db.store.get("halaqat/h1");
  for (const key of ["name", "teacherId", "supervisorId", "studentIds", "schedule", "status", "createdBy"]) {
    assert.deepEqual(after[key], before[key], key);
  }
});

test("omitting the link is rejected instead of clearing it", async () => {
  const db = fakeDb(dataset());
  await rejectsWith(call(db, "admin1", { halaqaId: "h2" }), "invalid-argument", "malformed");
  await rejectsWith(call(db, "admin1", { halaqaId: "h2", meetingLink: "" }), "invalid-argument", "empty");
  await rejectsWith(call(db, "admin1", { halaqaId: "h2", clear: "yes" }), "invalid-argument");
  await rejectsWith(
    call(db, "admin1", { halaqaId: "h2", clear: true, meetingLink: VALID_2 }),
    "invalid-argument",
  );
  assertSeededH2Untouched(db);
  assert.equal(db.writes.length, 0);
});

test("invalid links are rejected before any write", async () => {
  const db = fakeDb(dataset());
  for (const [bad, reason] of [
    ["not a url", "whitespace"],
    ["http://meet.example.test/room", "not_https"],
    ["https://user:pw@meet.example.test", "credentials"],
    ["https://meet.example.test/\u0007", "whitespace"],
    [`https://meet.example.test/${"x".repeat(500)}`, "too_long"],
  ]) {
    await rejectsWith(call(db, "admin1", { halaqaId: "h1", meetingLink: bad }), "invalid-argument", reason);
  }
  assert.equal(db.writes.length, 0);
});

test("missing halaqa and unsafe ids are handled without writes", async () => {
  const db = fakeDb(dataset());
  await rejectsWith(call(db, "admin1", { halaqaId: "nope", meetingLink: VALID }), "not-found");
  await rejectsWith(call(db, "sup1", { halaqaId: "nope", meetingLink: VALID }), "permission-denied");
  for (const halaqaId of ["halaqat/h1", ".", "..", "__h1__"]) {
    await rejectsWith(call(db, "admin1", { halaqaId, meetingLink: VALID }), "invalid-argument");
  }
  await rejectsWith(call(db, "admin1", { meetingLink: VALID }), "invalid-argument");
  assert.equal(db.writes.length, 0);
});

// ── setHalaqaMeetingLink: supervisors and other roles ─────────────

test("assigned supervisor may add a link only while none is stored", async () => {
  const db = fakeDb(dataset());
  db.store.get("halaqat/h2").supervisorId = "sup1";

  assert.equal((await call(db, "sup1", { halaqaId: "h1", meetingLink: VALID })).operation, "set");
  assertLinked(db, "h1", VALID);
  const audit = auditWrites(db)[0].data;
  assert.equal(audit.actorRole, "supervisor");
  assert.equal(audit.actorId, "sup1");

  assert.equal((await call(db, "sup1", { halaqaId: "h1", meetingLink: VALID })).operation, "unchanged");
  await rejectsWith(call(db, "sup1", { halaqaId: "h1", meetingLink: VALID_2 }), "permission-denied");
  await rejectsWith(call(db, "sup1", { halaqaId: "h1", clear: true }), "permission-denied");
  await rejectsWith(call(db, "sup1", { halaqaId: "h2", clear: true }), "permission-denied");
  assertLinked(db, "h1", VALID);
  assertSeededH2Untouched(db);
  assert.equal(auditWrites(db).length, 1);
});

test("supervisor add is denied when either store already holds a link", async () => {
  for (const [legacyValue, doc] of [
    [VALID, undefined],
    ["", { meetingLink: VALID, updatedAt: "seeded" }],
    [VALID_2, { meetingLink: VALID, updatedAt: "seeded" }],
  ]) {
    const db = fakeDb(datasetWith(legacyValue, doc));
    db.store.get("halaqat/h2").supervisorId = "sup1";
    await rejectsWith(call(db, "sup1", { halaqaId: "h2", meetingLink: VALID_2 }), "permission-denied");
    await rejectsWith(call(db, "sup1", { halaqaId: "h2", clear: true }), "permission-denied");
    assert.equal(db.writes.length, 0);
  }
});

test("supervisor of another halaqa is denied", async () => {
  const db = fakeDb(dataset());
  await rejectsWith(call(db, "sup2", { halaqaId: "h1", meetingLink: VALID }), "permission-denied");
  assert.equal(db.writes.length, 0);
});

test("students, parents, teachers, inactive admins and signed-out callers cannot set, update or clear", async () => {
  const db = fakeDb(dataset());
  for (const uid of ["student1", "parent1", "teacher1", "inactiveAdmin", "ghost"]) {
    await rejectsWith(call(db, uid, { halaqaId: "h1", meetingLink: VALID }), "permission-denied");
    await rejectsWith(call(db, uid, { halaqaId: "h2", meetingLink: VALID_2 }), "permission-denied");
    await rejectsWith(call(db, uid, { halaqaId: "h2", clear: true }), "permission-denied");
  }
  await rejectsWith(call(db, undefined, { halaqaId: "h1", meetingLink: VALID }), "unauthenticated");
  assert.equal(db.writes.length, 0);
  assertSeededH2Untouched(db);
});

test("request-supplied role or supervisor claims are ignored", async () => {
  const db = fakeDb(dataset());
  await rejectsWith(
    call(db, "student1", { halaqaId: "h1", meetingLink: VALID, role: "admin", supervisorId: "student1" }),
    "permission-denied",
  );
  assert.equal(db.writes.length, 0);
});

test("audit records and every write outside the two link stores carry no link value", async () => {
  const db = fakeDb(dataset());
  await call(db, "admin1", { halaqaId: "h1", meetingLink: VALID });
  await call(db, "admin1", { halaqaId: "h1", meetingLink: VALID_2 });
  await call(db, "admin1", { halaqaId: "h1", clear: true });
  const linkStores = (p) => p.startsWith("halaqat/") || p.startsWith("halaqaMeetingLinks/");
  assert.equal(auditWrites(db).length, 3);
  for (const w of db.writes.filter((x) => !linkStores(x.path))) {
    const json = JSON.stringify(w.data);
    assert.ok(!json.includes("meet.example") && !json.includes("video.example"), w.path);
    assert.ok(!json.includes("https://"), w.path);
  }
});

test("callable errors never echo the stored or requested link", async () => {
  const db = fakeDb(datasetWith(VALID, { meetingLink: VALID, updatedAt: "seeded" }));
  db.store.get("halaqat/h2").supervisorId = "sup1";
  const attempts = [
    call(db, "sup1", { halaqaId: "h2", meetingLink: VALID_2 }),
    call(db, "sup1", { halaqaId: "h2", clear: true }),
    call(db, "sup2", { halaqaId: "h1", meetingLink: VALID_2 }),
    call(db, "parent1", { halaqaId: "h2", meetingLink: VALID_2 }),
    call(db, "admin1", { halaqaId: "nope", meetingLink: VALID_2 }),
    call(db, "admin1", { halaqaId: "h2", meetingLink: "https://user:pw@video.example.org/x" }),
  ];
  for (const attempt of attempts) {
    await assert.rejects(attempt, (e) => {
      const blob = `${e.message} ${JSON.stringify(e.details ?? null)}`;
      assert.ok(!blob.includes("example"), blob);
      assert.ok(!blob.includes("https://"), blob);
      return true;
    });
  }
  assert.equal(db.writes.length, 0);
});

// ── direct-write bypass and create compatibility ──────────────────

test("firestore.rules freeze meetingLink for client halaqa updates", () => {
  const rules = readFileSync(join(repoRoot, "firestore.rules"), "utf8");
  const block = rules.slice(rules.indexOf("match /halaqat/{halaqaId}"));
  const start = block.indexOf("allow update");
  const update = block.slice(start, block.indexOf("}", start));
  assert.match(update, /^allow update: if false;\s*$/);
  assert.match(block, /allow create: if false;/);
});

function createPayload(extra = {}) {
  return {
    name: "حلقة جديدة",
    teacherId: "teacher1",
    schedule: [{ day: "الأحد", startTime: "18:00", endTime: "19:00" }],
    requestId: "req_meeting_link_01",
    ...extra,
  };
}

test("adminCreateHalaqa stores a valid link, stores empty when omitted, and rejects invalid links", async () => {
  let n = 0;
  const ids = () => `slot${++n}`;

  const withLink = fakeDb(dataset());
  const created = await schedule.adminCreateHalaqaCore(withLink, "admin1", createPayload({ meetingLink: ` ${VALID} ` }), ids);
  assert.equal(created.alreadyExisted, false);
  assertLinked(withLink, created.halaqaId, VALID);

  const without = fakeDb(dataset());
  const plain = await schedule.adminCreateHalaqaCore(without, "admin1", createPayload(), ids);
  assertUnlinked(without, plain.halaqaId);

  const blank = fakeDb(dataset());
  const b = await schedule.adminCreateHalaqaCore(blank, "admin1", createPayload({ meetingLink: "   " }), ids);
  assertUnlinked(blank, b.halaqaId);
  for (const db of [withLink, without, blank]) assertNoHalaqaLinkWrites(db);

  for (const [bad, reason] of [
    ["http://meet.example.test/room", "not_https"],
    ["meet.example.test/room", "not_https"],
    ["https://user:pw@meet.example.test", "credentials"],
  ]) {
    const db = fakeDb(dataset());
    await rejectsWith(
      schedule.adminCreateHalaqaCore(db, "admin1", createPayload({ meetingLink: bad }), ids),
      "invalid-argument",
      reason,
    );
    assert.equal(db.writes.length, 0);
  }
});

test("adminCreateHalaqa removes a stray canonical doc when no link is given and overwrites it otherwise", async () => {
  const id = createPayload().requestId;
  const stray = { meetingLink: VALID_2, updatedAt: "seeded", extra: "x" };

  const withoutLink = fakeDb({ ...dataset(), halaqaMeetingLinks: { [id]: { ...stray } } });
  await schedule.adminCreateHalaqaCore(withoutLink, "admin1", createPayload(), () => "slotA");
  assertUnlinked(withoutLink, id);

  const withLink = fakeDb({ ...dataset(), halaqaMeetingLinks: { [id]: { ...stray } } });
  await schedule.adminCreateHalaqaCore(withLink, "admin1", createPayload({ meetingLink: VALID }), () => "slotB");
  assertLinked(withLink, id, VALID);
});

test("adminCreateHalaqa request-id replay writes nothing and leaves the link stores alone", async () => {
  const db = fakeDb(dataset());
  const first = await schedule.adminCreateHalaqaCore(db, "admin1", createPayload({ meetingLink: VALID }), () => "slotR");
  const writesAfterFirst = db.writes.length;
  const replay = await schedule.adminCreateHalaqaCore(
    db,
    "admin1",
    createPayload({ meetingLink: VALID_2 }),
    () => "slotR2",
  );
  assert.equal(replay.alreadyExisted, true);
  assert.equal(replay.halaqaId, first.halaqaId);
  assert.equal(db.writes.length, writesAfterFirst);
  assertLinked(db, first.halaqaId, VALID);
});

test("adminCreateHalaqa audit metadata carries no link", async () => {
  const db = fakeDb(dataset());
  await schedule.adminCreateHalaqaCore(db, "admin1", createPayload({ meetingLink: VALID }), () => "slotX");
  const audit = auditWrites(db);
  assert.equal(audit.length, 1);
  assert.ok(!JSON.stringify(audit[0].data).includes("https://"));
});
