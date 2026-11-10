/**
 * B14 — setHalaqaMeetingLink against the Firestore emulator (real
 * transaction semantics: supervisor add-only under races, the canonical
 * `halaqaMeetingLinks` doc is the only stored link, a legacy
 * `halaqat.meetingLink` copy is removed in the same transaction, atomic audit).
 * Never touches a real project.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 functions/test/meeting_link.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "B14 emulator suite requires FIRESTORE_EMULATOR_HOST and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const { setHalaqaMeetingLinkCore } = require("../lib/halaqa/meetingLinkFunctions.js");
const { adminCreateHalaqaCore } = require("../lib/halaqa/halaqaScheduleFunctions.js");

const ACTION = "halaqa_meeting_link_change";
const LINK_A = "https://meet.example.test/room-a";
const LINK_B = "https://video.example.org/j/room-b";
const LINK_C = "https://meet.example.test/room-c";

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

const user = (role, extra = {}) => ({ name: role, role, isActive: true, ...extra });

/**
 * `meetingLink` seeds the canonical doc; `legacy` (a string) additionally
 * seeds a pre-J.9 `halaqat.meetingLink` copy.
 */
async function seed(meetingLink = "", { legacy } = {}) {
  const batch = db.batch();
  const docs = {
    "users/admin1": user("admin"),
    "users/inactiveAdmin": user("admin", { isActive: false }),
    "users/sup1": user("supervisor"),
    "users/sup2": user("supervisor"),
    "users/teacher1": user("teacher"),
    "users/student1": user("student"),
    "halaqat/h1": {
      name: "حلقة الفجر",
      teacherId: "teacher1",
      supervisorId: "sup1",
      studentIds: ["student1"],
      schedule: [{ slotId: "s1", day: "saturday", startTime: "16:00", endTime: "17:00" }],
      ...(legacy === undefined ? {} : { meetingLink: legacy }),
      status: "active",
    },
  };
  if (meetingLink) {
    docs["halaqaMeetingLinks/h1"] = {
      meetingLink,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }
  for (const [path, data] of Object.entries(docs)) batch.set(db.doc(path), data);
  await batch.commit();
}

async function audits() {
  return (await db.collection("auditLogs").where("action", "==", ACTION).get()).docs.map(
    (d) => d.data(),
  );
}

async function hasLegacyKey(halaqaId = "h1") {
  return Object.hasOwn((await db.doc(`halaqat/${halaqaId}`).get()).data(), "meetingLink");
}

/** The canonical link (`""` when none); throws if the halaqa carries a legacy copy. */
async function storedLink(halaqaId = "h1") {
  assert.equal(await hasLegacyKey(halaqaId), false, "the halaqa must not carry a meetingLink");
  const doc = await db.doc(`halaqaMeetingLinks/${halaqaId}`).get();
  if (!doc.exists) return "";
  const data = doc.data();
  assert.deepEqual(Object.keys(data).sort(), ["meetingLink", "updatedAt"]);
  assert.ok(data.updatedAt instanceof admin.firestore.Timestamp, "updatedAt is a server timestamp");
  return data.meetingLink;
}

async function canonicalExists(halaqaId = "h1") {
  return (await db.doc(`halaqaMeetingLinks/${halaqaId}`).get()).exists;
}

async function assertNoLinkInAudits() {
  const all = (await db.collection("auditLogs").get()).docs.map((d) => JSON.stringify(d.data()));
  for (const entry of all) {
    for (const link of [LINK_A, LINK_B, LINK_C, "https://"]) {
      assert.equal(entry.includes(link), false, "audit entry carries a link value");
    }
  }
}

async function expectCode(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `expected ${code}, got ${err.code}`);
    return true;
  });
}

const call = (uid, data) => setHalaqaMeetingLinkCore(db, uid, data);

test.beforeEach(async () => {
  await clearFirestore();
});

