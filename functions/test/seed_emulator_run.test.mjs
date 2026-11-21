/**
 * Orchestration of scripts/seed-emulator.mjs with injected fakes: guard
 * order, no firebase-admin load and no write before every check passes,
 * create-only writes, and safe failure without deletes. Plus the real entry
 * point as a child process for argument / environment refusals and SDK load
 * order. No emulator, no network, no firebase-admin initialization.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildDemoDataset,
  DEMO_ACCOUNTS,
  SEED_COMPLETION_PHASE,
  SEED_MARKER_PHASE,
  SEED_META,
} from "../scripts/seed-emulator-dataset.mjs";
import { failureHelp, REFUSED, RETRY_HELP, runSeed } from "../scripts/seed-emulator.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const entry = join(functionsDir, "scripts", "seed-emulator.mjs");
const spy = join(here, "fixtures", "seed_emulator_module_spy.cjs");
const spyRunner = join(here, "fixtures", "seed_emulator_spy_runner.mjs");
const repoFirebaseJson = JSON.parse(readFileSync(join(functionsDir, "..", "firebase.json"), "utf8"));

// ── Fakes ───────────────────────────────────────────────────────────────────

/**
 * In-memory Auth + Firestore. `failOn[key]` injects one outcome per write or
 * read key ("create <path>", "update <path>", "commit", "createUser <uid>",
 * "get <path>", "getUser <uid>"):
 *   "reject"   refused before anything is applied
 *   "landed"   applied, then the response fails (outcome looks like a failure)
 *   "hang"     never answers until the test calls land() or fail()
 *   "mismatch" (getUser) answers with another email
 *   function   custom ({ store, authUsers, apply }) => result
 * `onCommit(store)` runs after a successful commit, standing in for the
 * Firestore triggers the Functions emulator runs in the background.
 */
function fakeAdmin({ users = [], docs = {}, failOn = {}, projectId = "demo-rafiq-rules", onCommit } = {}) {
  const fake = { calls: [], failOn, hung: [] };
  const store = new Map(Object.entries(docs));
  const authUsers = new Map(users.map((u) => [u.uid, u]));
  const record = (entry) => fake.calls.push(entry);
  const act = async (key, apply) => {
    const mode = fake.failOn[key];
    if (mode === undefined) return apply();
    if (mode === "reject") throw new Error(`injected rejection at ${key}`);
    if (mode === "landed") {
      apply();
      throw new Error(`injected lost response at ${key}`);
    }
    if (mode === "hang") {
      return new Promise((resolve, reject) => {
        fake.hung.push({
          key,
          land: () => {
            try {
              resolve(apply());
            } catch (e) {
              reject(e);
            }
          },
          fail: () => reject(new Error(`late failure at ${key}`)),
        });
      });
    }
    if (typeof mode === "function") return mode({ store, authUsers, apply });
    throw new Error(`unknown failOn mode ${mode} for ${key}`);
  };
  const readFails = (key) => {
    if (fake.failOn[key] === "reject") throw Object.assign(new Error(`injected read failure at ${key}`), { code: "unavailable" });
  };
  const ref = (collection, id) => {
    const path = `${collection}/${id}`;
    return {
      path,
      // Nested paths (e.g. conversations/{id}/messages/{msgId}) used by seed v4.
      collection: (sub) => ({
        doc: (subId) => ref(`${collection}/${id}/${sub}`, subId),
      }),
      async create(data) {
        record(`create ${path}`);
        return act(`create ${path}`, () => {
          if (store.has(path)) throw new Error(`${path} already exists`);
          store.set(path, data);
        });
      },
      async update(data) {
        record(`update ${path}`);
        return act(`update ${path}`, () => store.set(path, { ...store.get(path), ...data }));
      },
      async get() {
        record(`read get ${path}`);
        readFails(`get ${path}`);
        return { exists: store.has(path), data: () => store.get(path) };
      },
      async set() {
        record(`set ${path}`);
      },
      async delete() {
        record(`DELETE ${path}`);
      },
    };
  };
  const db = {
    collection: (collection) => ({ doc: (id) => ref(collection, id) }),
    batch() {
      const pending = [];
      return {
        create: (r, data) => pending.push([r.path, data]),
        set: () => record("batch.set"),
        delete: () => record("batch.DELETE"),
        async commit() {
          record(`commit ${pending.length}`);
          return act("commit", () => {
            for (const [path] of pending) {
              if (store.has(path)) throw new Error(`${path} already exists`);
            }
            for (const [path, data] of pending) store.set(path, data);
            onCommit?.(store);
          });
        },
      };
    },
    async listCollections() {
      record("listCollections");
      return [...new Set([...store.keys()].map((k) => k.split("/")[0]))].map((id) => ({ id }));
    },
    async recursiveDelete() {
      record("DELETE recursive");
    },
  };
  const auth = {
    async listUsers() {
      record("listUsers");
      return { users: [...authUsers.values()] };
    },
    async createUser(user) {
      record(`createUser ${user.uid}`);
      return act(`createUser ${user.uid}`, () => {
        if (authUsers.has(user.uid)) throw new Error("uid exists");
        authUsers.set(user.uid, user);
        return user;
      });
    },
    async getUser(uid) {
      record(`read getUser ${uid}`);
      readFails(`getUser ${uid}`);
      const user = authUsers.get(uid);
      if (!user) throw Object.assign(new Error(`no user ${uid}`), { code: "auth/user-not-found" });
      return fake.failOn[`getUser ${uid}`] === "mismatch" ? { ...user, email: "other@rafiq.demo" } : user;
    },
    async deleteUser(uid) {
      record(`DELETE user ${uid}`);
    },
    async deleteUsers() {
      record("DELETE users");
    },
  };
  return Object.assign(fake, {
    projectId,
    auth,
    db,
    store,
    authUsers,
    serverTimestamp: () => "SERVER_TS",
    close: async () => record("close"),
  });
}

