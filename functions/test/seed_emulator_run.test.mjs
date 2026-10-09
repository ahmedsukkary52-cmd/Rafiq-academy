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

import { buildDemoDataset, SEED_META } from "../scripts/seed-emulator-dataset.mjs";
import { REFUSED, runSeed } from "../scripts/seed-emulator.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const entry = join(functionsDir, "scripts", "seed-emulator.mjs");
const spy = join(here, "fixtures", "seed_emulator_module_spy.cjs");
const repoFirebaseJson = JSON.parse(readFileSync(join(functionsDir, "..", "firebase.json"), "utf8"));

// ── Fakes ───────────────────────────────────────────────────────────────────

function fakeAdmin({ users = [], docs = {}, failOn = {}, projectId = "demo-rafiq-rules", calls }) {
  const store = new Map(Object.entries(docs));
  const authUsers = new Map(users.map((u) => [u.uid, u]));
  const record = (entry) => calls.push(entry);
  const maybeFail = (key) => {
    if (failOn[key]) throw new Error(`injected failure at ${key}`);
  };
  const ref = (collection, id) => {
    const path = `${collection}/${id}`;
    return {
      path,
      async create(data) {
        record(`create ${path}`);
        maybeFail(`create ${path}`);
        if (store.has(path)) throw new Error(`${path} already exists`);
        store.set(path, data);
      },
      async update(data) {
        record(`update ${path}`);
        maybeFail(`update ${path}`);
        store.set(path, { ...store.get(path), ...data });
      },
      async get() {
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
          maybeFail("commit");
          for (const [path, data] of pending) {
            if (store.has(path)) throw new Error(`${path} already exists`);
          }
          for (const [path, data] of pending) store.set(path, data);
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
      maybeFail(`createUser ${user.uid}`);
      if (authUsers.has(user.uid)) throw new Error("uid exists");
      authUsers.set(user.uid, user);
      return user;
    },
    async getUser(uid) {
      return authUsers.get(uid);
    },
    async deleteUser(uid) {
      record(`DELETE user ${uid}`);
    },
    async deleteUsers() {
      record("DELETE users");
    },
  };
  return {
    projectId,
    auth,
    db,
    store,
    authUsers,
    serverTimestamp: () => "SERVER_TS",
    close: async () => record("close"),
  };
}

function harness({
  args = [],
  env = {},
  firebaseJson = repoFirebaseJson,
  files = [],
  selfTest = true,
  blocked = [],
  readinessProblems = [],
  admin: adminOptions = {},
  loadAdminThrows = false,
} = {}) {
  const calls = [];
  const lines = { log: [], error: [] };
  const admin = fakeAdmin({ ...adminOptions, calls });
  const run = () =>
    runSeed({
      args,
      env,
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
      loadAdmin: async () => {
        calls.push(`loadAdmin env=${env.FIRESTORE_EMULATOR_HOST},${env.FIREBASE_AUTH_EMULATOR_HOST}`);
        if (loadAdminThrows) throw new Error("boom");
        return admin;
      },
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
  assert.deepEqual(ok.calls.slice(0, 4), [
    "readFirebaseJson",
    "installEgress 9099,8080,4400",
    "selfTest",
    "readiness 4400,9099,8080 env=127.0.0.1:8080",
  ]);
  assert.equal(ok.calls[4], "loadAdmin env=127.0.0.1:8080,127.0.0.1:9099");
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
  assert.equal(h.admin.store.get(`${SEED_META.collection}/${SEED_META.id}`).status, "complete");
  for (const doc of dataset.documents) {
    assert.ok(h.admin.store.has(`${doc.collection}/${doc.id}`), `${doc.collection}/${doc.id}`);
  }
  assert.ok(h.calls.includes("close"));
});

test("a failure part-way stops, deletes nothing and leaves the marker in_progress", async () => {
  const dataset = buildDemoDataset();
  const failures = [
    { [`createUser ${dataset.authUsers[2].uid}`]: true },
    { commit: true },
    { [`update ${SEED_META.collection}/${SEED_META.id}`]: true },
  ];
  for (const failOn of failures) {
    const h = harness({ admin: { failOn } });
    assert.equal(await h.run(), 1, JSON.stringify(failOn));
    assert.ok(!h.calls.some(isDelete), JSON.stringify(failOn));
    assert.equal(h.admin.store.get(`${SEED_META.collection}/${SEED_META.id}`).status, "in_progress");
    assert.ok(h.lines.error.some((l) => l.includes("Nothing was deleted")));
  }

  const midway = harness({ admin: { failOn: { [`createUser ${dataset.authUsers[2].uid}`]: true } } });
  await midway.run();
  assert.ok(!midway.calls.some((c) => c.startsWith("commit")));
  assert.ok(!midway.calls.includes(`createUser ${dataset.authUsers[3].uid}`));
});

test("a failed seed marker create stops before any Auth user or document", async () => {
  const marker = `${SEED_META.collection}/${SEED_META.id}`;
  const h = harness({ admin: { failOn: { [`create ${marker}`]: true } } });
  assert.equal(await h.run(), 1);
  assert.deepEqual(h.calls.filter(isWrite), [`create ${marker}`]);
  assert.ok(!h.calls.some(isDelete));
  assert.ok(h.lines.error.some((l) => l.includes("no Auth user or document was written")));
  assert.ok(!h.lines.error.some((l) => l.includes('stays "in_progress"')));
});

test("a blocked connection during writes fails the run before the marker is completed", async () => {
  const marker = `${SEED_META.collection}/${SEED_META.id}`;
  const h = harness({ blocked: (calls) => (calls.some((c) => c.startsWith("commit")) ? [{ host: "x", port: 1 }] : []) });
  assert.equal(await h.run(), 1);
  assert.ok(!h.calls.some(isDelete));
  assert.ok(!h.calls.includes(`update ${marker}`), h.calls.join("\n"));
  assert.equal(h.admin.store.get(marker).status, "in_progress");
  assert.ok(h.lines.error.some((l) => l.includes("pre-completion check") && l.includes("blocked")));
  assert.ok(h.lines.error.some((l) => l.includes('stays "in_progress"')));
});

test("the seeder source never calls delete APIs or emulator DELETE endpoints", () => {
  for (const file of ["seed-emulator.mjs", "seed-emulator-dataset.mjs", "seed-emulator-readiness.mjs"]) {
    const source = readFileSync(join(functionsDir, "scripts", file), "utf8");
    assert.doesNotMatch(source, /\.delete\(|deleteUser|recursiveDelete|method:\s*["']DELETE|\/emulator\/v1\/projects\/[^"'`]*\/(accounts|databases)/, file);
    assert.doesNotMatch(source, /\.set\(/, file);
  }
});

// ── Real entry point (child process) ────────────────────────────────────────

function runEntry(args, env, { preload = true } = {}) {
  const base = Object.fromEntries(
    Object.entries(process.env).filter(
      ([k]) => !/^(GOOGLE_APPLICATION_CREDENTIALS|GCLOUD_PROJECT|GOOGLE_CLOUD_PROJECT|.*_EMULATOR_HOST)$/i.test(k),
    ),
  );
  const res = spawnSync(process.execPath, [...(preload ? ["--require", spy] : []), entry, ...args], {
    cwd: functionsDir,
    env: { ...base, ...env },
    encoding: "utf8",
    timeout: 30000,
  });
  const loaded = /SEED_SPY firebase-admin-loaded=true/.test(res.stderr);
  return { status: res.status, stderr: res.stderr, loaded };
}

test("module spy detects firebase-admin when it is loaded (positive control)", () => {
  const res = spawnSync(
    process.execPath,
    ["--require", spy, "--input-type=module", "-e", "await import('firebase-admin/app');"],
    { cwd: functionsDir, encoding: "utf8", timeout: 30000 },
  );
  assert.match(res.stderr, /SEED_SPY firebase-admin-loaded=true/);
});

test("CLI: arguments and unsafe environments exit 64 without loading firebase-admin", () => {
  const cases = [
    [["--project", "rafiq-academy"], {}],
    [["dev"], {}],
    [[], { GOOGLE_APPLICATION_CREDENTIALS: "C:\\nonexistent\\sa.json" }],
    [[], { GCLOUD_PROJECT: "rafiq-academy" }],
    [[], { FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443" }],
    [[], { HTTPS_PROXY: "http://proxy.invalid:8080" }],
  ];
  for (const [args, env] of cases) {
    const { status, stderr, loaded } = runEntry(args, env);
    assert.equal(status, REFUSED, `${JSON.stringify([args, env])}\n${stderr}`);
    assert.match(stderr, /Seed refused:/);
    assert.equal(loaded, false, JSON.stringify([args, env]));
    assert.match(stderr, /SEED_SPY firebase-admin-loaded=false/);
  }
});

test("package.json exposes seed:emulator as the fixed entry point only", () => {
  const pkg = JSON.parse(readFileSync(join(functionsDir, "package.json"), "utf8"));
  assert.equal(pkg.scripts["seed:emulator"], "node scripts/seed-emulator.mjs");
  for (const [name, cmd] of Object.entries(pkg.scripts)) {
    if (name !== "seed:emulator") assert.doesNotMatch(cmd, /seed-emulator/, name);
  }
});