test("concurrent supervisor adds: exactly one link wins, one audit, loser denied", async () => {
  for (let round = 0; round < 5; round += 1) {
    await clearFirestore();
    await seed("");
    const requests = [LINK_A, LINK_B];
    const results = await Promise.allSettled(
      requests.map((meetingLink) => call("sup1", { halaqaId: "h1", meetingLink })),
    );

    const won = results.flatMap((r, i) => (r.status === "fulfilled" ? [i] : []));
    const lost = results.filter((r) => r.status === "rejected");
    assert.equal(won.length, 1, `round ${round}: exactly one request must succeed`);
    assert.equal(results[won[0]].value.operation, "set");
    assert.equal(lost.length, 1);
    assert.equal(lost[0].reason.code, "permission-denied");

    assert.equal(await storedLink(), requests[won[0]], "stored link is the winner's link");

    const entries = await audits();
    assert.equal(entries.length, 1, `round ${round}: one audit for one successful change`);
    assert.equal(entries[0].actorId, "sup1");
    assert.equal(entries[0].actorRole, "supervisor");
    assert.equal(entries[0].targetId, "h1");
    assert.deepEqual(entries[0].metadata, { halaqaId: "h1", operation: "meeting_link_set" });
    assert.equal((await db.collection("auditLogs").get()).size, 1, "no orphan audit records");
    await assertNoLinkInAudits();
  }
});

test("admin update racing a supervisor add: final link and audits match the successes", async () => {
  for (let round = 0; round < 5; round += 1) {
    await clearFirestore();
    await seed("");
    const results = await Promise.allSettled([
      call("admin1", { halaqaId: "h1", meetingLink: LINK_A }),
      call("sup1", { halaqaId: "h1", meetingLink: LINK_B }),
    ]);
    const [adminResult, supResult] = results;
    assert.equal(adminResult.status, "fulfilled", "admin may always set or update");

    const entries = await audits();
    if (supResult.status === "fulfilled") {
      // Supervisor committed first (set), admin then updated.
      assert.equal(supResult.value.operation, "set");
      assert.equal(adminResult.value.operation, "update");
      assert.equal(await storedLink(), LINK_A);
      assert.equal(entries.length, 2);
      assert.deepEqual(
        entries.map((e) => e.metadata.operation).sort(),
        ["meeting_link_set", "meeting_link_update"],
      );
    } else {
      // Admin committed first; the supervisor retry saw a link and was refused.
      assert.equal(supResult.reason.code, "permission-denied");
      assert.equal(adminResult.value.operation, "set");
      assert.equal(await storedLink(), LINK_A);
      assert.equal(entries.length, 1);
      assert.equal(entries[0].actorRole, "admin");
    }
    assert.equal((await db.collection("auditLogs").get()).size, entries.length);
    await assertNoLinkInAudits();
  }
});

test("admin set, update and explicit clear commit with one audit each", async () => {
  await seed("");
  assert.equal((await call("admin1", { halaqaId: "h1", meetingLink: LINK_A })).operation, "set");
  assert.equal((await call("admin1", { halaqaId: "h1", meetingLink: LINK_B })).operation, "update");
  assert.equal((await call("admin1", { halaqaId: "h1", meetingLink: LINK_B })).operation, "unchanged");
  assert.equal(await storedLink(), LINK_B);
  assert.equal((await call("admin1", { halaqaId: "h1", clear: true })).operation, "clear");
  assert.equal(await storedLink(), "");
  assert.equal(await canonicalExists(), false, "clear deletes the canonical doc");
  assert.deepEqual(
    (await audits()).map((e) => e.metadata.operation).sort(),
    ["meeting_link_clear", "meeting_link_set", "meeting_link_update"],
  );
  const h = (await db.doc("halaqat/h1").get()).data();
  assert.equal(h.name, "حلقة الفجر");
  assert.deepEqual(h.studentIds, ["student1"]);
  assert.equal(h.supervisorId, "sup1");
  await assertNoLinkInAudits();
});

test("supervisor cannot update or clear; other roles and halaqat are denied without writes", async () => {
  await seed(LINK_A);
  await expectCode(call("sup1", { halaqaId: "h1", meetingLink: LINK_C }), "permission-denied");
  await expectCode(call("sup1", { halaqaId: "h1", clear: true }), "permission-denied");
  await expectCode(call("sup2", { halaqaId: "h1", meetingLink: LINK_C }), "permission-denied");
  for (const uid of ["teacher1", "student1", "inactiveAdmin", "nobody"]) {
    await expectCode(
      call(uid, { halaqaId: "h1", meetingLink: LINK_C }),
      "permission-denied",
    );
  }
  await expectCode(call(undefined, { halaqaId: "h1", meetingLink: LINK_C }), "unauthenticated");
  await expectCode(
    call("sup1", { halaqaId: "h1", meetingLink: LINK_C, role: "admin", supervisorId: "sup1" }),
    "permission-denied",
  );
  await expectCode(call("admin1", { halaqaId: "h1", meetingLink: "http://x.example.test" }), "invalid-argument");
  await expectCode(call("admin1", { halaqaId: "nope", meetingLink: LINK_C }), "not-found");
  assert.equal(await storedLink(), LINK_A);
  assert.equal((await db.collection("auditLogs").get()).size, 0);
});

