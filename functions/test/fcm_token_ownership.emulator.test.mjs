/**
 * H2 — FCM token ownership (one active account per token) against the
 * Firestore emulator. Never touches a real project.
 *
 * Run from repo root (after `npm --prefix functions run build`) with the
 * isolated demo-rafiq-it emulators:
 *   npx firebase emulators:exec --config firebase.it.json --project demo-rafiq-it \
 *     --only firestore "node --test --test-concurrency=1 functions/test/fcm_token_ownership.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "FCM ownership suite requires FIRESTORE_EMULATOR_HOST and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const ownership = require("../lib/notifications/fcmTokenOwnership.js");
const evalFanOut = require("../lib/notifications/evaluationNotificationFunctions.js");

const TOKEN = "shared-device-token";

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

const devicePath = (uid, deviceId) => `fcmTokens/${uid}/devices/${deviceId}`;
const ownerPath = (token) =>
  `fcmTokenOwners/${ownership.tokenOwnerDocId(token)}`;

/** Client-shaped registration; each write gets a later server updateTime. */
async function register(uid, deviceId, token = TOKEN) {
  await db.doc(devicePath(uid, deviceId)).set(
    { token, platform: "android", disabled: false },
    { merge: true },
  );
}

async function data(path) {
  const snap = await db.doc(path).get();
  return snap.exists ? snap.data() : null;
}

const reconcile = (uid, deviceId, previousToken) =>
  ownership.reconcileDeviceTokenOwnership(db, { uid, deviceId, previousToken });

async function activeHolders(token = TOKEN) {
  const owner = await data(ownerPath(token));
  const holders = [];
  for (const [uid, deviceId] of [
    ["parentA", "dev1"],
    ["parentB", "dev1"],
    ["parentC", "dev1"],
  ]) {
    const doc = await data(devicePath(uid, deviceId));
    if (doc && doc.token === token && doc.disabled !== true &&
        ownership.deviceOwnsToken(owner, uid, deviceId)) {
      holders.push(uid);
    }
  }
  return holders;
}

test.beforeEach(clearFirestore);

test("owner record id is a hash; the token itself is never stored there", async () => {
  await register("parentA", "dev1");
  await reconcile("parentA", "dev1");
  const owner = await data(ownerPath(TOKEN));
  assert.deepEqual({ uid: owner.uid, deviceId: owner.deviceId }, { uid: "parentA", deviceId: "dev1" });
  assert.ok(!JSON.stringify(owner).includes(TOKEN));
  assert.match(ownership.tokenOwnerDocId(TOKEN), /^[0-9a-f]{64}$/);
});

