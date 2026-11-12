// Guarded entry point for `npm run test:fcm:emulator`.
//
//   npm run test:fcm:emulator
//
// Refuses (exit 64) before any emulator, test or network activity unless every
// project id the FCM emulator suites, firebase-admin or the Firebase CLI could
// read is exactly demo-rafiq-rules. Values already set in the environment are
// checked, never trusted, and never echoed.
//
// Outside an emulator (FIRESTORE_EMULATOR_HOST unset) it starts the Firestore
// emulator itself with the fixed `--project demo-rafiq-rules`, then re-enters
// this file inside it. Inside an emulator (`firebase emulators:exec ...`) it
// also checks the GCLOUD_PROJECT / FIREBASE_CONFIG the CLI derives from
// `--project`, so a wrong `--project` is refused before the tests start.
// Pure Node, no shell-specific syntax; arguments are refused so `npm run ...
// -- --project <id>` cannot change the target.
import { spawn } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const FCM_EMULATOR_PROJECT_ID = "demo-rafiq-rules";
export const FCM_EMULATOR_SUITES = [
  "test/fcm_ownership_gate.emulator.test.mjs",
  "test/fcm_token_ownership.emulator.test.mjs",
];

// Every variable a test, firebase-admin, @google-cloud/* or the Firebase CLI
// may take a project id from. If set, each must equal FCM_EMULATOR_PROJECT_ID.
export const PROJECT_ID_KEYS = [
  "RULES_TEST_PROJECT_ID",
  "GCLOUD_PROJECT",
  "GOOGLE_CLOUD_PROJECT",
  "GCP_PROJECT",
  "CLOUDSDK_CORE_PROJECT",
  "FIREBASE_PROJECT",
  "FIREBASE_PROJECT_ID",
];

// Emulator host variables: if set, they must point at the loopback interface.
export const EMULATOR_HOST_KEYS = [
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_FIRESTORE_EMULATOR_ADDRESS",
  "FIREBASE_AUTH_EMULATOR_HOST",
  "FIREBASE_STORAGE_EMULATOR_HOST",
  "STORAGE_EMULATOR_HOST",
  "FIREBASE_DATABASE_EMULATOR_HOST",
  "FIREBASE_EMULATOR_HUB",
  "PUBSUB_EMULATOR_HOST",
];

// Real credentials / production switches must not be present at all.
export const FORBIDDEN_KEYS = [
  "GOOGLE_APPLICATION_CREDENTIALS",
  "FIREBASE_TOKEN",
  "PRODUCTION_BACKEND_ENABLED",
];

const LOOPBACK = /^(127\.0\.0\.1|localhost|\[::1\]):\d{1,5}$/;

function lookup(env, key) {
  // Windows env names are case-insensitive; check every spelling.
  const hits = Object.keys(env).filter((k) => k.toUpperCase() === key && env[k] !== undefined);
  return hits.map((k) => [k, env[k]]);
}

/** Pure: returns a list of problems (names only, never values). */
export function checkFcmEmulatorEnv({ env, args, inEmulator }) {
  const problems = [];
  if (args.length !== 0) {
    problems.push(
      `takes no arguments (got ${args.length}); the emulator always runs with --project ${FCM_EMULATOR_PROJECT_ID}.`,
    );
  }
  for (const key of PROJECT_ID_KEYS) {
    for (const [name, value] of lookup(env, key)) {
      if (value !== FCM_EMULATOR_PROJECT_ID) problems.push(`${name} is set but is not ${FCM_EMULATOR_PROJECT_ID}.`);
    }
  }
  for (const [name, value] of lookup(env, "FIREBASE_CONFIG")) {
    let projectId;
    try {
      projectId = JSON.parse(value)?.projectId;
    } catch {
      projectId = undefined;
    }
    if (projectId !== FCM_EMULATOR_PROJECT_ID) {
      problems.push(`${name} is set but its projectId is not ${FCM_EMULATOR_PROJECT_ID}.`);
    }
  }
  for (const key of EMULATOR_HOST_KEYS) {
    for (const [name, value] of lookup(env, key)) {
      if (!LOOPBACK.test(value)) problems.push(`${name} is set but is not a loopback host:port.`);
    }
  }
  for (const key of FORBIDDEN_KEYS) {
    for (const [name, value] of lookup(env, key)) {
      if (value !== "") problems.push(`${name} must be unset.`);
    }
  }
  if (inEmulator) {
    // The Firebase CLI derives these from `--project`; a different --project
    // (or a missing one) shows up here.
    if (lookup(env, "GCLOUD_PROJECT").length === 0) {
      problems.push(`GCLOUD_PROJECT is missing; start the emulator with --project ${FCM_EMULATOR_PROJECT_ID}.`);
    }
  }
  return problems;
}

const here = dirname(fileURLToPath(import.meta.url));
const FUNCTIONS_DIR = join(here, "..");
const REPO_ROOT = join(FUNCTIONS_DIR, "..");

function run(command, args, options) {
  return new Promise((done) => {
    const child = spawn(command, args, { stdio: "inherit", ...options });
    child.on("error", (e) => {
      console.error(`Failed to start ${command}: ${e.message}`);
      done(1);
    });
    child.on("close", (code) => done(code ?? 1));
  });
}

export async function main({ env = process.env, args = process.argv.slice(2), error = console.error } = {}) {
  const inEmulator = lookup(env, "FIRESTORE_EMULATOR_HOST").length > 0;
  const problems = checkFcmEmulatorEnv({ env, args, inEmulator });
  if (problems.length > 0) {
    error("test:fcm:emulator refused (nothing was started):");
    for (const p of problems) error(`  - ${p}`);
    return 64;
  }
  if (!inEmulator) {
    // Fixed command string, no user input: the only --project is the demo one.
    const cmd =
      `firebase emulators:exec --project ${FCM_EMULATOR_PROJECT_ID} --only firestore ` +
      `"node functions/test/run_fcm_emulator.mjs"`;
    console.log(`> ${cmd}`);
    return run(cmd, [], { cwd: REPO_ROOT, shell: true });
  }
  const childEnv = { ...env, RULES_TEST_PROJECT_ID: FCM_EMULATOR_PROJECT_ID };
  return run(process.execPath, ["--test", "--test-concurrency=1", ...FCM_EMULATOR_SUITES], {
    cwd: FUNCTIONS_DIR,
    env: childEnv,
  });
}

function isEntryPoint() {
  if (!process.argv[1]) return false;
  const normalize = (p) => {
    const real = realpathSync(p);
    return process.platform === "win32" ? real.toLowerCase() : real;
  };
  return normalize(fileURLToPath(import.meta.url)) === normalize(process.argv[1]);
}

if (isEntryPoint()) {
  process.exitCode = await main();
}
