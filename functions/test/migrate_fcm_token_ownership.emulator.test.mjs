/**
 * FCM token ownership backfill runner against the Firestore emulator, using
 * the real reconcile transaction from lib/. Synthetic data only; refuses to
 * start unless the project is demo-rafiq-rules on a loopback emulator.
 *
 * Run (after `npm --prefix functions run build`) with an isolated config:
 *   firebase emulators:exec --config <isolated firebase.json> --project demo-rafiq-rules \
 *     --only firestore "node --test --test-concurrency=1 test/migrate_fcm_token_ownership.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
  GROUP,
  SCRIPT_ID,
  WRITE_PROJECT,
  assertEmulatorWriteTarget,
  runTokenOwnershipBackfill,
} from "../scripts/migrate-fcm-token-ownership.mjs";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST ?? "";

if (PROJECT_ID !== WRITE_PROJECT || !/^(127\.0\.0\.1|localhost):\d{1,5}$/.test(EMULATOR)) {
  throw new Error(`backfill emulator suite requires ${WRITE_PROJECT} and a loopback FIRESTORE_EMULATOR_HOST`);
}
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) throw new Error("GOOGLE_APPLICATION_CREDENTIALS must be unset");
if (process.env.PRODUCTION_BACKEND_ENABLED !== undefined) throw new Error("PRODUCTION_BACKEND_ENABLED must be unset");
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const { FieldPath } = require("firebase-admin/firestore");
const ownership = require("../lib/notifications/fcmTokenOwnership.js");
const evalFanOut = require("../lib/notifications/evaluationNotificationFunctions.js");
const pushGate = require("../lib/notifications/pushGate.js");

const here = dirname(fileURLToPath(import.meta.url));
const scriptPath = join(here, "..", "scripts", "migrate-fcm-token-ownership.mjs");
const egressPreload = pathToFileURL(join(here, "migrate-egress-preload.mjs")).href;
const emulatorPort = EMULATOR.split(":")[1];

const T = {
  single: "SYNTH-EMU-single-41a",
  shared: "SYNTH-EMU-shared-52b",
  tie: "SYNTH-EMU-tie-63c",
  ownedB: "SYNTH-EMU-owned-b-74d",
  released: "SYNTH-EMU-released-85e",
  moved: "SYNTH-EMU-moved-96f",
  malformed: "SYNTH-EMU-malformed-a70",
  parentAOwn: "SYNTH-EMU-parent-a-own-b81",
};
const SECRETS = [...Object.values(T), ...Object.values(T).map(ownership.tokenOwnerDocId), "SYNTH-EMU"];
const assertNoLeak = (text, label) => {
  for (const s of SECRETS) assert.ok(!text.includes(s), `${label} leaked a token or token hash`);
};

const devicePath = (uid, deviceId = "d1") => `fcmTokens/${uid}/devices/${deviceId}`;
const ownerPath = (token) => `fcmTokenOwners/${ownership.tokenOwnerDocId(token)}`;
const reg = (token) => ({ token, platform: "android", disabled: false });

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

/** path -> data + updateTime for every device and owner record. */
async function dump() {
  const out = {};
  const add = (snap) => {
    out[snap.ref.path] = { data: snap.data(), t: `${snap.updateTime.seconds}.${snap.updateTime.nanoseconds}` };
  };
  (await db.collectionGroup("devices").get()).docs.forEach(add);
  (await db.collection("fcmTokenOwners").get()).docs.forEach(add);
  return JSON.stringify(Object.entries(out).sort(([a], [b]) => (a < b ? -1 : 1)));
}

/** Every ownership situation, written in separate commits except the tie. */
async function seed() {
  await db.doc(devicePath("uSingle")).set(reg(T.single));
  await db.doc(devicePath("uOld")).set(reg(T.shared));
  await db.doc(devicePath("uNew")).set(reg(T.shared));
  const tie = db.batch();
  tie.set(db.doc(devicePath("uTieA")), reg(T.tie));
  tie.set(db.doc(devicePath("uTieB")), reg(T.tie));
  await tie.commit();
  // B verified owner; A's record of the same token is stale yet written later.
  await db.doc(devicePath("parentB")).set(reg(T.ownedB));
  await ownership.reconcileDeviceTokenOwnership(db, { uid: "parentB", deviceId: "d1" });
  await db.doc(devicePath("parentA")).set(reg(T.ownedB));
  await db.doc(devicePath("parentA", "d2")).set(reg(T.parentAOwn));
  await db.doc(devicePath("uStale")).set(reg(T.released));
  await db.doc(ownerPath(T.released)).set({ releasedAt: admin.firestore.FieldValue.serverTimestamp() });
  await db.doc(devicePath("uHolder")).set(reg(T.moved));
  await db.doc(ownerPath(T.moved)).set({ uid: "uGone", deviceId: "d9" });
  await db.doc(devicePath("uMal")).set(reg(T.malformed));
  await db.doc(ownerPath(T.malformed)).set({ uid: "uMal" });
}

