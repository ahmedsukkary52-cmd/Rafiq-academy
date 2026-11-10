/**
 * H2 ownership gate against the Firestore emulator: the exported ownership
 * trigger (reconcileFcmTokenOwnership) runs through FCM_OWNERSHIP_ENABLED
 * while the push gate and the shared backend gate stay closed, and the
 * exported evaluation sender (notifyParentsOnEvaluation) never reaches FCM.
 *
 * FCM is replaced in-process by a recording stub and a process-wide egress
 * guard refuses every connection except the loopback emulator port.
 * PRODUCTION_BACKEND_ENABLED is never set. Synthetic data only.
 *
 *   firebase emulators:exec --config <isolated firebase.json> --project demo-rafiq-rules \
 *     --only firestore "node --test --test-concurrency=1 test/fcm_ownership_gate.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST ?? "";

if (PROJECT_ID !== "demo-rafiq-rules" || !/^(127\.0\.0\.1|localhost):\d{1,5}$/.test(EMULATOR)) {
  throw new Error("ownership gate suite requires demo-rafiq-rules and a loopback FIRESTORE_EMULATOR_HOST");
}
if (process.env.PRODUCTION_BACKEND_ENABLED !== undefined) throw new Error("PRODUCTION_BACKEND_ENABLED must be unset");
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) throw new Error("GOOGLE_APPLICATION_CREDENTIALS must be unset");
delete process.env.FUNCTIONS_EMULATOR;
delete process.env.FCM_OWNERSHIP_ENABLED;
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.METADATA_SERVER_DETECTION = "none";

const guard = installEgressGuard({ allowedPorts: [Number(EMULATOR.split(":")[1])] });
assert.equal(await guard.selfTest(), true, "egress guard self-test");

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

// FCM stub, installed before the trigger modules load.
const TOKENS = {
  shared: "SYNTH-OG-shared-1a",
  aOwn: "SYNTH-OG-a-own-2b",
  other: "SYNTH-OG-other-3c",
};
const LABEL = new Map(Object.entries(TOKENS).map(([label, token]) => [token, label]));
const sends = [];
Object.defineProperty(admin, "messaging", {
  configurable: true,
  value: () => ({
    sendEachForMulticast: async ({ tokens }) => {
      sends.push(tokens.map((t) => LABEL.get(t) ?? "unknown"));
      return { responses: tokens.map(() => ({ success: true })) };
    },
  }),
});

const ownership = require("../lib/notifications/fcmTokenOwnership.js");
const evaluation = require("../lib/notifications/evaluationNotificationFunctions.js");
const ownershipGate = require("../lib/notifications/ownershipGate.js");
const pushGate = require("../lib/notifications/pushGate.js");
const productionGate = require("../lib/productionGate.js");

const SECRETS = [...Object.values(TOKENS), ...Object.values(TOKENS).map(ownership.tokenOwnerDocId), "SYNTH-OG"];
const devicePath = (uid, deviceId = "d1") => `fcmTokens/${uid}/devices/${deviceId}`;
const ownerPath = (token) => `fcmTokenOwners/${ownership.tokenOwnerDocId(token)}`;

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function data(path) {
  const snap = await db.doc(path).get();
  return snap.exists ? snap.data() : null;
}

async function paths(collection) {
  return (await db.collection(collection).get()).docs.map((d) => d.ref.path).sort();
}

/** Ownership gate as configured by FCM_OWNERSHIP_ENABLED; push must stay blocked. */
function setOwnershipGate(value) {
  if (value === undefined) delete process.env.FCM_OWNERSHIP_ENABLED;
  else process.env.FCM_OWNERSHIP_ENABLED = value;
  assert.equal(productionGate.isProductionBackendEnabled(), false);
  assert.equal(pushGate.resolvePushSendMode(), "blocked");
}

function ownershipEvent(uid, deviceId, beforeData, time = new Date().toISOString()) {
  return {
    time,
    params: { uid, deviceId },
    data: { before: { data: () => beforeData ?? undefined } },
  };
}

