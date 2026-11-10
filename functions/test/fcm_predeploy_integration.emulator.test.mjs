/**
 * Pre-deployment integration: the exported ownership trigger
 * (reconcileFcmTokenOwnership) and the exported evaluation sender
 * (notifyParentsOnEvaluation) driven together through their real `.run`
 * handlers against the Firestore emulator, with the shared backend gate
 * closed and opened the only way it opens locally (Functions emulator +
 * demo project). PRODUCTION_BACKEND_ENABLED is never set.
 *
 * FCM is replaced in-process by a recording stub and a process-wide egress
 * guard refuses every connection except the loopback emulator port.
 * Synthetic data only; tokens are never printed.
 *
 *   firebase emulators:exec --config <isolated firebase.json> --project demo-rafiq-rules \
 *     --only firestore "node --test --test-concurrency=1 test/fcm_predeploy_integration.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";
import {
  assertEmulatorWriteTarget,
  runTokenOwnershipBackfill,
} from "../scripts/migrate-fcm-token-ownership.mjs";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST ?? "";

if (PROJECT_ID !== "demo-rafiq-rules" || !/^(127\.0\.0\.1|localhost):\d{1,5}$/.test(EMULATOR)) {
  throw new Error("integration suite requires demo-rafiq-rules and a loopback FIRESTORE_EMULATOR_HOST");
}
if (process.env.PRODUCTION_BACKEND_ENABLED !== undefined) throw new Error("PRODUCTION_BACKEND_ENABLED must be unset");
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) throw new Error("GOOGLE_APPLICATION_CREDENTIALS must be unset");
delete process.env.FUNCTIONS_EMULATOR;
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.METADATA_SERVER_DETECTION = "none";

const guard = installEgressGuard({ allowedPorts: [Number(EMULATOR.split(":")[1])] });
assert.equal(await guard.selfTest(), true, "egress guard self-test");

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const { FieldPath } = require("firebase-admin/firestore");

// ── FCM stub (installed before the trigger modules load) ───────────────────
const TOKENS = {
  shared: "SYNTH-INT-shared-1a",
  bOwn: "SYNTH-INT-b-own-2b",
  aOwn: "SYNTH-INT-a-own-3c",
  malformed: "SYNTH-INT-malformed-4d",
  released: "SYNTH-INT-released-5e",
  otherDevice: "SYNTH-INT-other-device-6f",
};
const LABEL = new Map(Object.entries(TOKENS).map(([label, token]) => [token, label]));
const sends = [];
let onSend = null;
Object.defineProperty(admin, "messaging", {
  configurable: true,
  value: () => ({
    sendEachForMulticast: async ({ tokens }) => {
      sends.push(tokens.map((t) => LABEL.get(t) ?? "unknown"));
      if (onSend) await onSend();
      return { responses: tokens.map(() => ({ success: true })) };
    },
  }),
});

const ownership = require("../lib/notifications/fcmTokenOwnership.js");
const evaluation = require("../lib/notifications/evaluationNotificationFunctions.js");
const productionGate = require("../lib/productionGate.js");
const pushGate = require("../lib/notifications/pushGate.js");

const SECRETS = [...Object.values(TOKENS), ...Object.values(TOKENS).map(ownership.tokenOwnerDocId), "SYNTH-INT"];

// ── helpers ────────────────────────────────────────────────────────────────
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

function setGate(open) {
  if (open) process.env.FUNCTIONS_EMULATOR = "true";
  else delete process.env.FUNCTIONS_EMULATOR;
  assert.equal(productionGate.isProductionBackendEnabled(), false);
  assert.equal(pushGate.resolvePushSendMode(), open ? "emulator" : "blocked");
}

/** Client-shaped registration followed by the trigger delivery it raises. */
async function register(uid, deviceId, token, { deliver = true } = {}) {
  const before = await data(devicePath(uid, deviceId));
  await db.doc(devicePath(uid, deviceId)).set(
    { token, platform: "android", disabled: false, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  const event = ownershipEvent(uid, deviceId, before);
  if (deliver) await ownership.reconcileFcmTokenOwnership.run(event);
  return event;
}

function ownershipEvent(uid, deviceId, beforeData, time = new Date().toISOString()) {
  return {
    time,
    params: { uid, deviceId },
    data: { before: { data: () => beforeData ?? undefined } },
  };
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

/** Parent [uid] with a dedicated child, so each send targets one parent. */
async function parent(uid) {
  await db.doc(`parentProfiles/${uid}`).set({ uid, childrenIds: [`child_${uid}`] });
}

/** Runs the exported evaluation trigger for [uid]'s child; returns token labels sent. */
async function notify(uid, recordId) {
  const start = sends.length;
  await evaluation.notifyParentsOnEvaluation.run({
    params: { recordId },
    data: { before: { data: () => undefined }, after: { data: () => evaluationFor(`child_${uid}`) } },
  });
  return sends.slice(start).flat().sort();
}

async function allDocs(collection) {
  return (await db.collection(collection).get()).docs.map((d) => d.ref.path).sort();
}

test.beforeEach(async () => {
  await clearFirestore();
  setGate(false);
  onSend = null;
});

test.after(() => {
  delete process.env.FUNCTIONS_EMULATOR;
  assert.deepEqual(guard.blockedAttempts(), [], "no connection left the loopback emulator");
  assertNoLeak(JSON.stringify(sends), "recorded send labels");
});

function assertNoLeak(text, label) {
  for (const s of SECRETS) assert.ok(!text.includes(s), `${label} leaked a token or token hash`);
}

// ── gate closed: the deployment state under review ─────────────────────────
test("gate closed: neither trigger reads, writes or sends anything", async () => {
  await parent("parentA");
  await parent("parentB");
  await register("parentA", "d1", TOKENS.shared);
  await register("parentB", "d1", TOKENS.shared);
  const devicesBefore = JSON.stringify(
    (await db.getAll(db.doc(devicePath("parentA")), db.doc(devicePath("parentB"))))
      .map((s) => [s.data(), s.updateTime.seconds, s.updateTime.nanoseconds]),
  );

  assert.deepEqual(await notify("parentA", "rec_closed_a"), []);
  assert.deepEqual(await notify("parentB", "rec_closed_b"), []);
  assert.equal(sends.length, 0, "FCM never called");
  assert.deepEqual(await allDocs("fcmTokenOwners"), [], "no ownership record written");
  assert.deepEqual(await allDocs("notifications"), [], "no in-app notification written");
  assert.deepEqual(await allDocs("notificationDeliveries"), [], "no delivery claim written");
  const devicesAfter = JSON.stringify(
    (await db.getAll(db.doc(devicePath("parentA")), db.doc(devicePath("parentB"))))
      .map((s) => [s.data(), s.updateTime.seconds, s.updateTime.nanoseconds]),
  );
  assert.equal(devicesAfter, devicesBefore, "device records untouched");
});

test("gate closed then opened: registrations made while closed stay unreconciled " +
  "until the holder registers again or the backfill runs", async () => {
  await parent("parentA");
  await parent("parentB");
  await register("parentA", "d1", TOKENS.shared);
  await register("parentB", "d1", TOKENS.shared); // dropped: gate closed
  setGate(true);
  // Legacy behaviour: no owner record, so A's stale record is still sendable.
  assert.deepEqual(await notify("parentA", "rec_reopen_1"), ["shared"]);

  // Repair path 1: B's next registration (every app start rewrites updatedAt).
  await register("parentB", "d1", TOKENS.shared);
  assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB");
  // With no prior owner record the trigger cannot locate A's legacy record,
  // so it stays enabled; the owner record alone makes it unsendable.
  assert.equal((await data(devicePath("parentA"))).disabled, false);
  assert.deepEqual(await notify("parentA", "rec_reopen_2"), []);
  assert.deepEqual(await notify("parentB", "rec_reopen_b"), ["shared"]);
});

test("gate closed then opened: the backfill closes the same gap without a re-registration", async () => {
  await parent("parentA");
  await register("parentA", "d1", TOKENS.shared);
  await register("parentB", "d1", TOKENS.shared);
  setGate(true);
  const report = await runTokenOwnershipBackfill({
    db,
    mode: "apply",
    documentId: FieldPath.documentId(),
    reconcile: ownership.reconcileDeviceTokenOwnership,
    assertWriteTarget: () => assertEmulatorWriteTarget({ projectId: PROJECT_ID, env: process.env }),
  });
  assert.equal(report.written.claimed, 1);
  assert.equal(report.written.olderHoldersDisabled, 1);
  assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB");
  assert.deepEqual(await notify("parentA", "rec_backfilled"), []);
  assertNoLeak(JSON.stringify(report), "backfill report");
});

// ── gate open (emulator): trigger + sender together ────────────────────────
test("B owns the token, A keeps a stale record: A's notification never reaches it", async () => {
  setGate(true);
  await parent("parentA");
  await parent("parentB");
  await register("parentA", "d1", TOKENS.shared);
  await register("parentA", "d2", TOKENS.aOwn);
  await register("parentB", "d1", TOKENS.shared);
  // Force the stale record back to enabled, as if its own trigger never ran.
  await db.doc(devicePath("parentA")).set({ disabled: false }, { merge: true });

  assert.deepEqual(await notify("parentA", "rec_stale_a"), ["aOwn"]);
  assert.deepEqual(await notify("parentB", "rec_stale_b"), ["shared"]);
});

test("duplicate, retried and out-of-order trigger deliveries never move the token back to A", async () => {
  setGate(true);
  await parent("parentA");
  const lateA = await register("parentA", "d1", TOKENS.shared);
  const bEvent = await register("parentB", "d1", TOKENS.shared);
  // Redeliveries of B's event, then a late redelivery of A's original event.
  await ownership.reconcileFcmTokenOwnership.run(bEvent);
  await ownership.reconcileFcmTokenOwnership.run(bEvent);
  await ownership.reconcileFcmTokenOwnership.run(lateA);
  // A's stale record is re-enabled by a forged client write (no token change).
  await db.doc(devicePath("parentA")).set({ disabled: false }, { merge: true });
  await ownership.reconcileFcmTokenOwnership.run(ownershipEvent("parentA", "d1", { token: TOKENS.shared }));
  // That write is a newer registration of the same token, so A wins it back
  // by design (newest registration owns); B's next app start reclaims it.
  const afterForged = await data(ownerPath(TOKENS.shared));
  assert.equal(afterForged.uid, "parentA");
  await register("parentB", "d1", TOKENS.shared);
  assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB");
  assert.deepEqual(await notify("parentA", "rec_dup"), []);
});

test("an expired trigger delivery is dropped and leaves the newer owner in place", async () => {
  setGate(true);
  await parent("parentA");
  await register("parentA", "d1", TOKENS.shared);
  await register("parentB", "d1", TOKENS.shared);
  const old = new Date(Date.now() - ownership.OWNERSHIP_RETRY_WINDOW_MS - 60_000).toISOString();
  await db.doc(devicePath("parentA")).set({ disabled: false }, { merge: true });
  await ownership.reconcileFcmTokenOwnership.run(ownershipEvent("parentA", "d1", { token: TOKENS.shared }, old));
  assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB");
  assert.deepEqual(await notify("parentA", "rec_expired"), []);
});

test("sender with malformed, released, foreign-device and missing owner records", async () => {
  setGate(true);
  await parent("parentA");
  await register("parentA", "d1", TOKENS.malformed, { deliver: false });
  await db.doc(ownerPath(TOKENS.malformed)).set({ uid: "parentA" });
  await register("parentA", "d2", TOKENS.released, { deliver: false });
  await db.doc(ownerPath(TOKENS.released)).set({ releasedAt: admin.firestore.FieldValue.serverTimestamp() });
  await register("parentA", "d3", TOKENS.otherDevice, { deliver: false });
  await db.doc(ownerPath(TOKENS.otherDevice)).set({ uid: "parentA", deviceId: "d9" });
  await register("parentA", "d4", TOKENS.aOwn, { deliver: false }); // no owner record: legacy
  assert.deepEqual(await notify("parentA", "rec_malformed"), ["aOwn"]);
});

test("a claim committed before the sender reads ownership always excludes the token", async () => {
  setGate(true);
  await parent("parentA");
  await register("parentA", "d1", TOKENS.shared);
  for (let i = 0; i < 5; i++) {
    await register("parentB", "d1", TOKENS.shared);
    assert.deepEqual(await notify("parentA", `rec_seq_${i}`), [], `iteration ${i}`);
    await register("parentA", "d1", TOKENS.shared);
    assert.deepEqual(await notify("parentA", `rec_seq_back_${i}`), ["shared"], `iteration ${i}`);
  }
});

test("concurrent ownership change and send converge; later sends exclude the token", async () => {
  setGate(true);
  await parent("parentA");
  for (let i = 0; i < 5; i++) {
    await clearFirestore();
    await parent("parentA");
    await register("parentA", "d1", TOKENS.shared);
    await db.doc(devicePath("parentB")).set({ token: TOKENS.shared, platform: "android", disabled: false });
    await Promise.all([
      ownership.reconcileFcmTokenOwnership.run(ownershipEvent("parentB", "d1", null)),
      notify("parentA", `rec_conc_${i}`),
    ]);
    assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB", `iteration ${i}`);
    assert.equal((await data(devicePath("parentA"))).disabled, true, `iteration ${i}`);
    assert.deepEqual(await notify("parentA", `rec_conc_after_${i}`), [], `iteration ${i}`);
  }
});

test("documented window: before B's delivery commits, A (still the recorded owner) is sent to", async () => {
  setGate(true);
  await parent("parentA");
  await register("parentA", "d1", TOKENS.shared);
  const delayed = await register("parentB", "d1", TOKENS.shared, { deliver: false });
  // Trigger delayed: the server still names A as owner, so A's push goes out.
  assert.deepEqual(await notify("parentA", "rec_window_1"), ["shared"]);
  await ownership.reconcileFcmTokenOwnership.run(delayed);
  assert.deepEqual(await notify("parentA", "rec_window_2"), []);
});

test("time-of-check window: an ownership change during the FCM call does not recall the send", async () => {
  setGate(true);
  await parent("parentA");
  await register("parentA", "d1", TOKENS.shared);
  onSend = async () => {
    onSend = null;
    await register("parentB", "d1", TOKENS.shared);
  };
  assert.deepEqual(await notify("parentA", "rec_toc_1"), ["shared"]);
  assert.equal((await data(ownerPath(TOKENS.shared))).uid, "parentB");
  assert.deepEqual(await notify("parentA", "rec_toc_2"), []);
});