const VERIFIED = { problems: [], hubPid: 4242, cliVersion: "15.18.0" };

function harness({
  args = [],
  env = {},
  execArgv = [],
  firebaseJson = repoFirebaseJson,
  files = [],
  selfTest = true,
  blocked = [],
  readinessProblems = [],
  identityResult = VERIFIED,
  admin: adminOptions = {},
  adminInstance,
  loadAdminThrows = false,
  writeStepTimeoutMs,
} = {}) {
  const calls = [];
  const lines = { log: [], error: [] };
  // adminInstance: the same emulator state as an earlier run, with no injected failures.
  const admin = adminInstance ?? fakeAdmin(adminOptions);
  admin.calls = calls;
  if (adminInstance) admin.failOn = {};
  const run = () =>
    runSeed({
      args,
      env,
      execArgv,
      platform: "win32",
      readFirebaseJson: () => {
        calls.push("readFirebaseJson");
        if (firebaseJson instanceof Error) throw firebaseJson;
        return firebaseJson;
      },
      fileExists: (p) => files.includes(p),
      installEgress: ({ allowedPorts }) => {
        calls.push(`installEgress ${allowedPorts.join(",")}`);
        return {
          selfTest: async () => {
            calls.push("selfTest");
            return selfTest;
          },
          blockedAttempts: () => (typeof blocked === "function" ? blocked(calls) : blocked),
        };
      },
      readiness: async ({ ports }) => {
        calls.push(`readiness ${ports.hub},${ports.auth},${ports.firestore} env=${env.FIRESTORE_EMULATOR_HOST}`);
        return readinessProblems;
      },
      identity: async ({ ports }) => {
        calls.push(`identity ${ports.hub},${ports.ui}`);
        return identityResult;
      },
      loadAdmin: async () => {
        calls.push(`loadAdmin env=${env.FIRESTORE_EMULATOR_HOST},${env.FIREBASE_AUTH_EMULATOR_HOST}`);
        if (loadAdminThrows) throw new Error("boom");
        return admin;
      },
      ...(writeStepTimeoutMs === undefined ? {} : { writeStepTimeoutMs }),
      log: (l) => lines.log.push(l),
      error: (l) => lines.error.push(l),
    });
  return { run, calls, lines, admin, env };
}

const isWrite = (c) => /^(create|update|set|commit|createUser|batch\.)/.test(c);
const isDelete = (c) => /DELETE/.test(c);

// ── Refusals before firebase-admin is loaded ────────────────────────────────

