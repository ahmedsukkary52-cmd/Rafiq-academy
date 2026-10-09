/**
 * Local-safety guard: the Functions emulator must only run against demo-*
 * projects. Covers the pure guard, the backend gate, and Functions startup
 * (lib/index.js loaded in a child process). No emulator or network.
 *
 * Run after `npm --prefix functions run build`.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");

const guard = require("../lib/emulatorProjectGuard.js");
const gate = require("../lib/productionGate.js");

const ENV_KEYS = [
  "FUNCTIONS_EMULATOR",
  "PRODUCTION_BACKEND_ENABLED",
  "GCLOUD_PROJECT",
  "GOOGLE_CLOUD_PROJECT",
  "FIREBASE_CONFIG",
];

function withEnv(overrides, run) {
  const previous = Object.fromEntries(ENV_KEYS.map((k) => [k, process.env[k]]));
  for (const k of ENV_KEYS) delete process.env[k];
  Object.assign(process.env, overrides);
  try {
    run();
  } finally {
    for (const k of ENV_KEYS) {
      if (previous[k] === undefined) delete process.env[k];
      else process.env[k] = previous[k];
    }
  }
}

const REAL_PROJECTS = ["rafiq-academy", "rafiq-academy-staging", "rafiq-academy-prod", "some-other-project"];

// ── Pure guard ──────────────────────────────────────────────────────────────

test("isDemoProjectId accepts only demo-* project IDs", () => {
  assert.equal(guard.isDemoProjectId("demo-rafiq-rules"), true);
  for (const id of [...REAL_PROJECTS, "demo-", "DEMO-rafiq", "xdemo-rafiq", " demo-rafiq", "", undefined, null, 42]) {
    assert.equal(guard.isDemoProjectId(id), false, String(id));
  }
});

test("demo project from any explicit source is safe", () => {
  const demo = "demo-rafiq-rules";
  assert.equal(guard.emulatorProjectProblem({ GCLOUD_PROJECT: demo }), null);
  assert.equal(guard.emulatorProjectProblem({ GOOGLE_CLOUD_PROJECT: demo }), null);
  assert.equal(
    guard.emulatorProjectProblem({ FIREBASE_CONFIG: JSON.stringify({ projectId: demo }) }),
    null,
  );
  assert.equal(guard.emulatorProjectProblem({}, demo), null);
  assert.equal(
    guard.emulatorProjectProblem(
      { GCLOUD_PROJECT: demo, GOOGLE_CLOUD_PROJECT: demo, FIREBASE_CONFIG: JSON.stringify({ projectId: demo }) },
      demo,
    ),
    null,
  );
});

test("every non-demo project is unsafe, from every source", () => {
  for (const id of REAL_PROJECTS) {
    assert.notEqual(guard.emulatorProjectProblem({ GCLOUD_PROJECT: id }), null, id);
    assert.notEqual(guard.emulatorProjectProblem({ GOOGLE_CLOUD_PROJECT: id }), null, id);
    assert.notEqual(
      guard.emulatorProjectProblem({ FIREBASE_CONFIG: JSON.stringify({ projectId: id }) }),
      null,
      id,
    );
    assert.notEqual(guard.emulatorProjectProblem({}, id), null, id);
  }
});

test("a single real source among demo sources is unsafe", () => {
  const demoConfig = JSON.stringify({ projectId: "demo-rafiq-rules" });
  assert.notEqual(
    guard.emulatorProjectProblem({ FIREBASE_CONFIG: demoConfig, GCLOUD_PROJECT: "rafiq-academy" }),
    null,
  );
  assert.notEqual(
    guard.emulatorProjectProblem({ GCLOUD_PROJECT: "demo-rafiq-rules" }, "rafiq-academy"),
    null,
  );
});

test("an unresolvable project is unsafe", () => {
  assert.notEqual(guard.emulatorProjectProblem({}), null);
  assert.notEqual(guard.emulatorProjectProblem({ GCLOUD_PROJECT: "" }), null);
  assert.notEqual(guard.emulatorProjectProblem({ FIREBASE_CONFIG: "/path/to/config.json" }), null);
  assert.notEqual(guard.emulatorProjectProblem({ FIREBASE_CONFIG: "{}" }), null);
  assert.notEqual(
    guard.emulatorProjectProblem({ FIREBASE_CONFIG: JSON.stringify({ projectId: 7 }) }),
    null,
  );
});

test("assertEmulatorProjectIsDemo is a no-op outside the emulator", () => {
  assert.doesNotThrow(() => guard.assertEmulatorProjectIsDemo({}));
  assert.doesNotThrow(() => guard.assertEmulatorProjectIsDemo({ GCLOUD_PROJECT: "rafiq-academy" }, "rafiq-academy"));
  assert.doesNotThrow(() => guard.assertEmulatorProjectIsDemo({ FUNCTIONS_EMULATOR: "false", GCLOUD_PROJECT: "rafiq-academy" }));
});

test("assertEmulatorProjectIsDemo throws in the emulator for real or missing projects", () => {
  assert.throws(() => guard.assertEmulatorProjectIsDemo({ FUNCTIONS_EMULATOR: "true" }));
  for (const id of REAL_PROJECTS) {
    assert.throws(() => guard.assertEmulatorProjectIsDemo({ FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: id }), id);
    assert.throws(() => guard.assertEmulatorProjectIsDemo({ FUNCTIONS_EMULATOR: "true" }, id), id);
  }
  assert.doesNotThrow(() =>
    guard.assertEmulatorProjectIsDemo({ FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: "demo-rafiq-rules" }, "demo-rafiq-rules"),
  );
});

// ── Backend gate ────────────────────────────────────────────────────────────

test("gate: FUNCTIONS_EMULATOR alone does not open the backend", () => {
  withEnv({ FUNCTIONS_EMULATOR: "true" }, () => {
    assert.equal(gate.isEmulatorBackendAllowed(), false);
    assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));
  });
});

test("gate: emulator with a real project stays closed", () => {
  for (const id of REAL_PROJECTS) {
    withEnv({ FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: id }, () => {
      assert.equal(gate.isEmulatorBackendAllowed(), false, id);
      assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"), id);
    });
    withEnv(
      { FUNCTIONS_EMULATOR: "true", FIREBASE_CONFIG: JSON.stringify({ projectId: id }) },
      () => assert.equal(gate.isEmulatorBackendAllowed(), false, id),
    );
  }
});

test("gate: emulator with a demo project opens the local backend", () => {
  withEnv({ FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: "demo-rafiq-rules" }, () => {
    assert.equal(gate.isEmulatorBackendAllowed(), true);
    assert.doesNotThrow(() => gate.assertBackendAllowed("adminProvisionUser"));
  });
});

test("gate: non-emulator behavior is unchanged", () => {
  withEnv({ GCLOUD_PROJECT: "rafiq-academy" }, () => {
    assert.equal(gate.isEmulatorBackendAllowed(), false);
    assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));
  });
  withEnv({ PRODUCTION_BACKEND_ENABLED: "true", GCLOUD_PROJECT: "rafiq-academy" }, () => {
    assert.equal(gate.isProductionBackendEnabled(), true);
    assert.doesNotThrow(() => gate.assertBackendAllowed("adminProvisionUser"));
  });
});

// ── Functions startup (child process; admin.initializeApp() is local) ───────

function loadIndex(env) {
  const base = Object.fromEntries(
    Object.entries(process.env).filter(([k]) => !ENV_KEYS.includes(k)),
  );
  return spawnSync(process.execPath, ["-e", "require('./lib/index.js')"], {
    cwd: functionsDir,
    env: { ...base, ...env },
    encoding: "utf8",
  });
}

test("startup: emulator with a real project fails before handlers load", () => {
  for (const env of [
    { FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: "rafiq-academy" },
    { FUNCTIONS_EMULATOR: "true", FIREBASE_CONFIG: JSON.stringify({ projectId: "rafiq-academy-prod" }) },
    { FUNCTIONS_EMULATOR: "true" },
  ]) {
    const res = loadIndex(env);
    assert.notEqual(res.status, 0, JSON.stringify(env));
    assert.match(res.stderr, /Refusing to load Functions in the emulator/, JSON.stringify(env));
  }
});

test("startup: emulator with a demo project loads", () => {
  const res = loadIndex({
    FUNCTIONS_EMULATOR: "true",
    FIREBASE_CONFIG: JSON.stringify({ projectId: "demo-rafiq-rules" }),
    GCLOUD_PROJECT: "demo-rafiq-rules",
  });
  assert.equal(res.status, 0, res.stderr);
});

test("startup: outside the emulator, a real project still loads", () => {
  const res = loadIndex({ GCLOUD_PROJECT: "rafiq-academy" });
  assert.equal(res.status, 0, res.stderr);
});