test("transfer: a newer registration by another account disables the previous owner", async () => {
  await register("parentA", "dev1");
  assert.equal(await reconcile("parentA", "dev1"), "claimed");
  await register("parentB", "dev1");
  assert.equal(await reconcile("parentB", "dev1"), "claimed");

  const prev = await data(devicePath("parentA", "dev1"));
  assert.equal(prev.disabled, true);
  assert.equal(prev.disabledReason, ownership.TOKEN_TRANSFERRED_REASON);
  assert.equal((await data(ownerPath(TOKEN))).uid, "parentB");
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("duplicate registration / redelivered trigger is idempotent", async () => {
  await register("parentA", "dev1");
  await reconcile("parentA", "dev1");
  await register("parentA", "dev1");
  assert.equal(await reconcile("parentA", "dev1"), "unchanged");
  assert.equal(await reconcile("parentA", "dev1"), "unchanged");
  assert.equal((await data(devicePath("parentA", "dev1"))).disabled, false);
  assert.deepEqual(await activeHolders(), ["parentA"]);
});

test("account switching back and forth always leaves exactly the newest account", async () => {
  for (const uid of ["parentA", "parentB", "parentA", "parentC", "parentB"]) {
    await register(uid, "dev1");
    await reconcile(uid, "dev1");
    assert.deepEqual(await activeHolders(), [uid]);
  }
});

test("out-of-order trigger: a late older registration cannot take the token back", async () => {
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  // B's trigger runs first; A's (older) trigger arrives late.
  await reconcile("parentB", "dev1");
  assert.equal(await reconcile("parentA", "dev1"), "lost_to_newer");

  assert.equal((await data(devicePath("parentA", "dev1"))).disabled, true);
  assert.equal((await data(devicePath("parentB", "dev1"))).disabled, false);
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("concurrent registrations never leave two active owners", async () => {
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  await register("parentC", "dev1");
  await Promise.all([
    reconcile("parentA", "dev1"),
    reconcile("parentB", "dev1"),
    reconcile("parentC", "dev1"),
    reconcile("parentB", "dev1"),
  ]);
  // Re-run as the follow-up triggers on the disabled records would.
  for (const uid of ["parentA", "parentB", "parentC"]) {
    await reconcile(uid, "dev1", TOKEN);
  }
  assert.deepEqual(await activeHolders(), ["parentC"]);
});

test("stale owner record: a previous owner that moved to another token is left alone", async () => {
  await register("parentA", "dev1");
  await reconcile("parentA", "dev1");
  await register("parentA", "dev1", "parentA-new-token");
  await register("parentB", "dev1");
  await reconcile("parentB", "dev1");

  const a = await data(devicePath("parentA", "dev1"));
  assert.equal(a.disabled, false);
  assert.equal(a.token, "parentA-new-token");
  assert.equal((await data(ownerPath(TOKEN))).uid, "parentB");
});

function assertReleased(owner) {
  assert.ok(owner, "release keeps a tombstone");
  assert.equal(owner.uid, undefined);
  assert.equal(owner.deviceId, undefined);
  assert.ok(owner.releasedAt);
}

test("disable or token change by the owner releases the old token", async () => {
  await register("parentA", "dev1");
  await reconcile("parentA", "dev1");
  await db.doc(devicePath("parentA", "dev1")).set({ disabled: true }, { merge: true });
  assert.equal(await reconcile("parentA", "dev1", TOKEN), "released");
  assertReleased(await data(ownerPath(TOKEN)));

  await register("parentA", "dev1", "t2");
  await reconcile("parentA", "dev1");
  await register("parentA", "dev1", "t3");
  await reconcile("parentA", "dev1", "t2");
  assertReleased(await data(ownerPath("t2")));
  assert.equal((await data(ownerPath("t3"))).uid, "parentA");
});

test("re-registering a released token claims it again", async () => {
  await register("parentA", "dev1");
  await reconcile("parentA", "dev1");
  await db.doc(devicePath("parentA", "dev1")).set({ disabled: true }, { merge: true });
  await reconcile("parentA", "dev1", TOKEN);

  await register("parentB", "dev1");
  assert.equal(await reconcile("parentB", "dev1"), "claimed");
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("stale legacy record of a previous account stays unsendable after the " +
  "next owner releases the token", async () => {
  // parentA registered before the trigger existed: enabled, never reconciled.
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  await reconcile("parentB", "dev1");
  await db.doc(devicePath("parentB", "dev1")).set({ disabled: true }, { merge: true });
  assert.equal(await reconcile("parentB", "dev1", TOKEN), "released");

  assert.equal((await data(devicePath("parentA", "dev1"))).disabled, false);
  assert.deepEqual(await activeHolders(), []);
});

test("release by a non-owner never removes the real owner", async () => {
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  await reconcile("parentB", "dev1");
  await db.doc(devicePath("parentA", "dev1")).delete();
  assert.equal(await reconcile("parentA", "dev1", TOKEN), "ignored");
  assert.equal((await data(ownerPath(TOKEN))).uid, "parentB");
});

// ── Sender consults ownership ──────────────────────────────────────────────

const liveEvaluation = {
  studentId: "student1",
  halaqaId: "h1",
  teacherId: "teacher1",
  sessionId: "sess_x",
  type: "memorization",
  grade: "excellent-label",
  reviewStatus: "reviewed",
};

function fakeSender() {
  const calls = [];
  const sender = async ({ notification, tokens }) => {
    calls.push({ notification, tokens });
    return tokens.map((t) => ({ deviceId: t.deviceId, success: true }));
  };
  return { calls, sender };
}

test("sender skips a stale record whose token is owned by another account", async () => {
  await db.doc("parentProfiles/parentA").set({ uid: "parentA", childrenIds: ["student1"] });
  // Before ownership reconciliation ran for parentA: a stale enabled record.
  await register("parentA", "dev1");
  await register("parentA", "dev2", "parentA-own-token");
  await register("parentB", "dev1");
  await reconcile("parentB", "dev1");
  await reconcile("parentA", "dev2");
  // Simulate the stale record still enabled (its trigger has not run yet).
  await db.doc(devicePath("parentA", "dev1")).set({ disabled: false }, { merge: true });

  const { calls, sender } = fakeSender();
  await evalFanOut.handleRecitationRecordWrite({
    db,
    recordId: "rec1",
    before: null,
    after: liveEvaluation,
    sender,
  });
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].tokens.map((t) => t.deviceId), ["dev2"]);
});

test("sender sends nothing to a stale legacy record of a released token", async () => {
  await db.doc("parentProfiles/parentA").set({ uid: "parentA", childrenIds: ["student1"] });
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  await reconcile("parentB", "dev1");
  await db.doc(devicePath("parentB", "dev1")).set({ disabled: true }, { merge: true });
  await reconcile("parentB", "dev1", TOKEN);

  const { calls, sender } = fakeSender();
  await evalFanOut.handleRecitationRecordWrite({
    db,
    recordId: "rec3",
    before: null,
    after: liveEvaluation,
    sender,
  });
  assert.equal(calls.length, 0);
});

// ── One-off backfill for pre-trigger records ────────────────────────────────

const backfillAll = async (pageSize = 2) => {
  let cursor = null;
  const totals = {};
  for (;;) {
    const page = await ownership.backfillTokenOwnershipPage(db, { pageSize, cursor });
    for (const [k, v] of Object.entries(page.outcomes)) totals[k] = (totals[k] ?? 0) + v;
    if (page.done) return totals;
    cursor = page.nextCursor;
  }
};

test("backfill: legacy accounts sharing a token converge to the newest one", async () => {
  await register("parentA", "dev1");
  await register("parentC", "dev1");
  await register("parentB", "dev1");
  await register("parentA", "dev2", "parentA-own-token");

  await backfillAll();

  assert.deepEqual(await activeHolders(), ["parentB"]);
  assert.equal((await data(devicePath("parentA", "dev1"))).disabledReason,
    ownership.TOKEN_TRANSFERRED_REASON);
  assert.equal((await data(devicePath("parentC", "dev1"))).disabled, true);
  assert.equal((await data(ownerPath("parentA-own-token"))).uid, "parentA");

  const rerun = await backfillAll();
  assert.equal(rerun.claimed ?? 0, 0, "second run changes no ownership");
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("backfill never re-claims a released token for a stale record", async () => {
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  await reconcile("parentB", "dev1");
  await db.doc(devicePath("parentB", "dev1")).set({ disabled: true }, { merge: true });
  await reconcile("parentB", "dev1", TOKEN);

  await backfillAll();

  assertReleased(await data(ownerPath(TOKEN)));
  assert.deepEqual(await activeHolders(), []);
});

// ── Unchanged path writes nothing (B-4) ─────────────────────────────────────

const ownerUpdateTime = async (token = TOKEN) =>
  (await db.doc(ownerPath(token)).get()).updateTime;

test("unchanged ownership: redelivery and re-registration do not rewrite the owner record", async () => {
  await register("parentA", "dev1");
  assert.equal(await reconcile("parentA", "dev1"), "claimed");
  const claimed = await ownerUpdateTime();

  assert.equal(await reconcile("parentA", "dev1"), "unchanged");
  await register("parentA", "dev1");
  assert.equal(await reconcile("parentA", "dev1"), "unchanged");

  assert.ok((await ownerUpdateTime()).isEqual(claimed), "owner record was rewritten");
  assert.equal((await data(ownerPath(TOKEN))).uid, "parentA");
});

test("unchanged ownership: a backfill rerun does not rewrite owner records", async () => {
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  await register("parentA", "dev2", "parentA-own-token");
  await backfillAll();
  const shared = await ownerUpdateTime();
  const own = await ownerUpdateTime("parentA-own-token");

  const rerun = await backfillAll();
  assert.equal(rerun.claimed ?? 0, 0);
  assert.ok((await ownerUpdateTime()).isEqual(shared));
  assert.ok((await ownerUpdateTime("parentA-own-token")).isEqual(own));
});

test("unchanged ownership: a missing claimedAt is filled in without changing the owner", async () => {
  await register("parentA", "dev1");
  await db.doc(ownerPath(TOKEN)).set({ uid: "parentA", deviceId: "dev1" });
  assert.equal(await reconcile("parentA", "dev1"), "unchanged");
  const owner = await data(ownerPath(TOKEN));
  assert.equal(owner.uid, "parentA");
  assert.equal(owner.deviceId, "dev1");
  assert.ok(owner.claimedAt, "claimedAt filled in");
});

// ── Trigger gate and retry (B-1 / B-2) ──────────────────────────────────────

const NOW = Date.parse("2026-10-14T12:00:00.000Z");
const fresh = new Date(NOW - 60_000).toISOString();

test("trigger: a closed gate returns without throwing or reconciling", async () => {
  let calls = 0;
  const result = await ownership.runOwnershipTrigger({
    gateOpen: false,
    eventTime: fresh,
    now: NOW,
    reconcile: async () => { calls++; return "claimed"; },
  });
  assert.equal(result, "gate_closed");
  assert.equal(calls, 0);
});

test("trigger: transient errors rethrow for redelivery, permanent ones are dropped", async () => {
  const failWith = (code) => ownership.runOwnershipTrigger({
    gateOpen: true,
    eventTime: fresh,
    now: NOW,
    reconcile: async () => { throw Object.assign(new Error("x"), { code }); },
  });
  for (const code of [10, 14, 4, 8, 13, 2, 1, "aborted", "UNAVAILABLE", "deadline-exceeded"]) {
    await assert.rejects(failWith(code), undefined, `code ${code} should be retried`);
  }
  for (const code of [3, 5, 7, 9, "invalid-argument", "permission-denied", undefined]) {
    assert.equal(await failWith(code), "dropped", `code ${code} should be dropped`);
  }
  assert.equal(
    await ownership.runOwnershipTrigger({
      gateOpen: true, eventTime: fresh, now: NOW,
      reconcile: async () => { throw new TypeError("bug"); },
    }),
    "dropped",
  );
});

test("trigger: a delivery older than the retry window is dropped without reconciling", async () => {
  let calls = 0;
  const result = await ownership.runOwnershipTrigger({
    gateOpen: true,
    eventTime: new Date(NOW - ownership.OWNERSHIP_RETRY_WINDOW_MS - 1).toISOString(),
    now: NOW,
    reconcile: async () => { calls++; return "claimed"; },
  });
  assert.equal(result, "expired");
  assert.equal(calls, 0);
});

/** A db whose first [failures] transactions reject with gRPC [code]. */
function flakyDb(failures, code = 10) {
  let left = failures;
  return new Proxy(db, {
    get(target, prop) {
      if (prop === "runTransaction" && left > 0) {
        left--;
        return async () => {
          throw Object.assign(new Error(`${code}: simulated failure`), { code });
        };
      }
      const value = Reflect.get(target, prop, target);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
}

const deliver = (dbLike, uid, deviceId, previousToken) =>
  ownership.runOwnershipTrigger({
    gateOpen: true,
    eventTime: fresh,
    now: NOW,
    reconcile: () =>
      ownership.reconcileDeviceTokenOwnership(dbLike, { uid, deviceId, previousToken }),
  });

test("trigger: a transient transaction failure is retried and the previous owner is still disabled", async () => {
  await register("parentA", "dev1");
  await reconcile("parentA", "dev1");
  await register("parentB", "dev1");

  const flaky = flakyDb(1);
  await assert.rejects(deliver(flaky, "parentB", "dev1"), { code: 10 });
  assert.deepEqual(await activeHolders(), ["parentA"], "nothing committed on the failed delivery");

  assert.equal(await deliver(flaky, "parentB", "dev1"), "claimed");
  assert.equal((await data(devicePath("parentA", "dev1"))).disabledReason,
    ownership.TOKEN_TRANSFERRED_REASON);
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("trigger: a redelivery after a committed attempt is a no-op", async () => {
  await register("parentA", "dev1");
  await reconcile("parentA", "dev1");
  await register("parentB", "dev1");

  // Commit lands, then the delivery reports a transient failure anyway.
  await assert.rejects(ownership.runOwnershipTrigger({
    gateOpen: true, eventTime: fresh, now: NOW,
    reconcile: async () => {
      await reconcile("parentB", "dev1");
      throw Object.assign(new Error("14 UNAVAILABLE"), { code: 14 });
    },
  }), { code: 14 });
  const committed = await ownerUpdateTime();

  assert.equal(await deliver(db, "parentB", "dev1"), "unchanged");
  assert.equal(await deliver(db, "parentB", "dev1"), "unchanged");
  assert.ok((await ownerUpdateTime()).isEqual(committed));
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("trigger: concurrent and duplicate deliveries for competing accounts converge", async () => {
  await register("parentA", "dev1");
  await register("parentB", "dev1");
  await register("parentC", "dev1");
  const results = await Promise.allSettled([
    deliver(db, "parentA", "dev1"),
    deliver(flakyDb(1), "parentC", "dev1"),
    deliver(db, "parentB", "dev1"),
    deliver(db, "parentC", "dev1"),
    deliver(db, "parentB", "dev1"),
  ]);
  // Redeliver anything that asked for a retry, then the follow-up events the
  // disabling writes would raise.
  for (const [i, r] of results.entries()) {
    if (r.status === "rejected") {
      assert.ok(ownership.isTransientOwnershipError(r.reason), `delivery ${i}: ${r.reason}`);
      await deliver(db, ["parentA", "parentC", "parentB", "parentC", "parentB"][i], "dev1");
    }
  }
  for (const uid of ["parentA", "parentB", "parentC"]) {
    await deliver(db, uid, "dev1", TOKEN);
  }
  assert.deepEqual(await activeHolders(), ["parentC"]);
});

// ── Recovery of ownership left stale by a dropped event (Task 2) ───────────

/** Mirrors FcmTokenRemoteDatasourceImpl.upsertDeviceToken. */
async function clientRegister(uid, deviceId, token = TOKEN) {
  await db.doc(devicePath(uid, deviceId)).set(
    {
      token,
      platform: "android",
      disabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

const expired = new Date(NOW - ownership.OWNERSHIP_RETRY_WINDOW_MS - 1).toISOString();

const deliverAt = (eventTime, dbLike, uid, deviceId, previousToken) =>
  ownership.runOwnershipTrigger({
    gateOpen: true,
    eventTime,
    now: NOW,
    reconcile: () =>
      ownership.reconcileDeviceTokenOwnership(dbLike, { uid, deviceId, previousToken }),
  });

test("recovery: an expired delivery leaves ownership stale until the holder's " +
  "next registration repairs it", async () => {
  await clientRegister("parentA", "dev1");
  await deliver(db, "parentA", "dev1");
  await clientRegister("parentB", "dev1");

  assert.equal(await deliverAt(expired, db, "parentB", "dev1"), "expired");
  assert.deepEqual(await activeHolders(), ["parentA"], "stale until repaired");

  await clientRegister("parentB", "dev1");
  assert.equal(await deliver(db, "parentB", "dev1"), "claimed");
  assert.deepEqual(await activeHolders(), ["parentB"]);
  assert.equal((await data(devicePath("parentA", "dev1"))).disabledReason,
    ownership.TOKEN_TRANSFERRED_REASON);

  const repaired = await ownerUpdateTime();
  await clientRegister("parentB", "dev1");
  assert.equal(await deliver(db, "parentB", "dev1"), "unchanged");
  assert.ok((await ownerUpdateTime()).isEqual(repaired), "no write once correct");
});

test("recovery: a permanently failed delivery is repaired by the next registration", async () => {
  await clientRegister("parentA", "dev1");
  await deliver(db, "parentA", "dev1");
  await clientRegister("parentB", "dev1");

  assert.equal(await deliver(flakyDb(1, 7), "parentB", "dev1"), "dropped");
  assert.deepEqual(await activeHolders(), ["parentA"]);

  await clientRegister("parentB", "dev1");
  assert.equal(await deliver(db, "parentB", "dev1"), "claimed");
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("recovery: a transient failure that outlives the retry window is " +
  "repaired by the next registration", async () => {
  await clientRegister("parentA", "dev1");
  await deliver(db, "parentA", "dev1");
  await clientRegister("parentB", "dev1");

  await assert.rejects(deliver(flakyDb(1, 14), "parentB", "dev1"), { code: 14 });
  assert.equal(await deliverAt(expired, db, "parentB", "dev1"), "expired");
  assert.deepEqual(await activeHolders(), ["parentA"]);

  await clientRegister("parentB", "dev1");
  assert.equal(await deliver(db, "parentB", "dev1"), "claimed");
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("recovery: late events of an obsolete account never move ownership back " +
  "and write nothing", async () => {
  await clientRegister("parentA", "dev1");
  await deliver(db, "parentA", "dev1");
  await clientRegister("parentB", "dev1");
  await deliver(db, "parentB", "dev1");
  const settled = await ownerUpdateTime();

  assert.equal(await deliverAt(expired, db, "parentA", "dev1"), "expired");
  assert.equal(await deliver(db, "parentA", "dev1"), "ignored");
  assert.equal(await deliver(db, "parentA", "dev1", TOKEN), "ignored");
  assert.deepEqual(await activeHolders(), ["parentB"]);
  assert.ok((await ownerUpdateTime()).isEqual(settled));
});

test("recovery: duplicate and concurrent repairs converge without extra writes", async () => {
  await clientRegister("parentA", "dev1");
  await deliver(db, "parentA", "dev1");
  await clientRegister("parentB", "dev1");
  assert.equal(await deliverAt(expired, db, "parentB", "dev1"), "expired");

  await clientRegister("parentB", "dev1");
  const results = await Promise.all([
    deliver(db, "parentB", "dev1"),
    deliver(db, "parentB", "dev1"),
    deliver(db, "parentB", "dev1"),
  ]);
  assert.equal(results.filter((r) => r === "claimed").length, 1, String(results));
  assert.ok(results.every((r) => r === "claimed" || r === "unchanged"));
  const repaired = await ownerUpdateTime();

  assert.equal(await deliver(db, "parentB", "dev1"), "unchanged");
  assert.ok((await ownerUpdateTime()).isEqual(repaired));
  assert.deepEqual(await activeHolders(), ["parentB"]);
});

test("sender keeps legacy tokens that have no owner record yet", async () => {
  await db.doc("parentProfiles/parentA").set({ uid: "parentA", childrenIds: ["student1"] });
  await register("parentA", "dev1", "legacy-token");
  const { calls, sender } = fakeSender();
  await evalFanOut.handleRecitationRecordWrite({
    db,
    recordId: "rec2",
    before: null,
    after: liveEvaluation,
    sender,
  });
  assert.deepEqual(calls[0].tokens.map((t) => t.deviceId), ["dev1"]);
});