const run = (mode) =>
  runTokenOwnershipBackfill({
    db,
    mode,
    documentId: FieldPath.documentId(),
    reconcile: ownership.reconcileDeviceTokenOwnership,
    assertWriteTarget: () => assertEmulatorWriteTarget({ projectId: PROJECT_ID, env: process.env }),
    pageSize: 3,
  });

const liveEvaluation = {
  studentId: "student1",
  halaqaId: "h1",
  teacherId: "teacher1",
  sessionId: "sess_x",
  type: "memorization",
  grade: "excellent-label",
  reviewStatus: "reviewed",
};

/** Device ids the evaluation fan-out would push to for parent [uid]. */
async function sentDevices(uid, recordId) {
  const studentId = `child_${uid}`;
  await db.doc(`parentProfiles/${uid}`).set({ uid, childrenIds: [studentId] });
  const calls = [];
  await evalFanOut.handleRecitationRecordWrite({
    db,
    recordId,
    before: null,
    after: { ...liveEvaluation, studentId },
    sender: async ({ tokens }) => {
      calls.push(tokens.map((t) => t.deviceId));
      return tokens.map((t) => ({ deviceId: t.deviceId, success: true }));
    },
  });
  return calls.flat();
}

test.beforeEach(clearFirestore);

test("the tie fixture really shares one server updateTime", async () => {
  await seed();
  const [a, b] = await db.getAll(db.doc(devicePath("uTieA")), db.doc(devicePath("uTieB")));
  assert.ok(a.updateTime.isEqual(b.updateTime));
});

test("dry run writes nothing and classifies every situation", async () => {
  await seed();
  const before = await dump();
  const report = await run("dry-run");
  assert.equal(await dump(), before);
  assert.equal(report.groups[GROUP.legacySingle], 2); // uSingle + parentA's own token
  assert.equal(report.groups[GROUP.legacyShared], 1);
  assert.equal(report.groups[GROUP.legacyTie], 1);
  assert.equal(report.groups[GROUP.ownedWithStaleHolders], 1);
  assert.equal(report.groups[GROUP.released], 1);
  assert.equal(report.groups[GROUP.ownerNotHolding], 1);
  assert.equal(report.groups[GROUP.ownerMalformed], 1);
  assert.deepEqual(report.review[GROUP.ownedWithStaleHolders].refs, ["parentA/d1"]);
  assertNoLeak(JSON.stringify(report), "dry-run report");
});

test("apply claims unambiguous legacy tokens and leaves everything else untouched", async () => {
  await seed();
  const keep = [
    devicePath("uTieA"), devicePath("uTieB"), ownerPath(T.tie),
    devicePath("parentA"), devicePath("parentB"), ownerPath(T.ownedB),
    devicePath("uStale"), ownerPath(T.released),
    devicePath("uHolder"), ownerPath(T.moved),
    devicePath("uMal"), ownerPath(T.malformed),
  ];
  const snapshot = async () => {
    const snaps = await db.getAll(...keep.map((p) => db.doc(p)));
    return JSON.stringify(snaps.map((s) => (s.exists ? [s.data(), s.updateTime.seconds, s.updateTime.nanoseconds] : null)));
  };
  const before = await snapshot();
  const report = await run("apply");
  assert.equal(await snapshot(), before, "ambiguous, owned, released, moved and malformed records untouched");
  assert.deepEqual(report.written, { claimed: 3, olderHoldersDisabled: 1, skippedChangedSinceScan: 0, unexpectedOutcome: 0 });
  assert.deepEqual(report.errors, {});

  const shared = await data(ownerPath(T.shared));
  assert.deepEqual({ uid: shared.uid, deviceId: shared.deviceId }, { uid: "uNew", deviceId: "d1" });
  const older = await data(devicePath("uOld"));
  assert.equal(older.disabled, true);
  assert.equal(older.disabledReason, ownership.TOKEN_TRANSFERRED_REASON);
  assert.equal(older.token, T.shared, "token is kept, only disabled");
  assert.equal((await data(devicePath("uNew"))).disabled, false);
  assert.equal((await data(ownerPath(T.single))).uid, "uSingle");
  assert.equal((await data(ownerPath(T.ownedB))).uid, "parentB", "stale A did not override B");
  assert.equal(await data(ownerPath(T.tie)), null, "tie is not guessed");
  assertNoLeak(JSON.stringify(report), "apply report");
});

