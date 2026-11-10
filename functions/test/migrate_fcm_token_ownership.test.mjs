// FCM token ownership backfill: guards, classification and the runner
// against an in-memory Firestore stand-in. Synthetic data only; no network,
// no emulator, no firebase-admin.
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
  GROUP,
  SCRIPT_ID,
  WRITE_PROJECT,
  applyTargetProblems,
  assertEmulatorWriteTarget,
  classifyTokenGroup,
  isUsableToken,
  parseDevicePath,
  runTokenOwnershipBackfill,
  tokenHash,
} from "../scripts/migrate-fcm-token-ownership.mjs";
import { checkMigrationTarget, parseMigrationArgs } from "../scripts/migrate-guards.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const scriptPath = join(here, "..", "scripts", "migrate-fcm-token-ownership.mjs");
const noAdminPreload = pathToFileURL(join(here, "migrate-no-admin-preload.mjs")).href;
const require = createRequire(import.meta.url);

const DOCUMENT_ID = Symbol("documentId");
const EMU = { FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" };

// ── in-memory Firestore slice: collectionGroup scan, refs, getAll ──────────
class Db {
  constructor() {
    this.docs = new Map();
    this.clock = 0;
    this.reads = 0;
  }
  put(path, data, seconds) {
    const t = seconds ?? ++this.clock;
    this.docs.set(path, { data: structuredClone(data), updateTime: { seconds: t, nanoseconds: 0 } });
  }
  snap(path) {
    const entry = this.docs.get(path);
    return {
      id: path.split("/").pop(),
      ref: { path },
      exists: entry !== undefined,
      updateTime: entry?.updateTime,
      data: () => (entry ? structuredClone(entry.data) : undefined),
    };
  }
  collection(name) {
    return new Ref(name);
  }
  collectionGroup(id) {
    return new GroupQuery(this, id, Infinity, null, false);
  }
  async getAll(...refs) {
    this.reads += refs.length;
    return refs.map((r) => this.snap(r.path));
  }
  dump() {
    return JSON.stringify([...this.docs].sort(([a], [b]) => (a < b ? -1 : 1)));
  }
}
class Ref {
  constructor(path) {
    this.path = path;
  }
  doc(id) {
    return { path: `${this.path}/${id}`, collection: (name) => new Ref(`${this.path}/${id}/${name}`) };
  }
}
class GroupQuery {
  constructor(db, id, limitN, after, ordered) {
    Object.assign(this, { db, id, limitN, after, ordered });
  }
  orderBy(field) {
    assert.equal(field, DOCUMENT_ID);
    return new GroupQuery(this.db, this.id, this.limitN, this.after, true);
  }
  limit(n) {
    return new GroupQuery(this.db, this.id, n, this.after, this.ordered);
  }
  startAfter(snap) {
    return new GroupQuery(this.db, this.id, this.limitN, snap.ref.path, this.ordered);
  }
  async get() {
    assert.ok(this.ordered, "scan must page in documentId order");
    const paths = [...this.db.docs.keys()]
      .filter((p) => {
        const parts = p.split("/");
        return parts.length % 2 === 0 && parts[parts.length - 2] === this.id;
      })
      .sort()
      .filter((p) => this.after === null || p > this.after)
      .slice(0, this.limitN);
    return { docs: paths.map((p) => this.db.snap(p)) };
  }
}

// Synthetic tokens; none may appear in any report, nor may their hashes.
const T = {
  single: "SYNTH-TOKEN-single-7f1",
  shared: "SYNTH-TOKEN-shared-8a2",
  tie: "SYNTH-TOKEN-tie-9b3",
  ownedB: "SYNTH-TOKEN-owned-b-0c4",
  released: "SYNTH-TOKEN-released-1d5",
  moved: "SYNTH-TOKEN-moved-2e6",
  malformed: "SYNTH-TOKEN-malformed-3f7",
};
const SECRETS = [...Object.values(T), ...Object.values(T).map(tokenHash), "SYNTH-TOKEN"];

function assertNoLeak(text, label) {
  for (const secret of SECRETS) assert.ok(!text.includes(secret), `${label} leaked a token or token hash`);
}

const dev = (uid, deviceId) => `fcmTokens/${uid}/devices/${deviceId}`;
const owner = (token) => `fcmTokenOwners/${tokenHash(token)}`;
const reg = (token, extra = {}) => ({ token, platform: "android", disabled: false, ...extra });

/** One token per ownership situation the runner distinguishes. */
function seedAll(db) {
  db.put(dev("uSingle", "d1"), reg(T.single), 10);
  db.put(dev("uOld", "d1"), reg(T.shared), 11);
  db.put(dev("uNew", "d1"), reg(T.shared), 12);
  db.put(dev("uTieA", "d1"), reg(T.tie), 20);
  db.put(dev("uTieB", "d1"), reg(T.tie), 20);
  db.put(dev("parentB", "d1"), reg(T.ownedB), 30);
  db.put(dev("parentA", "d1"), reg(T.ownedB), 31); // stale A, newer write, B verified owner
  db.put(owner(T.ownedB), { uid: "parentB", deviceId: "d1", claimedAt: 1 });
  db.put(dev("uStale", "d1"), reg(T.released), 40);
  db.put(owner(T.released), { releasedAt: 1 });
  db.put(dev("uHolder", "d1"), reg(T.moved), 50);
  db.put(owner(T.moved), { uid: "uGone", deviceId: "d9", claimedAt: 1 });
  db.put(dev("uMal", "d1"), reg(T.malformed), 60);
  db.put(owner(T.malformed), { uid: "uMal" });
  db.put(dev("uOff", "d1"), reg(T.single, { disabled: true }), 70);
  db.put(dev("uBlank", "d1"), reg("   "), 71);
  db.put("users/u1/devices/x", reg(T.single), 72);
}

function fakeReconcile(db) {
  const calls = [];
  const reconcile = async (_db, { uid, deviceId, skipReleased }) => {
    assert.equal(skipReleased, true);
    calls.push(`${uid}/${deviceId}`);
    const path = dev(uid, deviceId);
    const token = db.snap(path).data().token;
    const hashPath = owner(token);
    const current = db.snap(hashPath);
    if (!current.exists) {
      db.put(hashPath, { uid, deviceId, claimedAt: 1 });
      return "claimed";
    }
    db.put(path, { ...db.snap(path).data(), disabled: true, disabledReason: "token_transferred" });
    return "lost_to_newer";
  };
  return { calls, reconcile };
}

const run = (db, mode, extra = {}) =>
  runTokenOwnershipBackfill({ db, mode, documentId: DOCUMENT_ID, pageSize: 2, ...extra });

// ── pure helpers ────────────────────────────────────────────────────────────
test("token predicate and hash match the compiled contract", () => {
  const contract = require("../lib/notifications/fcmTokenContract.js");
  for (const v of ["a", " a ", "", "   ", null, 7, "x".repeat(4096), "x".repeat(4097)]) {
    assert.equal(isUsableToken(v), contract.isUsableToken(v));
  }
  const source = readFileSync(join(here, "..", "src", "notifications", "fcmTokenOwnership.ts"), "utf8");
  assert.match(source, /createHash\("sha256"\)\.update\(token\.trim\(\)\)\.digest\("hex"\)/);
  assert.equal(tokenHash(" abc "), tokenHash("abc"));
  assert.match(tokenHash("abc"), /^[0-9a-f]{64}$/);
});

test("only fcmTokens/{uid}/devices/{id} paths are device records", () => {
  assert.deepEqual(parseDevicePath("fcmTokens/u/devices/d"), { uid: "u", deviceId: "d" });
  assert.equal(parseDevicePath("users/u/devices/d"), null);
  assert.equal(parseDevicePath("fcmTokens/u/other/d"), null);
  assert.equal(parseDevicePath("a/fcmTokens/u/devices/d"), null);
});

// ── classification ──────────────────────────────────────────────────────────
const h = (uid, seconds, deviceId = "d1") => ({ uid, deviceId, updateTime: { seconds, nanoseconds: 0 } });

test("a token verified as B's stays B's even when a stale A record is newer", () => {
  const out = classifyTokenGroup({
    holders: [h("parentA", 99), h("parentB", 1)],
    owner: { uid: "parentB", deviceId: "d1" },
  });
  assert.deepEqual(out, { group: GROUP.ownedWithStaleHolders });
});

test("classification of owned, released, moved and malformed owner records", () => {
  assert.equal(classifyTokenGroup({ holders: [h("b", 1)], owner: { uid: "b", deviceId: "d1" } }).group, GROUP.owned);
  assert.equal(classifyTokenGroup({ holders: [h("a", 1)], owner: { releasedAt: 1 } }).group, GROUP.released);
  assert.equal(
    classifyTokenGroup({ holders: [h("a", 1)], owner: { uid: "b", deviceId: "d1" } }).group,
    GROUP.ownerNotHolding,
  );
  for (const bad of [{ uid: "a" }, { deviceId: "d1" }, {}, { uid: 7, deviceId: "d1" }, { uid: "a", releasedAt: 1 }]) {
    assert.equal(classifyTokenGroup({ holders: [h("a", 1)], owner: bad }).group, GROUP.ownerMalformed);
  }
});

test("legacy tokens: single holder, strictly newest holder, or an ambiguous tie", () => {
  const single = classifyTokenGroup({ holders: [h("a", 5)], owner: null });
  assert.equal(single.group, GROUP.legacySingle);
  assert.equal(single.newest.uid, "a");
  const shared = classifyTokenGroup({ holders: [h("a", 5), h("b", 6), h("c", 4)], owner: null });
  assert.equal(shared.group, GROUP.legacyShared);
  assert.equal(shared.newest.uid, "b");
  assert.equal(classifyTokenGroup({ holders: [h("a", 6), h("b", 6), h("c", 1)], owner: null }).group, GROUP.legacyTie);
  const nanoTie = { uid: "x", deviceId: "d1", updateTime: { seconds: 6, nanoseconds: 1 } };
  assert.equal(classifyTokenGroup({ holders: [h("a", 6), nanoTie], owner: null }).newest.uid, "x");
  const noTime = { uid: "n", deviceId: "d1", updateTime: null };
  assert.equal(classifyTokenGroup({ holders: [noTime], owner: null }).group, GROUP.legacyTie);
});

// ── runner ──────────────────────────────────────────────────────────────────
test("dry run reads only, never reconciles, and reports every situation", async () => {
  const db = new Db();
  seedAll(db);
  const before = db.dump();
  const { calls, reconcile } = fakeReconcile(db);
  const report = await run(db, "dry-run", { reconcile });
  assert.equal(db.dump(), before);
  assert.deepEqual(calls, []);
  assert.deepEqual(report.scan, {
    documents: 13, nonFcmPaths: 1, disabledOrUnusable: 2, enabledRecords: 10, tokens: 7,
  });
  assert.deepEqual(report.groups, {
    [GROUP.owned]: 0,
    [GROUP.ownedWithStaleHolders]: 1,
    [GROUP.released]: 1,
    [GROUP.ownerNotHolding]: 1,
    [GROUP.ownerMalformed]: 1,
    [GROUP.legacySingle]: 1,
    [GROUP.legacyShared]: 1,
    [GROUP.legacyTie]: 1,
  });
  assert.equal(report.plannedGroups, 2);
  assert.deepEqual(report.review[GROUP.ownedWithStaleHolders].refs, ["parentA/d1"]);
  assert.deepEqual(report.review[GROUP.legacyTie].refs.sort(), ["uTieA/d1", "uTieB/d1"]);
  assert.deepEqual(report.written, { claimed: 0, olderHoldersDisabled: 0, skippedChangedSinceScan: 0, unexpectedOutcome: 0 });
  assertNoLeak(JSON.stringify(report), "dry-run report");
});

test("apply writes only unambiguous legacy tokens, newest holder first", async () => {
  const db = new Db();
  seedAll(db);
  const untouched = [
    dev("uTieA", "d1"), dev("uTieB", "d1"), dev("parentA", "d1"), dev("parentB", "d1"), owner(T.ownedB),
    dev("uStale", "d1"), owner(T.released), dev("uHolder", "d1"), owner(T.moved), dev("uMal", "d1"),
    owner(T.malformed), owner(T.tie),
  ];
  const snapshot = () => untouched.map((p) => JSON.stringify(db.docs.get(p) ?? null));
  const before = snapshot();
  const { calls, reconcile } = fakeReconcile(db);
  let asserted = 0;
  const report = await run(db, "apply", { reconcile, assertWriteTarget: () => { asserted += 1; } });

  assert.ok(calls.indexOf("uNew/d1") < calls.indexOf("uOld/d1"));
  assert.deepEqual([...calls].sort(), ["uNew/d1", "uOld/d1", "uSingle/d1"]);
  assert.deepEqual(snapshot(), before, "ambiguous, owned, released, moved and malformed groups untouched");
  assert.deepEqual(report.written, { claimed: 2, olderHoldersDisabled: 1, skippedChangedSinceScan: 0, unexpectedOutcome: 0 });
  assert.ok(asserted >= 3, "write target re-checked before each group");
  assert.equal(db.snap(owner(T.shared)).data().uid, "uNew");
  assert.equal(db.snap(dev("uOld", "d1")).data().disabled, true);
  assertNoLeak(JSON.stringify(report), "apply report");
});

test("newest holder is reconciled before older holders", async () => {
  const db = new Db();
  db.put(dev("a", "d1"), reg(T.shared), 1);
  db.put(dev("b", "d1"), reg(T.shared), 3);
  db.put(dev("c", "d1"), reg(T.shared), 2);
  const { calls, reconcile } = fakeReconcile(db);
  const report = await run(db, "apply", { reconcile, assertWriteTarget: () => {} });
  assert.equal(calls[0], "b/d1");
  assert.deepEqual(report.written, { claimed: 1, olderHoldersDisabled: 2, skippedChangedSinceScan: 0, unexpectedOutcome: 0 });
});

test("re-running apply is idempotent", async () => {
  const db = new Db();
  seedAll(db);
  const { reconcile } = fakeReconcile(db);
  await run(db, "apply", { reconcile, assertWriteTarget: () => {} });
  const after = db.dump();
  const second = fakeReconcile(db);
  const report = await run(db, "apply", { reconcile: second.reconcile, assertWriteTarget: () => {} });
  assert.deepEqual(second.calls, []);
  assert.equal(db.dump(), after);
  assert.equal(report.plannedGroups, 0);
  assert.equal(report.groups[GROUP.owned], 2);
});

test("a group that changed after the scan is skipped, not guessed", async () => {
  const db = new Db();
  db.put(dev("a", "d1"), reg(T.shared), 1);
  db.put(dev("b", "d1"), reg(T.shared), 2);
  db.put(dev("s", "d1"), reg(T.single), 3);
  const { calls, reconcile } = fakeReconcile(db);
  const realGetAll = db.getAll.bind(db);
  let ownerReads = 0;
  db.getAll = async (...refs) => {
    // First getAll is the owner lookup after the scan; mutate right after it.
    const out = await realGetAll(...refs);
    if (ownerReads++ === 0) {
      db.put(dev("a", "d1"), reg(T.shared), 9); // A re-registered: now the newest
      db.put(owner(T.single), { uid: "other", deviceId: "d1" }); // claimed by the trigger
    }
    return out;
  };
  const report = await run(db, "apply", { reconcile, assertWriteTarget: () => {} });
  assert.deepEqual(calls, []);
  assert.equal(report.written.skippedChangedSinceScan, 2);
  assert.equal(db.snap(owner(T.shared)).exists, false);
});

test("an unexpected reconcile outcome stops that group", async () => {
  const db = new Db();
  db.put(dev("a", "d1"), reg(T.shared), 1);
  db.put(dev("b", "d1"), reg(T.shared), 2);
  const calls = [];
  const reconcile = async (_db, { uid }) => {
    calls.push(uid);
    return "ignored";
  };
  const report = await run(db, "apply", { reconcile, assertWriteTarget: () => {} });
  assert.deepEqual(calls, ["b"]);
  assert.equal(report.written.unexpectedOutcome, 1);
  assert.deepEqual(report.review.unexpectedOutcome.refs, ["b/d1"]);
});

test("reconcile failures are counted by code only and do not stop other groups", async () => {
  const db = new Db();
  db.put(dev("a", "d1"), reg(T.single), 1);
  db.put(dev("b", "d1"), reg(T.shared), 2);
  const reconcile = async (_db, { uid }) => {
    if (uid === "a") throw Object.assign(new Error(`boom ${T.single}`), { code: 10 });
    return "claimed";
  };
  const report = await run(db, "apply", { reconcile, assertWriteTarget: () => {} });
  assert.deepEqual(report.errors, { aborted: 1 });
  assert.equal(report.written.claimed, 1);
  assertNoLeak(JSON.stringify(report), "failure report");
});

test("a scan that exceeds maxDocs aborts before any write", async () => {
  const db = new Db();
  seedAll(db);
  const before = db.dump();
  const { calls, reconcile } = fakeReconcile(db);
  const report = await run(db, "apply", { reconcile, assertWriteTarget: () => {}, maxDocs: 5 });
  assert.equal(report.aborted, "scanLimitExceeded");
  assert.deepEqual(calls, []);
  assert.equal(db.dump(), before);
});

test("apply refuses to start without a passing write-target check", async () => {
  const db = new Db();
  seedAll(db);
  const { calls, reconcile } = fakeReconcile(db);
  await assert.rejects(run(db, "apply", { reconcile }), /apply needs reconcile and assertWriteTarget/);
  await assert.rejects(
    run(db, "apply", {
      reconcile,
      assertWriteTarget: () => assertEmulatorWriteTarget({ projectId: "rafiq-academy", env: EMU }),
    }),
    /limited to the emulator demo project/,
  );
  await assert.rejects(run(db, "bogus", {}), /mode must be/);
  assert.deepEqual(calls, []);
});

test("emulator write target check", () => {
  assert.doesNotThrow(() => assertEmulatorWriteTarget({ projectId: WRITE_PROJECT, env: EMU }));
  for (const env of [{}, { FIRESTORE_EMULATOR_HOST: "10.0.0.5:8080" }, { FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443" }]) {
    assert.throws(() => assertEmulatorWriteTarget({ projectId: WRITE_PROJECT, env }), /loopback/);
  }
  for (const projectId of ["rafiq-academy", "demo-other", "rafiq-academy-staging", undefined]) {
    assert.throws(() => assertEmulatorWriteTarget({ projectId, env: EMU }), /emulator demo project/);
  }
});

// ── CLI guards ──────────────────────────────────────────────────────────────
function plan(argv, env) {
  const args = parseMigrationArgs(argv);
  const { problems, mode } = checkMigrationTarget({
    scriptId: SCRIPT_ID, args, env, credentialProjectId: null, needsAuth: false,
  });
  const all = [...problems, ...applyTargetProblems({ args, env })];
  // main() exits on any problem, whatever mode the shared check computed.
  return { problems: all, mode: all.length > 0 ? null : mode };
}

test("dry run is the default; apply needs the flag and the exact confirmation", () => {
  assert.deepEqual(plan(["--project", WRITE_PROJECT], EMU), { problems: [], mode: "dry-run" });
  const ok = plan(["--project", WRITE_PROJECT, "--apply", "--confirm", `${SCRIPT_ID}:${WRITE_PROJECT}`], EMU);
  assert.deepEqual(ok.problems, []);
  assert.equal(ok.mode, "apply");
  assert.ok(plan(["--project", WRITE_PROJECT, "--apply"], EMU).problems.length > 0);
  assert.ok(plan(["--project", WRITE_PROJECT, "--apply", "--confirm", `${SCRIPT_ID}:rafiq-academy`], EMU).problems.length > 0);
});

test("apply is refused for rafiq-academy and any project but the emulator demo", () => {
  for (const project of ["rafiq-academy", "rafiq-academy-staging", "rafiq-academy-prod"]) {
    const argv = ["--project", project, "--apply", "--confirm", `${SCRIPT_ID}:${project}`];
    assert.ok(
      plan(argv, {}).problems.some((p) => p.includes(`--apply is limited to ${WRITE_PROJECT}`)),
      `${project} apply must be refused even with a valid confirmation`,
    );
    assert.ok(plan(argv, EMU).problems.length > 0);
  }
  assert.ok(plan(["--project", "unknown-proj", "--apply", "--confirm", `${SCRIPT_ID}:unknown-proj`], EMU).problems.length > 0);
  assert.ok(plan(["--project", "demo-other", "--apply", "--confirm", `${SCRIPT_ID}:demo-other`], EMU).problems.length > 0);
  assert.ok(plan(["--apply", "--confirm", `${SCRIPT_ID}:${WRITE_PROJECT}`], EMU).problems.length > 0);
});

test("confusing or malformed flags never open writes on a real project", () => {
  const confirmReal = `${SCRIPT_ID}:rafiq-academy`;
  const confirmDemo = `${SCRIPT_ID}:${WRITE_PROJECT}`;
  const refused = [
    ["--project=rafiq-academy", "--apply", `--confirm=${confirmReal}`],
    ["--project", WRITE_PROJECT, "--project", "rafiq-academy", "--apply", "--confirm", confirmReal],
    ["--project", "rafiq-academy", "--apply", "--confirm", confirmDemo],
    ["--project", "rafiq-academy", "--apply=true", "--confirm", confirmReal],
    ["--project", "rafiq-academy", "--Apply", "--confirm", confirmReal],
    ["--project", "rafiq-academy", "--dry-run", "--confirm", confirmReal],
    ["--project", "RAFIQ-ACADEMY", "--apply", "--confirm", `${SCRIPT_ID}:RAFIQ-ACADEMY`],
    ["--project", " rafiq-academy", "--apply", "--confirm", `${SCRIPT_ID}: rafiq-academy`],
    ["rafiq-academy", "--apply", "--confirm", confirmReal],
    ["--project", "--apply", "--confirm", confirmReal],
  ];
  for (const argv of refused) {
    for (const env of [{}, EMU]) {
      const out = plan(argv, env);
      assert.notEqual(out.mode, "apply", `${argv.join(" ")} must not reach apply`);
      assert.ok(out.problems.length > 0, `${argv.join(" ")} must be refused`);
    }
  }
  // A real project with the emulator variables set is refused even read-only.
  assert.ok(plan(["--project", "rafiq-academy"], EMU).problems.length > 0);
});

test("project and emulator environment are validated independently", () => {
  const argv = ["--project", WRITE_PROJECT, "--apply", "--confirm", `${SCRIPT_ID}:${WRITE_PROJECT}`];
  assert.ok(plan(argv, {}).problems.length > 0, "no emulator host");
  assert.ok(plan(argv, { FIRESTORE_EMULATOR_HOST: "10.1.2.3:8080" }).problems.length > 0, "non-loopback emulator");
  assert.ok(plan(argv, { ...EMU, GCLOUD_PROJECT: "rafiq-academy" }).problems.length > 0, "env names another project");
  assert.ok(plan(argv, { ...EMU, FIREBASE_CONFIG: '{"projectId":"rafiq-academy"}' }).problems.length > 0);
  assert.ok(plan(argv, { ...EMU, GOOGLE_APPLICATION_CREDENTIALS: "x.json" }).problems.length > 0);
  // The runner's own check holds even if the shared allowlist check is bypassed.
  assert.ok(applyTargetProblems({ args: { apply: true, project: "rafiq-academy" }, env: EMU }).length > 0);
  assert.ok(applyTargetProblems({ args: { apply: true, project: WRITE_PROJECT }, env: {} }).length > 0);
  assert.deepEqual(applyTargetProblems({ args: { apply: false, project: "rafiq-academy" }, env: {} }), []);
});

function cli(argv, env) {
  const clean = Object.fromEntries(
    Object.entries(process.env).filter(([k]) =>
      !/(_EMULATOR_HOST|^GCLOUD_PROJECT$|^GOOGLE_CLOUD_PROJECT$|^GCP_PROJECT$|^CLOUDSDK_CORE_PROJECT$|^FIREBASE_CONFIG$|^GOOGLE_APPLICATION_CREDENTIALS$)/i.test(k)),
  );
  return spawnSync(process.execPath, ["--import", noAdminPreload, scriptPath, ...argv], {
    env: { ...clean, ...env },
    encoding: "utf8",
    timeout: 30_000,
  });
}

test("CLI refuses rafiq-academy apply before loading firebase-admin", () => {
  const res = cli(["--project", "rafiq-academy", "--apply", "--confirm", `${SCRIPT_ID}:rafiq-academy`], {});
  assert.equal(res.status, 2);
  assert.match(res.stderr, /refused: --apply is limited to demo-rafiq-rules/);
  assert.doesNotMatch(res.stderr, /firebase-admin load attempted/);
  assert.equal(res.stdout, "");
});

test("CLI refuses unknown projects, a missing emulator and mixed modes", () => {
  for (const [argv, env] of [
    [["--project", "someone-else"], EMU],
    [["--project", WRITE_PROJECT], {}],
    [["--project", WRITE_PROJECT, "--apply", "--dry-run", "--confirm", `${SCRIPT_ID}:${WRITE_PROJECT}`], EMU],
    [["--project", WRITE_PROJECT, "--apply", "--confirm", `${SCRIPT_ID}:${WRITE_PROJECT}`], { FIRESTORE_EMULATOR_HOST: "10.0.0.1:8080" }],
    [["--project", "rafiq-academy"], EMU],
  ]) {
    const res = cli(argv, env);
    assert.equal(res.status, 2, argv.join(" "));
    assert.match(res.stderr, /refused:/);
    assert.doesNotMatch(res.stderr, /firebase-admin load attempted/);
  }
});

test("the runner never touches the push gate or a sender", () => {
  const source = readFileSync(scriptPath, "utf8");
  for (const forbidden of ["PRODUCTION_BACKEND_ENABLED", "FUNCTIONS_EMULATOR", "messaging", "sendEach", ".delete(", "console.log(token", "writeFile"]) {
    assert.ok(!source.includes(forbidden), `runner must not reference ${forbidden}`);
  }
});
