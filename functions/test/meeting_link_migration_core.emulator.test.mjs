/**
 * B14 meeting-link migration core — Firestore behaviour the pure decisions
 * rely on, checked against the real Admin SDK and an isolated Firestore
 * emulator (`demo-rafiq-rules`, non-default ports). Synthetic data only;
 * build functions first.
 *
 * The adapter below is test-only: it wires the core decisions into
 * transactions so lock contention, write fencing, ambiguous commits, document
 * metadata and rollback evidence can be observed. It is not a migration
 * entry point and has no delete path. Emulator results are evidence for the
 * emulator only; production Firestore semantics remain unverified until
 * observed there.
 *
 *   MEETING_LINK_MIGRATION_EMULATOR=1 MEETING_LINK_MIGRATION_PORTS=38180,34480 \
 *   firebase emulators:exec --config <isolated firebase.json> \
 *     --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 test/meeting_link_migration_core.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";
import { EMULATOR_PROJECT, safeErrorCode } from "../scripts/migrate-meeting-links.mjs";
import {
  CANONICAL_SCHEMA_VERSION,
  MIGRATION_ID,
  abandonConfirmationToken,
  applyEvidencePaths,
  buildMigrationPlan,
  classifyCanonical,
  classifyErrorCode,
  classifyLegacy,
  decideCandidateWrite,
  decideLockAcquisition,
  decideLockRelease,
  decideRollbackDelete,
  detectPlanDrift,
  lockPaths,
  observedRecordFields,
  openPlan,
  outcomeRecordFields,
  planRecordFromScan,
  resolveUncertainCommit,
  rollbackEvidencePaths,
  runPaths,
  sha256Hex,
  timeKey,
} from "../scripts/meeting-link-migration-core.mjs";

const PORTS = String(process.env.MEETING_LINK_MIGRATION_PORTS ?? "").split(",").map(Number);
const [FS_PORT, HUB_PORT] = PORTS;
{
  const problems = [];
  if (process.env.MEETING_LINK_MIGRATION_EMULATOR !== "1") problems.push("MEETING_LINK_MIGRATION_EMULATOR must be 1");
  if (PORTS.length !== 2 || PORTS.some((p) => !Number.isInteger(p) || p < 1024 || p > 65535)) {
    problems.push("MEETING_LINK_MIGRATION_PORTS must be firestore,hub");
  }
  if (PORTS.some((p) => [8080, 4400, 4000, 4500, 5001, 9099, 9199, 9150].includes(p))) {
    problems.push("default (possibly shared) emulator ports are refused");
  }
  if (process.env.FIRESTORE_EMULATOR_HOST !== `127.0.0.1:${FS_PORT}`) problems.push("FIRESTORE_EMULATOR_HOST mismatch");
  if (process.env.FIREBASE_EMULATOR_HUB !== `127.0.0.1:${HUB_PORT}`) problems.push("FIREBASE_EMULATOR_HUB mismatch");
  for (const key of ["GCLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT"]) {
    if (process.env[key] && process.env[key] !== EMULATOR_PROJECT) problems.push(`${key} is not ${EMULATOR_PROJECT}`);
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) problems.push("GOOGLE_APPLICATION_CREDENTIALS must be unset");
  if (problems.length > 0) throw new Error(`B14 migration core emulator suite refused: ${problems.join("; ")}`);
}

process.env.METADATA_SERVER_DETECTION = "none";
const guard = installEgressGuard({ allowedPorts: [FS_PORT, HUB_PORT] });
assert.equal(await guard.selfTest(), true, "egress guard must be active");

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const admin = require("firebase-admin");
admin.initializeApp({ projectId: EMULATOR_PROJECT });
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;
const { meetingLinkIssue, canonicalMeetingLinkData, setHalaqaMeetingLinkCore } = require("../lib/halaqa/meetingLinkFunctions.js");

const MARK = "zqcoreemu";
const LINK_A = `https://meet.example.test/${MARK}-a`;
const LINK_B = `https://video.example.org/j/${MARK}-b`;
const FORBIDDEN = [MARK, "://", "example.test", "example.org"];
const RUN_A = "run-core-emu-a";
const RUN_B = "run-core-emu-b";
const RB = "rb-core-emu-01";
const outputs = [];

// Hashes of the files this suite loads; a real runner must hash what it
// actually executes before any write (future prerequisite).
const fileHash = (...parts) => sha256Hex(readFileSync(join(here, "..", ...parts)));
const IDENTITY = { projectId: EMULATOR_PROJECT, databaseId: "(default)", migrationId: MIGRATION_ID };
const VERSIONS = {
  entryPoint: fileHash("scripts", "migrate-meeting-links.mjs"),
  core: fileHash("scripts", "meeting-link-migration-core.mjs"),
  adapter: fileHash("test", "meeting_link_migration_core.emulator.test.mjs"),
  validator: fileHash("lib", "halaqa", "meetingLinkFunctions.js"),
  canonicalSchema: CANONICAL_SCHEMA_VERSION,
};
/** Connection target as reported by the SDK, not by the plan. */
const sdkConnection = () => ({ projectId: admin.app().options.projectId, databaseId: db.databaseId });