test("a token owned by B is never used for A's notifications, before or after apply", async () => {
  await seed();
  assert.deepEqual(await sentDevices("parentA", "rec_before"), ["d2"]);
  await run("apply");
  assert.deepEqual(await sentDevices("parentA", "rec_after"), ["d2"]);
  assert.deepEqual(await sentDevices("parentB", "rec_b"), ["d1"]);
});

test("released, moved and malformed owner records keep their holders unsendable", async () => {
  await seed();
  await run("apply");
  for (const [uid, token] of [["uStale", T.released], ["uHolder", T.moved], ["uMal", T.malformed]]) {
    const kept = await ownership.filterOwnedTokens(db, uid, [{ deviceId: "d1", token }]);
    assert.deepEqual(kept, [], `${uid} must fail closed`);
  }
});

test("after apply the older holder of a legacy shared token receives nothing", async () => {
  await seed();
  await run("apply");
  assert.deepEqual(await sentDevices("uOld", "rec_old"), []);
  assert.deepEqual(await sentDevices("uNew", "rec_new"), ["d1"]);
});

test("re-running apply changes nothing", async () => {
  await seed();
  await run("apply");
  const after = await dump();
  const second = await run("apply");
  assert.equal(await dump(), after);
  assert.equal(second.plannedGroups, 0);
  assert.deepEqual(second.written, { claimed: 0, olderHoldersDisabled: 0, skippedChangedSinceScan: 0, unexpectedOutcome: 0 });
});

test("the push gate stays blocked while PRODUCTION_BACKEND_ENABLED is unset", async () => {
  await seed();
  await run("apply");
  assert.equal(process.env.PRODUCTION_BACKEND_ENABLED, undefined);
  assert.equal(pushGate.resolvePushSendMode(), "blocked");
  assert.equal(pushGate.isPushSendAllowed(pushGate.resolvePushSendMode()), false);
});

function cli(argv, extraEnv) {
  const env = Object.fromEntries(
    Object.entries(process.env).filter(([k]) =>
      !/(^GCLOUD_PROJECT$|^GOOGLE_CLOUD_PROJECT$|^GCP_PROJECT$|^CLOUDSDK_CORE_PROJECT$|^FIREBASE_CONFIG$|^GOOGLE_APPLICATION_CREDENTIALS$)/i.test(k)),
  );
  return spawnSync(process.execPath, ["--import", egressPreload, scriptPath, ...argv], {
    env: { ...env, MIGRATE_IT_ALLOWED_PORTS: emulatorPort, METADATA_SERVER_DETECTION: "none", ...extraEnv },
    encoding: "utf8",
    timeout: 60_000,
  });
}

test("CLI: dry run by default, then confirmed apply on the emulator demo", async () => {
  await seed();
  const before = await dump();
  const dry = cli(["--project", WRITE_PROJECT], {});
  assert.equal(dry.status, 0, dry.stderr);
  assert.equal(JSON.parse(dry.stdout).mode, "dry-run");
  assert.equal(await dump(), before);

  const applied = cli(["--project", WRITE_PROJECT, "--apply", "--confirm", `${SCRIPT_ID}:${WRITE_PROJECT}`], {});
  assert.equal(applied.status, 0, applied.stderr);
  const report = JSON.parse(applied.stdout);
  assert.equal(report.mode, "apply");
  assert.equal(report.written.claimed, 3);
  assert.doesNotMatch(applied.stderr, /egress blocked/);
  assertNoLeak(dry.stdout + dry.stderr + applied.stdout + applied.stderr, "CLI output");
});

test("CLI: rafiq-academy and other projects are refused even with the emulator up", async () => {
  await seed();
  const before = await dump();
  for (const project of ["rafiq-academy", "demo-other"]) {
    const res = cli(["--project", project, "--apply", "--confirm", `${SCRIPT_ID}:${project}`], {});
    assert.equal(res.status, 2, project);
    assert.match(res.stderr, /refused:/);
    assert.equal(res.stdout, "");
  }
  const mismatch = cli(
    ["--project", WRITE_PROJECT, "--apply", "--confirm", `${SCRIPT_ID}:${WRITE_PROJECT}`],
    { GCLOUD_PROJECT: "rafiq-academy" },
  );
  assert.equal(mismatch.status, 2);
  assert.equal(await dump(), before);
});