/** Client-shaped write followed by the trigger delivery it raises. */
async function register(uid, deviceId, fields, { deliver = true } = {}) {
  const before = await data(devicePath(uid, deviceId));
  await db.doc(devicePath(uid, deviceId)).set(
    { platform: "android", disabled: false, ...fields, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  const event = ownershipEvent(uid, deviceId, before);
  if (deliver) await ownership.reconcileFcmTokenOwnership.run(event);
  return event;
}

const evaluationFor = (studentId) => ({
  studentId,
  halaqaId: "h1",
  teacherId: "teacher1",
  sessionId: "sess_x",
  type: "memorization",
  grade: "excellent-label",
  reviewStatus: "reviewed",
});

async function parent(uid) {
  await db.doc(`parentProfiles/${uid}`).set({ uid, childrenIds: [`child_${uid}`] });
}

/** Runs the exported evaluation trigger for [uid]'s child; returns labels sent. */
async function notify(uid, recordId) {
  const start = sends.length;
  await evaluation.notifyParentsOnEvaluation.run({
    params: { recordId },
    data: { before: { data: () => undefined }, after: { data: () => evaluationFor(`child_${uid}`) } },
  });
  return sends.slice(start).flat().sort();
}

test.beforeEach(async () => {
  await clearFirestore();
  delete process.env.FUNCTIONS_EMULATOR;
  setOwnershipGate(undefined);
});

test.after(() => {
  delete process.env.FUNCTIONS_EMULATOR;
  delete process.env.FCM_OWNERSHIP_ENABLED;
  assert.deepEqual(guard.blockedAttempts(), [], "no connection left the loopback emulator");
  const recorded = JSON.stringify(sends);
  for (const s of SECRETS) assert.ok(!recorded.includes(s), "recorded labels leaked a token");
});

test("ownership gate open, push closed: ownership is claimed and transferred, nothing is sent", async () => {
  setOwnershipGate("true");
  await parent("parentA");
  await parent("parentB");
  await register("parentA", "d1", { token: TOKENS.shared });
  assert.deepEqual(
    (({ uid, deviceId }) => ({ uid, deviceId }))(await data(ownerPath(TOKENS.shared))),
    { uid: "parentA", deviceId: "d1" },
  );
  await register("parentB", "d1", { token: TOKENS.shared });
  assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB");
  const stale = await data(devicePath("parentA"));
  assert.equal(stale.disabled, true);
  assert.equal(stale.disabledReason, ownership.TOKEN_TRANSFERRED_REASON);

  assert.deepEqual(await notify("parentA", "rec_a"), []);
  assert.deepEqual(await notify("parentB", "rec_b"), []);
  assert.equal(sends.length, 0, "FCM never called");
  assert.deepEqual(await paths("notifications"), [], "no in-app notification written");
  assert.deepEqual(await paths("notificationDeliveries"), [], "no delivery claim written");
});

test("ownership gate closed or not exactly \"true\": the trigger writes nothing", async () => {
  for (const value of [undefined, "TRUE", "1", " true"]) {
    await clearFirestore();
    setOwnershipGate(value);
    await register("parentA", "d1", { token: TOKENS.shared });
    await register("parentB", "d1", { token: TOKENS.shared });
    assert.deepEqual(await paths("fcmTokenOwners"), [], JSON.stringify(value));
    assert.equal((await data(devicePath("parentA"))).disabled, false, JSON.stringify(value));
  }
});

test("a delivery is attributed only to the device record at its own path", async () => {
  setOwnershipGate("true");
  await register("parentA", "d1", { token: TOKENS.shared }, { deliver: false });
  // Event names B, but no record exists under B: B never becomes the owner.
  await ownership.reconcileFcmTokenOwnership.run(ownershipEvent("parentB", "d1", null));
  assert.deepEqual(await paths("fcmTokenOwners"), []);
  // The real delivery for A's record claims for A only.
  await ownership.reconcileFcmTokenOwnership.run(ownershipEvent("parentA", "d1", null));
  const owner = await data(ownerPath(TOKENS.shared));
  assert.deepEqual({ uid: owner.uid, deviceId: owner.deviceId }, { uid: "parentA", deviceId: "d1" });
});

test("missing or invalid data never records ownership", async () => {
  setOwnershipGate("true");
  const cases = [
    ["uEmpty", { token: "" }],
    ["uBlank", { token: "    " }],
    ["uLong", { token: "x".repeat(4097) }],
    ["uNumber", { token: 12345 }],
    ["uNoToken", {}],
    ["uDisabled", { token: TOKENS.other, disabled: true }],
  ];
  for (const [uid, fields] of cases) await register(uid, "d1", fields);
  // No device record at all, and malformed event params.
  await ownership.reconcileFcmTokenOwnership.run(ownershipEvent("uMissing", "d1", null));
  for (const params of [{ uid: undefined, deviceId: "d1" }, { uid: "uX", deviceId: undefined }, {}]) {
    await ownership.reconcileFcmTokenOwnership.run({
      time: new Date().toISOString(),
      params,
      data: { before: { data: () => undefined } },
    });
  }
  assert.deepEqual(await paths("fcmTokenOwners"), []);
  for (const [uid] of cases) {
    const doc = await data(devicePath(uid));
    assert.notEqual(doc.disabledReason, ownership.TOKEN_TRANSFERRED_REASON, uid);
  }
});

test("duplicate, late and expired deliveries never move the token back to the stale account", async () => {
  setOwnershipGate("true");
  const lateA = await register("parentA", "d1", { token: TOKENS.shared });
  const bEvent = await register("parentB", "d1", { token: TOKENS.shared });
  await ownership.reconcileFcmTokenOwnership.run(bEvent);
  await ownership.reconcileFcmTokenOwnership.run(lateA);
  const old = new Date(Date.now() - ownership.OWNERSHIP_RETRY_WINDOW_MS - 60_000).toISOString();
  await db.doc(devicePath("parentA")).set({ disabled: false }, { merge: true });
  await ownership.reconcileFcmTokenOwnership.run(ownershipEvent("parentA", "d1", { token: TOKENS.shared }, old));
  assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB");
});

test("ownership recorded while push was closed protects the first sends after push opens", async () => {
  setOwnershipGate("true");
  await parent("parentA");
  await parent("parentB");
  await register("parentA", "d1", { token: TOKENS.shared });
  await register("parentA", "d2", { token: TOKENS.aOwn });
  await register("parentB", "d1", { token: TOKENS.shared });
  // Simulate the stale record still enabled, as if A's sign-out never landed.
  await db.doc(devicePath("parentA")).set({ disabled: false }, { merge: true });
  assert.equal(sends.length, 0);

  // Push opens the only way it opens locally: Functions emulator + demo project.
  process.env.FUNCTIONS_EMULATOR = "true";
  assert.equal(pushGate.resolvePushSendMode(), "emulator");
  assert.deepEqual(await notify("parentA", "rec_open_a"), ["aOwn"], "B's token never carries A's notification");
  assert.deepEqual(await notify("parentB", "rec_open_b"), ["shared"]);
});

test("without the ownership gate the same history leaves the token unowned (the gap it closes)", async () => {
  await parent("parentA");
  await register("parentA", "d1", { token: TOKENS.shared });
  await register("parentB", "d1", { token: TOKENS.shared });
  assert.deepEqual(await paths("fcmTokenOwners"), []);
  process.env.FUNCTIONS_EMULATOR = "true";
  assert.deepEqual(await notify("parentA", "rec_gap_a"), ["shared"]);
});

test("the ownership gate never opens the shared gate inside this process", () => {
  setOwnershipGate("true");
  assert.equal(ownershipGate.isOwnershipReconcileEnabled(), true);
  assert.equal(productionGate.isProductionBackendEnabled(), false);
  assert.equal(pushGate.resolvePushSendMode(), "blocked");
});