function assertNoLinks(value, label) {
  const text = typeof value === "string" ? value : JSON.stringify(value);
  for (const needle of FORBIDDEN) assert.equal(text.includes(needle), false, `${label} contains ${needle}`);
}

async function clearFirestore() {
  const res = await fetch(
    `http://127.0.0.1:${FS_PORT}/emulator/v1/projects/${EMULATOR_PROJECT}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed(docs) {
  const batch = db.batch();
  for (const [path, data] of Object.entries(docs)) batch.set(db.doc(path), data);
  await batch.commit();
}

const delay = (ms) => new Promise((done) => setTimeout(done, ms));
const H = (id) => db.collection("halaqat").doc(id);
const L = (id) => db.collection("halaqaMeetingLinks").doc(id);
const view = (snap) => ({
  exists: snap.exists,
  data: snap.exists ? snap.data() : undefined,
  createTime: snap.createTime,
  updateTime: snap.updateTime,
});
const isTimestamp = (v) => v instanceof Timestamp;
const earlier = (a, b) => a.seconds < b.seconds || (a.seconds === b.seconds && a.nanoseconds < b.nanoseconds);
const once = (hook) => {
  let fired = false;
  return hook ? async () => { if (!fired) { fired = true; await hook(); } } : null;
};
const applyWriter = (runId, generation, planDigest) => ({ kind: "apply", runId, generation, planDigest, targetRunId: null });
const rollbackWriter = (generation, planDigest, runId = RB, targetRunId = RUN_A) => ({ kind: "rollback", runId, generation, planDigest, targetRunId });

/** Reads every path of `paths` inside `tx` and returns the core's read-set shape. */
async function readSetIn(tx, paths) {
  const entries = Object.values(paths);
  const snaps = await tx.getAll(...entries.map((path) => db.doc(path)));
  return {
    transactionId: randomUUID(),
    connection: sdkConnection(),
    docs: Object.fromEntries(entries.map((path, i) => [path, view(snaps[i])])),
  };
}

// ── test-only adapter around the core decisions ────────────────────────────

async function acquireLock({ writer, validatedPlan = null }) {
  const { lock } = lockPaths(writer.generation);
  const runPath = runPaths(writer.runId).run;
  try {
    return await db.runTransaction(async (tx) => {
      const refs = [db.doc(lock), db.doc(runPath)];
      if (writer.generation > 1) refs.push(db.doc(lockPaths(writer.generation - 1).release));
      if (writer.kind === "rollback") refs.push(db.doc(runPaths(writer.targetRunId).run));
      const snaps = await tx.getAll(...refs);
      const [current, runClaim] = snaps;
      const previous = writer.generation > 1 ? snaps[2] : null;
      const target = writer.kind === "rollback" ? snaps[snaps.length - 1] : null;
      const decision = decideLockAcquisition({
        writer,
        identity: IDENTITY,
        validatedPlan,
        current: view(current),
        previousRelease: previous ? view(previous) : null,
        runClaim: view(runClaim),
        targetRun: target ? view(target) : undefined,
      });
      if (decision.acquire) {
        tx.create(db.doc(decision.lockPath), decision.lockData);
        tx.create(db.doc(decision.runPath), decision.runData);
      }
      return decision;
    });
  } catch (error) {
    if (safeErrorCode(error) === "already-exists") return { acquire: false, reason: "create_conflict" };
    throw error;
  }
}

async function releaseLock({ generation, request }) {
  const paths = lockPaths(generation);
  return db.runTransaction(async (tx) => {
    const [lock, release] = await tx.getAll(db.doc(paths.lock), db.doc(paths.release));
    const decision = decideLockRelease({ lock: view(lock), release: view(release), request });
    if (decision.release) tx.create(db.doc(paths.release), { ...decision.data, releasedAt: FieldValue.serverTimestamp() });
    return decision;
  });
}

const PERSISTED_IN_TX = new Set(["migrated", "halaqaGone", "canonicalAppeared", "changedSinceReview", "legacyNoLongerValid", "metadataUnavailable"]);

/**
 * One fenced candidate write. Every doc the decision depends on is read in
 * the same transaction; the canonical doc, its manifest entry and the
 * per-record outcome commit together. Fenced, expired or rejected decisions
 * write nothing.
 */
async function migrateFenced({ validatedPlan, halaqaId, writer, afterRead = null, now = () => Date.now() }) {
  const hook = once(afterRead);
  const run = runPaths(writer.runId);
  return db.runTransaction(
    async (tx) => {
      const readSet = await readSetIn(tx, applyEvidencePaths({ writer, halaqaId }));
      if (hook) await hook();
      const halaqa = readSet.docs[`halaqat/${halaqaId}`];
      const legacy = halaqa?.exists ? classifyLegacy(halaqa.data, meetingLinkIssue) : { category: "missing" };
      const decision = decideCandidateWrite({ validatedPlan, halaqaId, now: now(), writer, readSet, legacyCategory: legacy.category });
      const outcome = decision.write ? decision.outcomeIfCommitted : decision.outcome;
      if (decision.write) {
        tx.create(L(halaqaId), canonicalMeetingLinkData(legacy.value));
        tx.create(db.doc(run.entry(halaqaId)), { ...decision.manifestEntry, createdAt: FieldValue.serverTimestamp() });
      }
      if (PERSISTED_IN_TX.has(outcome)) {
        tx.create(db.doc(run.outcome(halaqaId)), outcomeRecordFields({ runId: writer.runId, halaqaId, planDigest: writer.planDigest, outcome, reason: decision.reason }));
      }
      return decision;
    },
    { maxAttempts: 5 },
  );
}

async function captureObserved({ runId, halaqaId }) {
  const snap = await L(halaqaId).get();
  const data = observedRecordFields({ runId, halaqaId, canonical: view(snap) });
  if (data) await db.doc(runPaths(runId).observed(halaqaId)).create(data);
  return data;
}

/** Rollback decision for one doc. Reads the rollback writer's own stop doc; has no delete path. */
async function rollbackOne({ writer, halaqaId, afterRead = null, maxObservationDelayMs, interveningActionProof }) {
  const hook = once(afterRead);
  return db.runTransaction(async (tx) => {
    const readSet = await readSetIn(tx, rollbackEvidencePaths({ writer, halaqaId }));
    if (hook) await hook();
    return decideRollbackDelete({ writer, halaqaId, readSet, identity: IDENTITY, maxObservationDelayMs, interveningActionProof });
  });
}

async function resolveAfterUncertainty({ writer, halaqaId }) {
  const [entry, link] = await db.getAll(db.doc(runPaths(writer.runId).entry(halaqaId)), L(halaqaId));
  return resolveUncertainCommit({ writer, halaqaId, entry: view(entry), canonical: view(link) });
}

async function scanRecords() {
  const records = [];
  const halaqat = await db.collection("halaqat").get();
  for (const doc of halaqat.docs) {
    const link = await L(doc.id).get();
    records.push(
      planRecordFromScan({
        halaqaId: doc.id,
        legacy: classifyLegacy(doc.data(), meetingLinkIssue),
        canonical: link.exists ? classifyCanonical(link.data(), meetingLinkIssue, isTimestamp) : null,
        halaqaUpdateTime: doc.updateTime,
        canonicalUpdateTime: link.exists ? link.updateTime : null,
      }),
    );
  }
  return records;
}

/** Dry-run plan, then the approval step: the reviewed digest is passed back explicitly. */
async function reviewedPlan() {
  const plan = buildMigrationPlan({ identity: IDENTITY, versions: VERSIONS, mode: "apply", issuedAt: Date.now(), records: await scanRecords() });
  const approvedDigest = plan.digest;
  const opened = openPlan(plan, { expected: { identity: IDENTITY, versions: VERSIONS, mode: "apply", approvedDigest }, now: Date.now() });
  assert.deepEqual(opened.problems ?? [], []);
  outputs.push({ label: "plan", text: JSON.stringify(plan) });
  return { plan, handle: opened.plan };
}

/** Seeds candidate halaqat, reviews a plan and takes apply lock generation 1 for RUN_A. */
async function candidateWithLock(ids = ["hCand"]) {
  const docs = { "users/admin1": { role: "admin", isActive: true } };
  for (const id of ids) docs[`halaqat/${id}`] = { meetingLink: LINK_A, supervisorId: "" };
  await seed(docs);
  const { plan, handle } = await reviewedPlan();
  const writer = applyWriter(RUN_A, 1, handle.digest);
  assert.equal((await acquireLock({ writer, validatedPlan: handle })).acquire, true);
  return { plan, handle, writer };
}

/** Migrates hCand under lock 1 and captures its observed metadata. */
async function migratedWithEvidence({ observeAfterMs = 0 } = {}) {
  const ctx = await candidateWithLock();
  const decision = await migrateFenced({ validatedPlan: ctx.handle, halaqaId: "hCand", writer: ctx.writer });
  assert.equal(decision.write, true);
  if (observeAfterMs > 0) await delay(observeAfterMs);
  assert.ok(await captureObserved({ runId: RUN_A, halaqaId: "hCand" }));
  return ctx;
}

/** Releases apply lock 1 and takes rollback lock 2 targeting RUN_A. */
async function rollbackLock(planDigest) {
  assert.equal((await releaseLock({ generation: 1, request: { reason: "completed", runId: RUN_A } })).release, true);
  const writer = rollbackWriter(2, planDigest);
  const acquired = await acquireLock({ writer });
  assert.equal(acquired.acquire, true, acquired.reason);
  return writer;
}

async function migrationDataSnapshot() {
  const out = {};
  for (const name of ["halaqat", "halaqaMeetingLinks"]) {
    for (const doc of (await db.collection(name).get()).docs) out[doc.ref.path] = timeKey(doc.updateTime);
  }
  return out;
}

test.beforeEach(async () => {
  await clearFirestore();
});

test("isolation: the hub lists only this run's Firestore; the SDK target matches the plan identity", async () => {
  const listing = await (await fetch(`http://127.0.0.1:${HUB_PORT}/emulators`)).json();
  assert.equal(listing.firestore.port, FS_PORT);
  assert.equal(listing.hub.port, HUB_PORT);
  for (const other of ["auth", "functions", "storage", "database", "pubsub", "hosting"]) {
    assert.equal(listing[other], undefined, `${other} emulator must not run`);
  }
  assert.deepEqual(sdkConnection(), { projectId: IDENTITY.projectId, databaseId: IDENTITY.databaseId });
});