test("legacy-era halaqa: a legacy-only copy blocks supervisor adds; admin changes remove the copy", async () => {
  await seed("", { legacy: LINK_A });
  const before = (await db.doc("halaqat/h1").get()).updateTime;
  await expectCode(call("sup1", { halaqaId: "h1", meetingLink: LINK_C }), "permission-denied");
  assert.ok((await db.doc("halaqat/h1").get()).updateTime.isEqual(before), "a denied add writes nothing");
  assert.equal(await canonicalExists(), false);
  assert.equal(await hasLegacyKey(), true);

  assert.equal((await call("admin1", { halaqaId: "h1", meetingLink: LINK_B })).operation, "update");
  assert.equal(await storedLink(), LINK_B, "canonical set, legacy copy removed in the same transaction");

  await clearFirestore();
  await seed(LINK_A, { legacy: LINK_A });
  assert.equal((await call("admin1", { halaqaId: "h1", clear: true })).operation, "clear");
  assert.equal(await storedLink(), "");

  await clearFirestore();
  await seed("", { legacy: "" });
  assert.equal((await call("sup1", { halaqaId: "h1", meetingLink: LINK_C })).operation, "set");
  assert.equal(await storedLink(), LINK_C, "an empty legacy key is removed by the supervisor's add");
  const h = (await db.doc("halaqat/h1").get()).data();
  assert.equal(h.name, "حلقة الفجر");
  assert.equal(h.supervisorId, "sup1");
  await assertNoLinkInAudits();
});

test("adminCreateHalaqa with a link writes only the canonical doc; requestId replay writes nothing", async () => {
  const batch = db.batch();
  batch.set(db.doc("users/admin1"), user("admin"));
  batch.set(db.doc("users/teacher1"), user("teacher"));
  batch.set(db.doc("users/sup1"), user("supervisor"));
  await batch.commit();

  const requestId = "b14CreateReq01";
  const payload = (meetingLink) => ({
    name: "حلقة العصر",
    teacherId: "teacher1",
    supervisorId: "sup1",
    schedule: [{ day: "السبت", startTime: "16:00", endTime: "17:00" }],
    meetingLink,
    requestId,
  });

  const first = await adminCreateHalaqaCore(db, "admin1", payload(` ${LINK_A} `), () => "slotC1");
  assert.equal(first.alreadyExisted, false);
  assert.equal(first.halaqaId, requestId);
  assert.deepEqual(first.slotIds, ["slotC1"]);

  const h = (await db.doc(`halaqat/${requestId}`).get()).data();
  assert.equal(h.name, "حلقة العصر");
  assert.equal(h.teacherId, "teacher1");
  assert.equal(h.supervisorId, "sup1");
  assert.deepEqual(h.studentIds, []);
  assert.equal(h.status, "active");
  assert.equal(await storedLink(requestId), LINK_A, "trimmed link stored only in the canonical doc");

  const creates = (await db.collection("auditLogs").where("action", "==", "halaqa_create").get()).docs;
  assert.equal(creates.length, 1);
  assert.equal(creates[0].data().targetId, requestId);
  assert.equal("meetingLink" in creates[0].data().metadata, false);
  assert.equal((await db.collection("auditLogs").get()).size, 1);
  await assertNoLinkInAudits();

  const halaqaBefore = await db.doc(`halaqat/${requestId}`).get();
  const linkBefore = await db.doc(`halaqaMeetingLinks/${requestId}`).get();

  const replay = await adminCreateHalaqaCore(db, "admin1", payload(LINK_B), () => "slotC2");
  assert.equal(replay.alreadyExisted, true);
  assert.equal(replay.halaqaId, requestId);
  assert.deepEqual(replay.slotIds, ["slotC1"]);

  const halaqaAfter = await db.doc(`halaqat/${requestId}`).get();
  const linkAfter = await db.doc(`halaqaMeetingLinks/${requestId}`).get();
  assert.ok(halaqaAfter.updateTime.isEqual(halaqaBefore.updateTime), "halaqa doc not rewritten");
  assert.ok(linkAfter.updateTime.isEqual(linkBefore.updateTime), "canonical doc not rewritten");
  assert.equal(await storedLink(requestId), LINK_A, "replay link ignored");
  assert.equal((await db.collection("auditLogs").get()).size, 1, "replay adds no audit");
  await assertNoLinkInAudits();
});