test("pre-SDK refusals never install the SDK or write", async () => {
  const cases = {
    args: { args: ["--project", "rafiq-academy"] },
    emptyArg: { args: [""] },
    unreadableFirebaseJson: { firebaseJson: new Error("ENOENT") },
    missingPorts: { firebaseJson: { emulators: { firestore: { port: 8080 } } } },
    credentials: { env: { GOOGLE_APPLICATION_CREDENTIALS: "C:\\sa.json" } },
    adcFile: { env: { APPDATA: "C:\\A" }, files: [join("C:\\A", "gcloud", "application_default_credentials.json")] },
    conflictingProject: { env: { GCLOUD_PROJECT: "rafiq-academy" } },
    prefixOnlyProject: { env: { GOOGLE_CLOUD_PROJECT: "demo-other" } },
    badFirebaseConfig: { env: { FIREBASE_CONFIG: "{\"projectId\":\"rafiq-academy\"}" } },
    wrongFirestoreHost: { env: { FIRESTORE_EMULATOR_HOST: "localhost:8080" } },
    wrongAuthPort: { env: { FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9098" } },
    proxy: { env: { HTTPS_PROXY: "http://proxy:8080" } },
    selfTestFails: { selfTest: false },
    notReady: { readinessProblems: ["Auth emulator is not reachable"] },
    nodeOptions: { env: { NODE_OPTIONS: "--require C:/x.js" } },
    execArgv: { execArgv: ["--import=file:///C:/x.mjs"] },
    npmNodeOptions: { env: { npm_config_node_options: "" } },
    hubPortMissing: { firebaseJson: { emulators: { auth: { port: 9099 }, firestore: { port: 8080 }, ui: { port: 4000 } } } },
    uiDisabled: { firebaseJson: { emulators: { ...repoFirebaseJson.emulators, ui: { enabled: false, port: 4000 } } } },
    identityFails: { identityResult: { problems: ['Emulator UI reports project "demo-no-project"'], hubPid: null, cliVersion: null } },
  };
  for (const [name, options] of Object.entries(cases)) {
    const h = harness(options);
    const code = await h.run();
    assert.equal(code, REFUSED, name);
    assert.ok(!h.calls.some((c) => c.startsWith("loadAdmin")), `${name}: ${h.calls}`);
    assert.ok(!h.calls.some(isWrite), name);
    assert.ok(h.lines.error.length > 0, name);
  }
});

test("environment checks run before the network allowlist, which runs before readiness", async () => {
  const h = harness({ env: { GCLOUD_PROJECT: "rafiq-academy" } });
  await h.run();
  assert.deepEqual(h.calls, ["readFirebaseJson"]);

  const ok = harness();
  await ok.run();
  assert.deepEqual(ok.calls.slice(0, 6), [
    "readFirebaseJson",
    "installEgress 9099,8080,4400,4000",
    "selfTest",
    "readiness 4400,9099,8080 env=127.0.0.1:8080",
    "identity 4400,4000",
    "loadAdmin env=127.0.0.1:8080,127.0.0.1:9099",
  ]);
  assert.ok(ok.lines.log.some((l) => l.includes("hub pid 4242") && l.includes("15.18.0")));
});

test("Node preload options are refused before firebase.json is even read, without echoing values", async () => {
  const secret = "C:/Users/x/token-agent.js";
  for (const options of [
    { env: { NODE_OPTIONS: `--require ${secret}` } },
    { env: { node_options: `--import=${secret}` } },
    { env: { NODE_OPTIONS: "--inspect" } },
    { env: { npm_config_node_options: `--require ${secret}` } },
    { execArgv: ["--require", secret] },
    { execArgv: ["--inspect-brk"] },
    { args: ["--project", "x"], execArgv: ["-r", secret] },
  ]) {
    const h = harness(options);
    assert.equal(await h.run(), REFUSED, JSON.stringify(options));
    assert.deepEqual(h.calls, [], JSON.stringify(options));
    assert.ok(h.lines.error.length > 0);
    assert.ok(!h.lines.error.some((l) => l.includes(secret) || l.includes("--inspect")), h.lines.error.join("\n"));
  }
  const blank = harness({ env: { NODE_OPTIONS: "  " } });
  assert.equal(await blank.run(), 0);
});

test("an identity failure refuses after readiness and before firebase-admin, without writing", async () => {
  for (const problems of [
    ["Hub locator could not be read (ENOENT)"],
    ["Hub locator names pid 1, but the hub is pid 2"],
    ['Emulator UI reports project "demo-no-project"'],
    ["Emulator hub lists ui at 127.0.0.1:4001; expected 127.0.0.1:4000."],
  ]) {
    const h = harness({ identityResult: { problems, hubPid: null, cliVersion: null } });
    assert.equal(await h.run(), REFUSED, problems[0]);
    assert.equal(h.calls.at(-1), "identity 4400,4000");
    assert.ok(h.calls.some((c) => c.startsWith("readiness")));
    assert.ok(!h.calls.some((c) => c.startsWith("loadAdmin") || isWrite(c)), h.calls.join("\n"));
    assert.deepEqual(h.lines.error, [`Seed refused: ${problems[0]}`]);
  }
  const notReady = harness({ readinessProblems: ["not ready"] });
  assert.equal(await notReady.run(), REFUSED);
  assert.ok(!notReady.calls.some((c) => c.startsWith("identity")));
});

test("emulator host overrides are in place before firebase-admin loads", async () => {
  const env = {};
  const h = harness({ env });
  assert.equal(await h.run(), 0);
  assert.equal(env.FIRESTORE_EMULATOR_HOST, "127.0.0.1:8080");
  assert.equal(env.FIREBASE_AUTH_EMULATOR_HOST, "127.0.0.1:9099");
  assert.equal(env.GCLOUD_PROJECT, "demo-rafiq-rules");
  assert.equal(env.GOOGLE_CLOUD_PROJECT, "demo-rafiq-rules");
});

// ── Refusals after loading, still before any write ──────────────────────────

test("a wrong app project or a failed SDK load refuses without writing", async () => {
  for (const options of [{ admin: { projectId: "rafiq-academy" } }, { loadAdminThrows: true }]) {
    const h = harness(options);
    assert.equal(await h.run(), REFUSED);
    assert.ok(!h.calls.some(isWrite), JSON.stringify(options));
  }
});

test("any blocked connection during the SDK probes refuses before writing", async () => {
  const h = harness({ blocked: (calls) => (calls.includes("listUsers") ? [{ host: "oauth2.googleapis.com", port: 443 }] : []) });
  assert.equal(await h.run(), REFUSED);
  assert.ok(!h.calls.some(isWrite), h.calls.join("\n"));
  assert.ok(h.lines.error.some((l) => l.includes("non-emulator network access")));
});

test("existing data or a leftover seed marker refuses before writing", async () => {
  const cases = {
    authUser: { users: [{ uid: "someone", email: "x@y.z" }] },
    foreignDoc: { docs: { "halaqat/h1": { name: "x" } } },
    partialSeed: { docs: { [`${SEED_META.collection}/${SEED_META.id}`]: { status: "in_progress", version: 1 } } },
    completeSeed: { docs: { [`${SEED_META.collection}/${SEED_META.id}`]: { status: "complete", version: 1 } } },
  };
  for (const [name, admin] of Object.entries(cases)) {
    const h = harness({ admin });
    assert.equal(await h.run(), REFUSED, name);
    assert.ok(!h.calls.some(isWrite), `${name}: ${h.calls}`);
  }
  const partial = harness({ admin: cases.partialSeed });
  await partial.run();
  assert.ok(partial.lines.error.some((l) => l.includes("in_progress")));
});

// ── Writes ──────────────────────────────────────────────────────────────────

test("happy path: marker, Auth users with fixed UIDs, one create batch, verify, then complete", async () => {
  const h = harness();
  assert.equal(await h.run(), 0);
  const dataset = buildDemoDataset();
  const writes = h.calls.filter(isWrite);
  assert.deepEqual(writes, [
    `create ${SEED_META.collection}/${SEED_META.id}`,
    ...dataset.authUsers.map((u) => `createUser ${u.uid}`),
    `commit ${dataset.documents.length}`,
    `update ${SEED_META.collection}/${SEED_META.id}`,
  ]);
  assert.ok(!h.calls.some(isDelete));
  const marker = h.admin.store.get(`${SEED_META.collection}/${SEED_META.id}`);
  assert.equal(marker.status, "complete");
  assert.equal(marker.hubPid, 4242);
  assert.equal(marker.cliVersion, "15.18.0");
  for (const doc of dataset.documents) {
    assert.ok(h.admin.store.has(`${doc.collection}/${doc.id}`), `${doc.collection}/${doc.id}`);
  }
  assert.ok(h.calls.includes("close"));
});

test("a failure part-way stops, deletes nothing and leaves the marker in_progress", async () => {
  const dataset = buildDemoDataset();
  const failures = [
    { [`createUser ${dataset.authUsers[2].uid}`]: "reject" },
    { commit: "reject" },
    { [`update ${SEED_META.collection}/${SEED_META.id}`]: "reject" },
  ];
  for (const failOn of failures) {
    const h = harness({ admin: { failOn } });
    assert.equal(await h.run(), 1, JSON.stringify(failOn));
    assert.ok(!h.calls.some(isDelete), JSON.stringify(failOn));
    assert.equal(h.admin.store.get(`${SEED_META.collection}/${SEED_META.id}`).status, "in_progress");
    assert.ok(h.lines.error.some((l) => l.includes("Nothing was deleted") && l.includes("hub pid 4242")));
    assert.ok(h.lines.error.some((l) => l.includes(RETRY_HELP)), JSON.stringify(failOn));
  }

  const midway = harness({ admin: { failOn: { [`createUser ${dataset.authUsers[2].uid}`]: "reject" } } });
  await midway.run();
  assert.ok(!midway.calls.some((c) => c.startsWith("commit")));
  assert.ok(!midway.calls.includes(`createUser ${dataset.authUsers[3].uid}`));
});

test("a failed seed marker create stops before any Auth user or document", async () => {
  const marker = `${SEED_META.collection}/${SEED_META.id}`;
  const h = harness({ admin: { failOn: { [`create ${marker}`]: "reject" } } });
  assert.equal(await h.run(), 1);
  assert.deepEqual(h.calls.filter(isWrite), [`create ${marker}`]);
  assert.ok(!h.calls.some(isDelete));
  assert.ok(h.lines.error.some((l) => l.includes("no Auth user or document was written")));
  assert.ok(!h.lines.error.some((l) => l.includes('"in_progress" and sent no update')));
  assert.ok(h.lines.error.some((l) => l.includes(RETRY_HELP)));
});

test("failure guidance forbids re-running the session and never promises an empty restart", () => {
  assert.match(RETRY_HELP, /Do not re-run the seeder against this emulator session/);
  assert.match(RETRY_HELP, /`npm run serve` only \(never --import or --export-on-exit\)/);
  assert.match(RETRY_HELP, /Restarting does not by itself prove the emulator is empty/);
  assert.match(RETRY_HELP, /pre-write checks decide/);
  for (const phase of [SEED_MARKER_PHASE, "Auth user x@rafiq.demo", "Firestore documents", "verification", SEED_COMPLETION_PHASE, undefined]) {
    for (const session of [{}, { hubPid: 4242, cliVersion: "15.18.0" }]) {
      for (const timedOut of [false, true]) {
        const text = failureHelp(phase, session, timedOut);
        assert.ok(text.startsWith("Nothing was deleted"), text);
        assert.ok(text.endsWith(RETRY_HELP), text);
        assert.equal(text.includes("hub pid 4242"), Boolean(session.hubPid), text);
        assert.equal(text.includes("was not cancelled and may still be applied"), timedOut, text);
        assert.doesNotMatch(text, /\b(reset|wipe|clear the emulator|delete the data)\b/i, text);
        assert.doesNotMatch(text.replace(RETRY_HELP, ""), /\bempty\b/i, text);
      }
    }
  }
  const completion = failureHelp(SEED_COMPLETION_PHASE, {});
  assert.match(completion, /may be "in_progress" or "complete"/);
  assert.doesNotMatch(completion, /sent no update/);
  const unexpected = failureHelp(undefined, {});
  assert.match(unexpected, /state of _seedMeta\/demo is indeterminate/);
  assert.doesNotMatch(unexpected, /sent no update|stays "in_progress"/);
  assert.match(failureHelp("Firestore documents", {}), /This run created _seedMeta\/demo as "in_progress" and sent no update/);
});

test("an unexpected error outside a write step reports the marker state as indeterminate", async () => {
  const h = harness();
  const collection = h.admin.db.collection;
  let n = 0;
  h.admin.db.collection = (name) => {
    n += 1;
    if (n === 2) throw new TypeError("unexpected client failure");
    return collection(name);
  };
  assert.equal(await h.run(), 1);
  assert.deepEqual(h.calls.filter(isWrite), []);
  assert.ok(!h.calls.some(isDelete));
  const text = h.lines.error.join("\n");
  assert.match(text, /unexpected client failure/);
  assert.match(text, /state of _seedMeta\/demo \(emulator hub pid 4242\) is indeterminate/);
  assert.doesNotMatch(text, /sent no update|stays "in_progress"/);
});

test("a complete marker is refused without claiming the earlier run succeeded", async () => {
  const h = harness({ admin: { docs: { [`${SEED_META.collection}/${SEED_META.id}`]: { status: "complete", version: 1 } } } });
  assert.equal(await h.run(), REFUSED);
  assert.deepEqual(h.calls.filter(isWrite), []);
  const text = h.lines.error.join("\n");
  assert.match(text, /is "complete" \(dataset v1\): the dataset looks complete, but that does not show the run that wrote it succeeded/);
  assert.doesNotMatch(text, /already seeded/);
  assert.doesNotMatch(text, /Read-only diagnosis/);
});

test("a failed state probe reports the state as unknown and writes nothing", async () => {
  const h = harness();
  h.admin.auth.listUsers = async () => {
    throw new Error("connection reset");
  };
  assert.equal(await h.run(), REFUSED);
  assert.deepEqual(h.calls.filter(isWrite), []);
  assert.ok(h.lines.error.some((l) => l.includes("connection reset") && l.includes("the emulator's state is unknown")));
});

test("docs state the identity evidence and the no-reuse retry procedure", () => {
  const docs = readFileSync(join(functionsDir, "..", "docs", "DEMO_ACADEMY_DATASET.md"), "utf8").replace(/\r\n/g, "\n");
  for (const phrase of [
    "`NODE_OPTIONS`",
    "`npm_config_node_options`",
    "(9099 / 8080 / 4400 / 4000)",
    "`hub-demo-rafiq-rules.json`",
    "only read, never created, repaired or deleted",
    "`GET /api/config`",
    "`singleProjectMode` is not evidence",
    "Do not re-run the seeder against a session where it failed while writing.",
    "never `--import` or\n  `--export-on-exit`",
    "Stopping and restarting does not by itself prove the emulator is empty.",
    "for diagnosis only",
    "There is no reset, no rollback and nothing is deleted.",
    "It does not cancel the request, which may still\nbe applied later",
    "A\ntimeout is not proof that the write failed or that nothing was written.",
    "A read it could not do is reported as unknown, never as absent.",
    "The diagnosis never makes the session acceptable for\nseeding.",
    "may create `studentSearch/{id}`",
    "`engines.node` is `\"22\"`",
    "runs the Functions emulator on the host's Node instead.",
  ]) {
    assert.ok(docs.includes(phrase), phrase);
  }
  const flat = docs.replace(/\s+/g, " ");
  for (const phrase of [
    "The seeder never retries a step itself; firebase-admin and its client libraries may retry some requests internally",
    "After any failure or timeout the seeder sends no further write and exits 1.",
    "may still be applied later, even after the seeder has exited.",
    "can still leave it `complete`.",
  ]) {
    assert.ok(flat.includes(phrase), phrase);
  }
  assert.doesNotMatch(flat, /there are no retries|never completes the marker|never set to `complete`/);
  assert.doesNotMatch(docs, /start them again with `npm run serve`,\s*then re-run the seeder/);
});

test("a blocked connection during writes fails the run before the marker is completed", async () => {
  const marker = `${SEED_META.collection}/${SEED_META.id}`;
  const h = harness({ blocked: (calls) => (calls.some((c) => c.startsWith("commit")) ? [{ host: "x", port: 1 }] : []) });
  assert.equal(await h.run(), 1);
  assert.ok(!h.calls.some(isDelete));
  assert.ok(!h.calls.includes(`update ${marker}`), h.calls.join("\n"));
  assert.equal(h.admin.store.get(marker).status, "in_progress");
  assert.ok(h.lines.error.some((l) => l.includes("pre-completion check") && l.includes("blocked")));
  assert.ok(h.lines.error.some((l) => l.includes('as "in_progress" and sent no update')));
});

// ── Failure injection: what is left, and what the next run does ─────────────

const MARKER = `${SEED_META.collection}/${SEED_META.id}`;
const DATASET = buildDemoDataset();
const UIDS = DATASET.authUsers.map((u) => u.uid);
const DOC_COUNT = DATASET.documents.length;
const FULL_WRITES = [`create ${MARKER}`, ...UIDS.map((u) => `createUser ${u}`), `commit ${DOC_COUNT}`, `update ${MARKER}`];
const writesUpTo = (entry) => FULL_WRITES.slice(0, FULL_WRITES.indexOf(entry) + 1);
const writesOf = (calls) => calls.filter(isWrite);
const datasetDocsIn = (store) => DATASET.documents.filter((d) => store.has(`${d.collection}/${d.id}`)).length;
const markerStatus = (admin) => admin.store.get(MARKER)?.status ?? null;
const tick = () => new Promise((resolve) => setImmediate(resolve));

const FAILURE_MATRIX = [
  { name: "marker create rejected", failOn: { [`create ${MARKER}`]: "reject" }, writes: writesUpTo(`create ${MARKER}`), marker: null, users: 0, docs: 0, rerun: 0 },
  { name: "marker create landed, response lost", failOn: { [`create ${MARKER}`]: "landed" }, writes: writesUpTo(`create ${MARKER}`), marker: "in_progress", users: 0, docs: 0, rerun: REFUSED },
  { name: "first Auth user rejected", failOn: { [`createUser ${UIDS[0]}`]: "reject" }, writes: writesUpTo(`createUser ${UIDS[0]}`), marker: "in_progress", users: 0, docs: 0, rerun: REFUSED },
  { name: "middle Auth user rejected", failOn: { [`createUser ${UIDS[2]}`]: "reject" }, writes: writesUpTo(`createUser ${UIDS[2]}`), marker: "in_progress", users: 2, docs: 0, rerun: REFUSED },
  { name: "middle Auth user landed, response lost", failOn: { [`createUser ${UIDS[2]}`]: "landed" }, writes: writesUpTo(`createUser ${UIDS[2]}`), marker: "in_progress", users: 3, docs: 0, rerun: REFUSED },
  { name: "last Auth user rejected", failOn: { [`createUser ${UIDS.at(-1)}`]: "reject" }, writes: writesUpTo(`createUser ${UIDS.at(-1)}`), marker: "in_progress", users: UIDS.length - 1, docs: 0, rerun: REFUSED },
  { name: "document batch rejected", failOn: { commit: "reject" }, writes: writesUpTo(`commit ${DOC_COUNT}`), marker: "in_progress", users: UIDS.length, docs: 0, rerun: REFUSED },
  { name: "document batch landed, response lost", failOn: { commit: "landed" }, writes: writesUpTo(`commit ${DOC_COUNT}`), marker: "in_progress", users: UIDS.length, docs: DOC_COUNT, rerun: REFUSED },
  { name: "verification finds a wrong Auth email", failOn: { [`getUser ${UIDS[1]}`]: "mismatch" }, writes: writesUpTo(`commit ${DOC_COUNT}`), marker: "in_progress", users: UIDS.length, docs: DOC_COUNT, rerun: REFUSED },
  { name: "verification read fails", failOn: { [`get ${DATASET.documents[3].collection}/${DATASET.documents[3].id}`]: "reject" }, writes: writesUpTo(`commit ${DOC_COUNT}`), marker: "in_progress", users: UIDS.length, docs: DOC_COUNT, rerun: REFUSED },
  { name: "marker completion rejected", failOn: { [`update ${MARKER}`]: "reject" }, writes: FULL_WRITES, marker: "in_progress", users: UIDS.length, docs: DOC_COUNT, rerun: REFUSED },
  { name: "marker completion landed, response lost", failOn: { [`update ${MARKER}`]: "landed" }, writes: FULL_WRITES, marker: "complete", users: UIDS.length, docs: DOC_COUNT, rerun: REFUSED },
];

test("failure matrix: exit 1, no cleanup or retry, marker state as expected, and the next run on that state", async () => {
  for (const s of FAILURE_MATRIX) {
    const first = harness({ admin: { failOn: s.failOn } });
    assert.equal(await first.run(), 1, s.name);
    assert.deepEqual(writesOf(first.calls), s.writes, `${s.name}: extra or repeated writes`);
    assert.ok(!first.calls.some(isDelete), s.name);
    assert.equal(markerStatus(first.admin), s.marker, s.name);
    assert.equal(first.admin.authUsers.size, s.users, s.name);
    assert.equal(datasetDocsIn(first.admin.store), s.docs, s.name);
    assert.ok(first.lines.error.some((l) => l.includes(RETRY_HELP)), s.name);
    assert.ok(!first.lines.log.includes("Seed complete."), s.name);

    const next = harness({ adminInstance: first.admin });
    assert.equal(await next.run(), s.rerun, `${s.name}: next run`);
    if (s.rerun === REFUSED) {
      assert.deepEqual(writesOf(next.calls), [], `${s.name}: next run wrote`);
      assert.ok(!next.calls.some(isDelete), s.name);
    }
  }
});

test("a rejected marker create left nothing, so only then does a later run on the same state seed", async () => {
  const first = harness({ admin: { failOn: { [`create ${MARKER}`]: "reject" } } });
  assert.equal(await first.run(), 1);
  assert.equal(first.admin.store.size, 0);
  assert.equal(first.admin.authUsers.size, 0);
  const next = harness({ adminInstance: first.admin });
  assert.equal(await next.run(), 0);
  assert.equal(markerStatus(next.admin), "complete");
});

test("a write that does not answer stops the run: no later write, no completion, and it may still land", async () => {
  const cases = [
    { key: `create ${MARKER}`, last: `create ${MARKER}`, phase: SEED_MARKER_PHASE },
    { key: `createUser ${UIDS[2]}`, last: `createUser ${UIDS[2]}`, phase: `Auth user ${UIDS[2]}` },
    { key: "commit", last: `commit ${DOC_COUNT}`, phase: "Firestore documents" },
    { key: `update ${MARKER}`, last: `update ${MARKER}`, phase: SEED_COMPLETION_PHASE },
  ];
  for (const c of cases) {
    const h = harness({ admin: { failOn: { [c.key]: "hang" } }, writeStepTimeoutMs: 20 });
    assert.equal(await h.run(), 1, c.key);
    assert.deepEqual(writesOf(h.calls), writesUpTo(c.last), `${c.key}: writes after the timeout`);
    assert.notEqual(markerStatus(h.admin), "complete", c.key);
    assert.ok(h.lines.error.some((l) => l.startsWith(`Seed stopped during ${c.phase}:`) && l.includes("may still be applied")), c.key);
    assert.ok(h.lines.error.some((l) => l.includes("did not answer in time") && l.includes(RETRY_HELP)), c.key);
    assert.ok(!h.calls.some(isDelete), c.key);

    const callsAtExit = h.calls.length;
    assert.equal(h.admin.hung.length, 1, c.key);
    h.admin.hung[0].land();
    await tick();
    assert.equal(h.calls.length, callsAtExit, `${c.key}: the late answer triggered more work`);

    const next = harness({ adminInstance: h.admin });
    assert.equal(await next.run(), REFUSED, `${c.key}: next run`);
    assert.deepEqual(writesOf(next.calls), [], c.key);
  }
});

test("the abandoned request landing late can complete the marker, so a timeout never proves the outcome", async () => {
  const h = harness({ admin: { failOn: { [`update ${MARKER}`]: "hang" } }, writeStepTimeoutMs: 20 });
  assert.equal(await h.run(), 1);
  assert.equal(markerStatus(h.admin), "in_progress");
  h.admin.hung[0].land();
  await tick();
  assert.equal(markerStatus(h.admin), "complete");
  assert.ok(h.lines.error.some((l) => l.includes('may be "in_progress" or "complete"')));
});

test("a late error from an abandoned request is ignored without an unhandled rejection", async () => {
  const h = harness({ admin: { failOn: { [`createUser ${UIDS[1]}`]: "hang" } }, writeStepTimeoutMs: 20 });
  assert.equal(await h.run(), 1);
  const callsAtExit = h.calls.length;
  h.admin.hung[0].fail();
  await tick();
  await tick();
  assert.equal(h.calls.length, callsAtExit);
});

test("two concurrent runs: the loser's marker create fails, it writes nothing else, later runs are refused", async () => {
  const otherRun = ({ store }) => {
    store.set(MARKER, { status: "in_progress", version: 1, hubPid: 9999 });
    throw Object.assign(new Error("6 ALREADY_EXISTS: Document already exists"), { code: 6 });
  };
  const h = harness({ admin: { failOn: { [`create ${MARKER}`]: otherRun } } });
  assert.equal(await h.run(), 1);
  assert.deepEqual(writesOf(h.calls), [`create ${MARKER}`]);
  assert.equal(h.admin.authUsers.size, 0);
  assert.ok(h.lines.error.some((l) => l.includes("may or may not exist")));

  const next = harness({ adminInstance: h.admin });
  assert.equal(await next.run(), REFUSED);
  assert.deepEqual(writesOf(next.calls), []);
  assert.ok(next.lines.error.some((l) => l.includes('"in_progress" (emulator hub pid 9999)')));
});

test("studentSearch written by triggers after a partial seed is reported, and the next run is refused", async () => {
  const triggers = (store) => {
    for (const uid of ["demo-student-01", "demo-student-02"]) store.set(`studentSearch/${uid}`, { studentId: uid });
  };
  const first = harness({ admin: { failOn: { [`getUser ${UIDS[0]}`]: "mismatch" }, onCommit: triggers } });
  assert.equal(await first.run(), 1);
  assert.ok(first.admin.store.has("studentSearch/demo-student-01"));

  const next = harness({ adminInstance: first.admin });
  assert.equal(await next.run(), REFUSED);
  assert.deepEqual(writesOf(next.calls), []);
  assert.ok(next.lines.error.some((l) => l.includes("not written by the seeder): studentSearch")), next.lines.error.join("\n"));

  const withoutMarker = harness({ admin: { docs: { "studentSearch/demo-student-01": { studentId: "x" } } } });
  assert.equal(await withoutMarker.run(), REFUSED);
  assert.deepEqual(writesOf(withoutMarker.calls), []);
});

// ── Read-only diagnosis of an interrupted seed ──────────────────────────────

async function partialState() {
  const first = harness({ admin: { failOn: { [`createUser ${UIDS[3]}`]: "reject" } } });
  assert.equal(await first.run(), 1);
  return first.admin;
}

test("an in_progress marker prints a read-only diagnosis of UIDs and counts, and the run stays refused", async () => {
  const next = harness({ adminInstance: await partialState() });
  assert.equal(await next.run(), REFUSED);
  const text = next.lines.error.join("\n");
  assert.match(text, /Read-only diagnosis of the interrupted seed \(nothing is written, changed or deleted\):/);
  assert.match(text, /Auth: 3 of 6 demo accounts exist: demo-admin-01, demo-supervisor-01, demo-teacher-01\./);
  assert.match(text, /Auth: 3 user\(s\) in total\./);
  assert.match(text, /Firestore users: 0 of 6 dataset documents exist\./);
  assert.match(text, /never makes the session acceptable for seeding/);
  for (const account of DEMO_ACCOUNTS) {
    for (const value of [account.email, account.name]) assert.ok(!text.includes(value), value);
  }

  const afterLoad = next.calls.slice(next.calls.findIndex((c) => c.startsWith("loadAdmin")) + 1);
  for (const call of afterLoad) assert.match(call, /^(listUsers|listCollections|read (get|getUser) |close$)/, call);
  assert.deepEqual(writesOf(next.calls), []);
  assert.ok(!next.calls.some(isDelete));
});

test("diagnosis read errors are reported as unknown, never as absent", async () => {
  const next = harness({ adminInstance: await partialState() });
  next.admin.failOn = { [`getUser ${UIDS[0]}`]: "reject", [`get users/${UIDS[1]}`]: "reject" };
  assert.equal(await next.run(), REFUSED);
  const text = next.lines.error.join("\n");
  assert.match(text, /Auth: 2 of 6 demo accounts exist: demo-supervisor-01, demo-teacher-01\./);
  assert.match(text, /Auth: could not check demo-admin-01 \(unavailable\)\./);
  assert.match(text, /Firestore users: 0 of 6 dataset documents exist; 1 could not be read\./);
  assert.deepEqual(writesOf(next.calls), []);
});

test("a failing diagnosis says so, claims nothing about the data, and the run stays refused", async () => {
  const state = await partialState();
  const next = harness({ adminInstance: state });
  const lines = [];
  const code = await runSeed({
    args: [],
    env: {},
    execArgv: [],
    platform: "win32",
    readFirebaseJson: () => repoFirebaseJson,
    fileExists: () => false,
    installEgress: () => ({ selfTest: async () => true, blockedAttempts: () => [] }),
    readiness: async () => [],
    identity: async () => VERIFIED,
    loadAdmin: async () => state,
    diagnose: async () => {
      throw new Error("emulator stopped answering");
    },
    log: () => {},
    error: (l) => lines.push(l),
  });
  assert.equal(code, REFUSED);
  assert.ok(lines.some((l) => l.includes('"in_progress"')));
  assert.ok(lines.includes("Read-only diagnosis failed: emulator stopped answering. This says nothing about which data exists."));
  assert.deepEqual(writesOf(next.calls), []);
});

test("a connection blocked during the diagnosis is reported, nothing is written and the run stays refused", async () => {
  const state = await partialState();
  const blocked = (calls) =>
    calls.some((c) => c.startsWith("read getUser")) ? [{ host: "oauth2.googleapis.com", port: 443 }] : [];
  const next = harness({ adminInstance: state, blocked });
  assert.equal(await next.run(), REFUSED);
  assert.deepEqual(writesOf(next.calls), []);
  assert.ok(!next.calls.some(isDelete));
  const text = next.lines.error.join("\n");
  assert.match(text, /Read-only diagnosis: 1 non-emulator connection attempt\(s\) were blocked; its output may be incomplete/);
  assert.ok(next.lines.error[0].startsWith('Seed refused: _seedMeta/demo is "in_progress"'), text);
  assert.ok(!next.lines.log.includes("Seeding demo dataset…"));

  const quiet = harness({ adminInstance: state });
  assert.equal(await quiet.run(), REFUSED);
  assert.ok(!quiet.lines.error.some((l) => l.includes("were blocked")));
});

test("the diagnosis code path contains no write, update or delete call", () => {
  const source = readFileSync(join(functionsDir, "scripts", "seed-emulator-dataset.mjs"), "utf8");
  const start = source.indexOf("export async function diagnosePartialSeed");
  assert.ok(start > 0);
  const body = source.slice(start);
  assert.doesNotMatch(body, /\.(create|update|set|delete|commit|batch|createUser|updateUser|add|runTransaction|bulkWriter)\(/);
});

test("the seeder source never calls delete APIs or emulator DELETE endpoints", () => {
  for (const file of ["seed-emulator.mjs", "seed-emulator-dataset.mjs", "seed-emulator-readiness.mjs"]) {
    const source = readFileSync(join(functionsDir, "scripts", file), "utf8");
    assert.doesNotMatch(source, /\.delete\(|deleteUser|recursiveDelete|method:\s*["']DELETE|\/emulator\/v1\/projects\/[^"'`]*\/(accounts|databases)/, file);
    assert.doesNotMatch(source, /\.set\(/, file);
  }
});

// ── Real entry point (child process) ────────────────────────────────────────

// The seeder refuses Node preload options, so the module spy is loaded by a
// runner script (no execArgv) that calls runSeed with its real defaults.
function runNode(nodeArgs, env = {}) {
  const base = Object.fromEntries(
    Object.entries(process.env).filter(
      ([k]) =>
        !/^(GOOGLE_APPLICATION_CREDENTIALS|GCLOUD_PROJECT|GOOGLE_CLOUD_PROJECT|.*_EMULATOR_HOST|NODE_OPTIONS|npm_config_node_options)$/i.test(k),
    ),
  );
  const res = spawnSync(process.execPath, nodeArgs, {
    cwd: functionsDir,
    env: { ...base, ...env },
    encoding: "utf8",
    timeout: 30000,
  });
  const loaded = /SEED_SPY firebase-admin-loaded=true/.test(res.stderr);
  return { status: res.status, stderr: res.stderr, loaded };
}

test("module spy detects firebase-admin when it is loaded (positive control)", () => {
  const { stderr } = runNode([spyRunner], { SPY_CONTROL: "1" });
  assert.match(stderr, /SEED_SPY firebase-admin-loaded=true/);
});

const UNSAFE_CASES = [
  [["--project", "rafiq-academy"], {}],
  [["dev"], {}],
  [[], { GOOGLE_APPLICATION_CREDENTIALS: "C:\\nonexistent\\sa.json" }],
  [[], { GCLOUD_PROJECT: "rafiq-academy" }],
  [[], { FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443" }],
  [[], { HTTPS_PROXY: "http://proxy.invalid:8080" }],
];

test("CLI: arguments and unsafe environments exit 64 without loading firebase-admin", () => {
  for (const [args, env] of UNSAFE_CASES) {
    const { status, stderr, loaded } = runNode([spyRunner, ...args], env);
    assert.equal(status, REFUSED, `${JSON.stringify([args, env])}\n${stderr}`);
    assert.match(stderr, /Seed refused:/);
    assert.equal(loaded, false, JSON.stringify([args, env]));
    assert.match(stderr, /SEED_SPY firebase-admin-loaded=false/);
  }
});

test("CLI: the real entry point refuses the same cases with exit 64", () => {
  for (const [args, env] of UNSAFE_CASES) {
    const { status, stderr } = runNode([entry, ...args], env);
    assert.equal(status, REFUSED, `${JSON.stringify([args, env])}\n${stderr}`);
    assert.match(stderr, /Seed refused:/);
  }
});

test("CLI: preloads via --require, --import, NODE_OPTIONS or npm node-options exit 64 before firebase-admin", () => {
  const spyPath = spy.replaceAll("\\", "/");
  const cases = [
    { nodeArgs: ["--require", spy, entry], expect: /extra option/ },
    { nodeArgs: ["--import=data:text/javascript,0", entry], expect: /extra option/ },
    { nodeArgs: [entry], env: { NODE_OPTIONS: `--require "${spyPath}"` }, expect: /NODE_OPTIONS is set/ },
    { nodeArgs: [entry], env: { npm_config_node_options: `--require "${spyPath}"` }, expect: /npm_config_node_options is set/ },
  ];
  for (const { nodeArgs, env, expect } of cases) {
    const label = JSON.stringify({ nodeArgs: nodeArgs.length, env: Object.keys(env ?? {}) });
    const { status, stderr, loaded } = runNode(nodeArgs, env);
    assert.equal(status, REFUSED, `${label}\n${stderr}`);
    assert.match(stderr, /Seed refused:/, label);
    assert.match(stderr, expect, label);
    assert.equal(loaded, false, label);
    assert.ok(!stderr.includes(spyPath) && !stderr.includes(spy), `${label}: value echoed`);
  }
});

test("package.json exposes seed:emulator as the fixed entry point only", () => {
  const pkg = JSON.parse(readFileSync(join(functionsDir, "package.json"), "utf8"));
  assert.equal(pkg.scripts["seed:emulator"], "node scripts/seed-emulator.mjs");
  for (const [name, cmd] of Object.entries(pkg.scripts)) {
    if (name !== "seed:emulator") assert.doesNotMatch(cmd, /seed-emulator/, name);
  }
});