// ── metadata semantics and rollback ────────────────────────────────────────

test("metadata: a migrated doc is never-updated and shares the entry's createTime and server timestamp; rollback still does not delete", async () => {
  const ctx = await migratedWithEvidence();
  const [link, entry, outcome] = await db.getAll(L("hCand"), db.doc(runPaths(RUN_A).entry("hCand")), db.doc(runPaths(RUN_A).outcome("hCand")));
  assert.equal(timeKey(link.createTime), timeKey(link.updateTime), "createTime == updateTime for a fresh doc");
  assert.equal(timeKey(link.data().updatedAt), timeKey(entry.data().createdAt), "same-commit server timestamps are equal");
  assert.equal(timeKey(link.createTime), timeKey(entry.createTime), "canonical and manifest createTime equal within one transaction");
  assert.deepEqual(Object.keys(link.data()).sort(), ["meetingLink", "updatedAt"], "no migration fields in the canonical doc");
  assert.equal(entry.data().planDigest, ctx.handle.digest, "manifest entry is bound to the plan digest");
  assert.equal(outcome.data().outcome, "migrated", "per-record outcome committed with the write");

  const writer = await rollbackLock(ctx.handle.digest);
  const result = await rollbackOne({ writer, halaqaId: "hCand" });
  assert.deepEqual(result, { delete: false, outcome: "skipped", reason: "admin_resave_unprovable", recommendation: "forward_fix", evidenceComplete: true });
  assert.equal((await L("hCand").get()).exists, true, "complete evidence still deletes nothing");

  const evidence = [];
  for (const path of [
    runPaths(RUN_A).run,
    runPaths(RUN_A).entry("hCand"),
    runPaths(RUN_A).observed("hCand"),
    runPaths(RUN_A).outcome("hCand"),
    runPaths(RB).run,
    lockPaths(1).lock,
    lockPaths(1).release,
    lockPaths(2).lock,
  ]) {
    const snap = await db.doc(path).get();
    assert.equal(snap.exists, true, path);
    evidence.push(snap.data());
  }
  assertNoLinks(evidence, "run, manifest, observed, outcome and lock records");
  outputs.push({ label: "rollback complete evidence", text: JSON.stringify(result) });
});

test("rollback evidence is incomplete for every doc changed after migration: callable update, console edit, recreate, clear", async () => {
  const cases = {
    callableUpdate: { change: () => setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hCand", meetingLink: LINK_B }), reason: "modified_since_creation" },
    consoleEdit: { change: () => L("hCand").update({ meetingLink: LINK_B }), reason: "modified_since_creation" },
    recreateIdentical: {
      change: async () => {
        const data = (await L("hCand").get()).data();
        await L("hCand").delete();
        await L("hCand").create(data);
      },
      reason: "create_time_mismatch",
    },
    callableClear: { change: () => setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hCand", clear: true }), reason: "canonical_missing" },
  };
  for (const [name, { change, reason }] of Object.entries(cases)) {
    await clearFirestore();
    const ctx = await migratedWithEvidence();
    await change();
    const before = await L("hCand").get();
    const writer = await rollbackLock(ctx.handle.digest);
    const result = await rollbackOne({ writer, halaqaId: "hCand" });
    assert.deepEqual(result, { delete: false, outcome: "skipped", reason, recommendation: "forward_fix", evidenceComplete: false }, name);
    const after = await L("hCand").get();
    assert.equal(after.exists, before.exists, `${name}: nothing deleted`);
    if (before.exists) assert.equal(timeKey(after.updateTime), timeKey(before.updateTime), `${name}: doc untouched`);
    outputs.push({ label: `rollback ${name}`, text: JSON.stringify(result) });
  }
});

test("A1 regression: an unchanged admin re-save leaves no trace, so rollback refuses instead of deleting the admin's link", async () => {
  const ctx = await migratedWithEvidence();
  const before = await migrationDataSnapshot();
  const auditBefore = (await db.collection("auditLogs").get()).size;
  const resave = await setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hCand", meetingLink: LINK_A });
  assert.equal(resave.operation, "unchanged");
  assert.deepEqual(await migrationDataSnapshot(), before, "the re-save wrote nothing to the halaqa or canonical doc");
  assert.equal((await db.collection("auditLogs").get()).size, auditBefore, "the re-save left no audit entry");

  const writer = await rollbackLock(ctx.handle.digest);
  const result = await rollbackOne({ writer, halaqaId: "hCand" });
  assert.equal(result.delete, false);
  assert.equal(result.reason, "admin_resave_unprovable");
  assert.equal((await rollbackOne({ writer, halaqaId: "hCand", interveningActionProof: { kind: "auditTrail" } })).reason, "proof_kind_not_approved");
  assert.equal((await L("hCand").get()).data().meetingLink, LINK_A, "the admin-confirmed link survives");
});

test("B4: a missing or late observed record makes rollback evidence incomplete", async () => {
  const late = await migratedWithEvidence({ observeAfterMs: 1200 });
  const writer = await rollbackLock(late.handle.digest);
  assert.equal((await rollbackOne({ writer, halaqaId: "hCand", maxObservationDelayMs: 1000 })).reason, "observation_late");
  assert.equal((await rollbackOne({ writer, halaqaId: "hCand", maxObservationDelayMs: 60_001 })).reason, "observation_window_invalid");

  await clearFirestore();
  const ctx = await candidateWithLock();
  assert.equal((await migrateFenced({ validatedPlan: ctx.handle, halaqaId: "hCand", writer: ctx.writer })).write, true);
  const rbWriter = await rollbackLock(ctx.handle.digest);
  assert.equal((await rollbackOne({ writer: rbWriter, halaqaId: "hCand" })).reason, "observed_missing");
  assert.equal((await L("hCand").get()).exists, true);
});

test("A8: the rollback fence reads the rollback run's own stop doc, not the apply run's", async () => {
  const ctx = await migratedWithEvidence();
  const writer = await rollbackLock(ctx.handle.digest);
  await db.doc(runPaths(RUN_A).stop).create({ at: FieldValue.serverTimestamp() });
  assert.equal((await rollbackOne({ writer, halaqaId: "hCand" })).reason, "admin_resave_unprovable", "the apply run's stop does not fence the rollback");
  await db.doc(runPaths(RB).stop).create({ at: FieldValue.serverTimestamp() });
  assert.deepEqual(
    (({ outcome, reason }) => ({ outcome, reason }))(await rollbackOne({ writer, halaqaId: "hCand" })),
    { outcome: "fenced", reason: "stop_requested" },
  );
});

test("Firestore semantics probe (not a rollback path): a delete pinned to lastUpdateTime and a concurrent edit never both succeed", async () => {
  const seen = [];
  for (let round = 0; round < 8; round += 1) {
    await clearFirestore();
    await seed({ "halaqaMeetingLinks/hProbe": { meetingLink: LINK_A, updatedAt: FieldValue.serverTimestamp() } });
    let competing = null;
    const probe = db
      .runTransaction(async (tx) => {
        const snap = await tx.get(L("hProbe"));
        competing = L("hProbe").update({ meetingLink: LINK_B }).then(
          () => "fulfilled",
          (error) => `rejected:${safeErrorCode(error)}`,
        );
        await (round >= 4 ? Promise.race([competing, delay(2000)]) : delay(30));
        tx.delete(L("hProbe"), { lastUpdateTime: snap.updateTime });
      })
      .then(
        () => "deleted",
        (error) => `rejected:${safeErrorCode(error)}`,
      );
    const [outcome, edit] = [await probe, await competing];
    const link = await L("hProbe").get();
    seen.push(`${outcome}/${edit}`);
    if (edit === "fulfilled") {
      assert.equal(link.exists, true, `round ${round}: edited doc deleted`);
      assert.equal(link.data().meetingLink, LINK_B, `round ${round}`);
    } else {
      assert.equal(link.exists, false, `round ${round}: edit failed but doc survived`);
      assert.equal(outcome, "deleted", `round ${round}`);
    }
  }
  console.log(`precondition-delete probe outcomes (delete/edit): ${seen.join(", ")}`);
});

// ── locks and fencing ──────────────────────────────────────────────────────

test("lock contention: six workers race for generation 1, exactly one wins, migration data untouched", async () => {
  await seed({ "halaqat/hX": { meetingLink: LINK_A }, "halaqaMeetingLinks/hY": { meetingLink: LINK_B, updatedAt: FieldValue.serverTimestamp() } });
  const { handle } = await reviewedPlan();
  const before = await migrationDataSnapshot();
  const runs = Array.from({ length: 6 }, (_, i) => `run-core-emu-w${i}`);
  const results = await Promise.all(runs.map((runId) => acquireLock({ writer: applyWriter(runId, 1, handle.digest), validatedPlan: handle })));
  const winners = results.filter((r) => r.acquire);
  assert.equal(winners.length, 1, JSON.stringify(results.map((r) => r.reason ?? "acquired")));
  for (const r of results) if (!r.acquire) assert.ok(["generation_taken", "create_conflict"].includes(r.reason), r.reason);
  assert.equal((await db.doc(lockPaths(1).lock).get()).data().runId, winners[0].lockData.runId);
  assert.deepEqual(await migrationDataSnapshot(), before);
  console.log(`lock contention outcomes: ${results.map((r) => (r.acquire ? "acquired" : r.reason)).join(", ")}`);
});

test("locks: no automatic expiry; release or confirmed abandonment; run ids are single-use; rollback is bound to its target run", async () => {
  await seed({ "halaqat/hX": { meetingLink: LINK_A } });
  const { handle } = await reviewedPlan();
  const writerA = applyWriter(RUN_A, 1, handle.digest);
  assert.equal((await acquireLock({ writer: writerA, validatedPlan: handle })).acquire, true);
  assert.equal((await acquireLock({ writer: applyWriter(RUN_B, 2, handle.digest), validatedPlan: handle })).reason, "previous_generation_not_released");
  assert.equal((await releaseLock({ generation: 1, request: { reason: "completed", runId: RUN_B } })).reason, "not_lock_owner");
  assert.equal((await releaseLock({ generation: 1, request: { reason: "operator_abandoned" } })).reason, "human_confirmation_required");
  assert.equal(
    (await releaseLock({ generation: 1, request: { reason: "operator_abandoned", humanConfirmed: true, confirmation: "yes" } })).reason,
    "human_confirmation_required",
  );
  assert.equal((await db.doc(lockPaths(1).release).get()).exists, false);
  const abandoned = await releaseLock({
    generation: 1,
    request: { reason: "operator_abandoned", humanConfirmed: true, confirmation: abandonConfirmationToken(1, RUN_A) },
  });
  assert.equal(abandoned.release, true);
  assert.equal((await releaseLock({ generation: 1, request: { reason: "completed", runId: RUN_A } })).reason, "already_released");
  assert.equal((await acquireLock({ writer: applyWriter(RUN_B, 1, handle.digest), validatedPlan: handle })).reason, "generation_taken");
  assert.equal((await acquireLock({ writer: applyWriter(RUN_A, 2, handle.digest), validatedPlan: handle })).reason, "run_id_reused");
  assert.equal((await acquireLock({ writer: applyWriter(RUN_B, 2, "f".repeat(64)), validatedPlan: handle })).reason, "plan_digest_mismatch");
  assert.equal((await acquireLock({ writer: rollbackWriter(2, "f".repeat(64)) })).reason, "rollback_target_invalid");
  assert.equal((await acquireLock({ writer: rollbackWriter(2, handle.digest, RB, "run-core-emu-none") })).reason, "rollback_target_missing");
  assert.equal((await db.doc(lockPaths(2).lock).get()).exists, false, "refused acquisitions created nothing");
  assert.equal((await acquireLock({ writer: rollbackWriter(2, handle.digest) })).acquire, true);
});

test("stale-worker fencing: release, missing lock, other owner, other kind and own stop request all block the write", async () => {
  const { handle, writer } = await candidateWithLock();
  const migrate = (w) => migrateFenced({ validatedPlan: handle, halaqaId: "hCand", writer: w });
  await releaseLock({ generation: 1, request: { reason: "operator_abandoned", humanConfirmed: true, confirmation: abandonConfirmationToken(1, RUN_A) } });
  assert.deepEqual(await migrate(writer), { write: false, outcome: "fenced", reason: "lock_released" });
  assert.deepEqual(await migrate(applyWriter(RUN_A, 2, handle.digest)), { write: false, outcome: "fenced", reason: "lock_missing" });
  assert.equal((await L("hCand").get()).exists, false);

  assert.equal((await acquireLock({ writer: rollbackWriter(2, handle.digest, RUN_B, RUN_A) })).acquire, true);
  assert.deepEqual(await migrate(applyWriter(RUN_A, 2, handle.digest)), { write: false, outcome: "fenced", reason: "lock_owner_mismatch" });
  assert.deepEqual(await migrate(applyWriter(RUN_B, 2, handle.digest)), { write: false, outcome: "fenced", reason: "lock_kind_mismatch" });
  await releaseLock({ generation: 2, request: { reason: "completed", runId: RUN_B } });

  const writerC = applyWriter("run-core-emu-c", 3, handle.digest);
  assert.equal((await acquireLock({ writer: writerC, validatedPlan: handle })).acquire, true);
  await db.doc(runPaths(RUN_A).stop).create({ at: FieldValue.serverTimestamp() });
  await db.doc(runPaths(writerC.runId).stop).create({ at: FieldValue.serverTimestamp() });
  assert.deepEqual(await migrate(writerC), { write: false, outcome: "fenced", reason: "stop_requested" });
  assert.equal((await L("hCand").get()).exists, false, "no write while fenced");
  assert.equal((await db.doc(runPaths(writerC.runId).outcome("hCand")).get()).exists, false, "fenced decisions persist nothing");
});

test("fencing race (8 rounds): no canonical write commits after a release or stop request commits", async () => {
  const seen = [];
  for (let round = 0; round < 8; round += 1) {
    await clearFirestore();
    const { handle, writer } = await candidateWithLock();
    const viaStop = round % 2 === 1;
    const fencePath = viaStop ? runPaths(RUN_A).stop : lockPaths(1).release;
    let competing = null;
    const migration = migrateFenced({
      validatedPlan: handle,
      halaqaId: "hCand",
      writer,
      afterRead: async () => {
        competing = (
          viaStop
            ? db.doc(fencePath).create({ at: FieldValue.serverTimestamp() })
            : releaseLock({ generation: 1, request: { reason: "operator_abandoned", humanConfirmed: true, confirmation: abandonConfirmationToken(1, RUN_A) } })
        ).then(
          () => "fulfilled",
          (error) => `rejected:${safeErrorCode(error)}`,
        );
        await (round >= 4 ? Promise.race([competing, delay(2000)]) : delay(30));
      },
    }).then(
      (d) => (d.write ? "written" : `${d.outcome}:${d.reason ?? ""}`),
      (error) => `rejected:${safeErrorCode(error)}`,
    );
    const [outcome, fenceWrite] = [await migration, await competing];
    const [link, fence, entry] = await db.getAll(L("hCand"), db.doc(fencePath), db.doc(runPaths(RUN_A).entry("hCand")));
    seen.push(`${viaStop ? "stop" : "release"}:${outcome}/${fenceWrite}`);
    assert.equal(link.exists, entry.exists, `round ${round}: canonical and manifest entry commit together`);
    if (link.exists && fence.exists) {
      assert.ok(earlier(link.createTime, fence.createTime), `round ${round}: a write committed after the fence`);
    }
    if (!link.exists) assert.notEqual(outcome, "written", `round ${round}`);
  }
  console.log(`fencing race outcomes (fence:migration/fence write): ${seen.join(", ")}`);
});

// ── drift, expiry and ambiguous commits ────────────────────────────────────

test("drift and expiry: a source change after review is changedSinceReview; an expired plan writes nothing", async () => {
  await seed({ "halaqat/hDrift": { meetingLink: LINK_A, name: "n1" }, "halaqat/hSteady": { meetingLink: LINK_B }, "halaqat/hLate": { meetingLink: LINK_A } });
  const { plan, handle } = await reviewedPlan();
  const writer = applyWriter(RUN_A, 1, handle.digest);
  assert.equal((await acquireLock({ writer, validatedPlan: handle })).acquire, true);
  await H("hDrift").update({ name: "n2" });
  const drift = detectPlanDrift(plan, await scanRecords());
  assert.equal(drift.replanRequired, false);
  assert.deepEqual(drift.changedSinceReview, ["hDrift"]);
  assert.deepEqual(await migrateFenced({ validatedPlan: handle, halaqaId: "hDrift", writer }), { write: false, outcome: "changedSinceReview", reason: null });
  assert.equal((await L("hDrift").get()).exists, false);
  assert.equal((await db.doc(runPaths(RUN_A).outcome("hDrift")).get()).data().outcome, "changedSinceReview");
  assert.equal((await migrateFenced({ validatedPlan: handle, halaqaId: "hSteady", writer })).write, true);

  const expired = await migrateFenced({ validatedPlan: handle, halaqaId: "hLate", writer, now: () => handle.expiresAt });
  assert.deepEqual(expired, { write: false, outcome: "planExpired", reason: "expired" });
  assert.equal((await L("hLate").get()).exists, false);

  await seed({ "halaqat/hNew": { meetingLink: LINK_A } });
  assert.ok(detectPlanDrift(plan, await scanRecords()).reasons.includes("record_added"));
  assert.deepEqual(await migrateFenced({ validatedPlan: handle, halaqaId: "hNew", writer }), { write: false, outcome: "rejected", reason: "candidate_not_in_plan" });
  assert.equal((await L("hNew").get()).exists, false);
});

test("B5 ambiguous commit: a manifest entry verifies the commit; a missing entry never authorizes a write", async () => {
  const { handle, writer } = await candidateWithLock(["hCand", "hOther"]);
  const lost = await migrateFenced({ validatedPlan: handle, halaqaId: "hCand", writer }).then(() => {
    throw Object.assign(new Error("response lost"), { code: 4 });
  }).catch((error) => classifyErrorCode(safeErrorCode(error)));
  assert.equal(lost, "ambiguous");
  const verified = await resolveAfterUncertainty({ writer, halaqaId: "hCand" });
  assert.deepEqual([verified.outcome, verified.evidence, verified.canonicalState], ["committedAfterAmbiguity", "committedVerified", "presentUnmodified"]);

  await setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hCand", meetingLink: LINK_B });
  assert.equal((await resolveAfterUncertainty({ writer, halaqaId: "hCand" })).canonicalState, "presentModified");
  await setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hCand", clear: true });
  assert.equal((await resolveAfterUncertainty({ writer, halaqaId: "hCand" })).canonicalState, "absentAfterCommit");
  await setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hCand", meetingLink: LINK_A });
  assert.equal((await resolveAfterUncertainty({ writer, halaqaId: "hCand" })).canonicalState, "presentReplaced");

  await db.doc(runPaths(RUN_A).entry("hCand")).delete();
  const deletedEntry = await resolveAfterUncertainty({ writer, halaqaId: "hCand" });
  assert.deepEqual([deletedEntry.outcome, deletedEntry.reason], ["unresolved", "manifest_absent_canonical_present"]);
  assert.equal(deletedEntry.authorizesWrite, false);
  assert.equal(deletedEntry.authorizesDelete, false);

  const absent = await resolveAfterUncertainty({ writer, halaqaId: "hOther" });
  assert.deepEqual([absent.outcome, absent.reason, absent.action], ["unresolved", "manifest_absent_canonical_absent", "replan"]);
  await setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hOther", meetingLink: LINK_B });
  const adminDoc = await L("hOther").get();
  assert.equal((await resolveAfterUncertainty({ writer, halaqaId: "hOther" })).reason, "manifest_absent_canonical_present");
  const retry = await migrateFenced({ validatedPlan: handle, halaqaId: "hOther", writer });
  assert.deepEqual(retry, { write: false, outcome: "canonicalAppeared", reason: null });
  const afterRetry = await L("hOther").get();
  assert.equal(timeKey(afterRetry.updateTime), timeKey(adminDoc.updateTime), "admin's doc not overwritten");
  assert.equal(afterRetry.data().meetingLink, LINK_B);
  outputs.push({ label: "ambiguous", text: JSON.stringify([verified, deletedEntry, absent, retry]) });
});

test("redaction: plans, decisions and reports collected in this suite contain no link values", () => {
  assert.ok(outputs.length >= 5, "outputs were collected");
  for (const { label, text } of outputs) assertNoLinks(text, label);
});

test("no connection outside the isolated emulator was attempted by the test process", () => {
  assert.deepEqual(guard.blockedAttempts(), []);
});
