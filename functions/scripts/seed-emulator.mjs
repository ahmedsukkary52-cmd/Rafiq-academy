// Demo dataset seeder for the local Emulator Suite only.
//
//   npm run seed:emulator        (emulators started with `npm run serve`)
//
// Order, each step failing closed before the next:
//  1. no arguments                      (exit 64)
//  2. firebase.json emulator ports      (exit 64)
//  3. env: exact project, no credentials, no proxies, emulator hosts (exit 64)
//  4. network allowlist + self-test     (exit 64)
//  5. emulator readiness over 127.0.0.1 (exit 64)
//  6. load firebase-admin, re-check project and emulator hosts (exit 64)
//  7. read-only probes through the SDK; any blocked connection or existing
//     data refuses the run              (exit 64)
//  8. writes (create-only)              (exit 1 on failure, nothing deleted)
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { REPO_ROOT } from "./deploy-functions.mjs";
import {
  buildDemoDataset,
  classifyEmulatorState,
  SEED_MARKER_PHASE,
  SEED_META,
  writeDemoDataset,
} from "./seed-emulator-dataset.mjs";
import { installEgressGuard } from "./seed-emulator-egress.mjs";
import { checkSeedEnvironment, readEmulatorPorts, SEED_PROJECT_ID } from "./seed-emulator-guards.mjs";
import { checkEmulatorReadiness } from "./seed-emulator-readiness.mjs";

export const REFUSED = 64;
const PROBE_TIMEOUT_MS = 15000;

export async function loadFirebaseAdmin() {
  const { initializeApp, deleteApp } = await import("firebase-admin/app");
  const { getAuth } = await import("firebase-admin/auth");
  const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: SEED_PROJECT_ID }, "seed-emulator");
  return {
    projectId: app.options.projectId,
    auth: getAuth(app),
    db: getFirestore(app),
    serverTimestamp: () => FieldValue.serverTimestamp(),
    close: () => deleteApp(app),
  };
}

function withTimeout(promise, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${PROBE_TIMEOUT_MS} ms`)), PROBE_TIMEOUT_MS);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

const restartHelp =
  "`npm run serve` keeps emulator data in memory only: stop the emulators, start them again with `npm run serve`, " +
  "then re-run `npm run seed:emulator`.";

function failureHelp(phase) {
  const marker = `${SEED_META.collection}/${SEED_META.id}`;
  if (phase === SEED_MARKER_PHASE) {
    return (
      `Nothing was deleted, and no Auth user or document was written. Creating ${marker} failed, ` +
      `so it may or may not exist. ${restartHelp}`
    );
  }
  return `Nothing was deleted. ${marker} stays "in_progress", so the next run refuses to start. ${restartHelp}`;
}

export async function runSeed({
  args,
  env = process.env,
  platform = process.platform,
  readFirebaseJson = () => JSON.parse(readFileSync(join(REPO_ROOT, "firebase.json"), "utf8")),
  fileExists = existsSync,
  installEgress = installEgressGuard,
  readiness = checkEmulatorReadiness,
  loadAdmin = loadFirebaseAdmin,
  log = console.log,
  error = console.error,
}) {
  const refuse = (lines) => {
    for (const line of [].concat(lines)) error(`Seed refused: ${line}`);
    return REFUSED;
  };

  if (args.length !== 0) {
    return refuse(`npm run seed:emulator takes no arguments, got ${JSON.stringify(args)}.`);
  }

  let firebaseJson;
  try {
    firebaseJson = readFirebaseJson();
  } catch (e) {
    return refuse(`firebase.json could not be read: ${e.message}`);
  }
  const { problems: portProblems, ports } = readEmulatorPorts(firebaseJson);
  if (portProblems.length > 0) return refuse(portProblems);

  const { problems: envProblems, overrides } = checkSeedEnvironment({ env, platform, fileExists, ports });
  if (envProblems.length > 0) return refuse(envProblems);

  let egress;
  try {
    egress = installEgress({ allowedPorts: [ports.auth, ports.firestore, ports.hub] });
  } catch (e) {
    return refuse(`network allowlist could not be installed: ${e.message}`);
  }
  if (!(await egress.selfTest())) {
    return refuse("network allowlist self-test failed; external connections are not provably blocked.");
  }

  Object.assign(env, overrides);
  log(`Project: ${SEED_PROJECT_ID}`);
  log(`Auth emulator: ${overrides.FIREBASE_AUTH_EMULATOR_HOST}`);
  log(`Firestore emulator: ${overrides.FIRESTORE_EMULATOR_HOST}`);

  const notReady = await readiness({ ports });
  if (notReady.length > 0) return refuse(notReady);

  let admin;
  try {
    admin = await loadAdmin();
  } catch (e) {
    return refuse(`firebase-admin could not be initialized: ${e.message}`);
  }

  try {
    if (admin.projectId !== SEED_PROJECT_ID) {
      return refuse(`firebase-admin app project is ${JSON.stringify(admin.projectId)}; expected "${SEED_PROJECT_ID}".`);
    }
    for (const [key, value] of Object.entries(overrides)) {
      if (env[key] !== value) return refuse(`${key} changed to ${JSON.stringify(env[key])} after start-up.`);
    }

    let state;
    try {
      const [users, collections, meta] = await withTimeout(
        Promise.all([
          admin.auth.listUsers(10),
          admin.db.listCollections(),
          admin.db.collection(SEED_META.collection).doc(SEED_META.id).get(),
        ]),
        "emulator state probe",
      );
      state = {
        userCount: users.users.length,
        collectionIds: collections.map((c) => c.id),
        meta: meta.exists ? meta.data() : null,
      };
    } catch (e) {
      const blocked = egress.blockedAttempts();
      return refuse(
        blocked.length > 0
          ? `firebase-admin attempted non-emulator network access (${blocked.length} blocked).`
          : `emulator state probe failed: ${e.message}`,
      );
    }
    if (egress.blockedAttempts().length > 0) {
      return refuse("firebase-admin attempted non-emulator network access; refusing to write.");
    }

    const verdict = classifyEmulatorState(state);
    if (!verdict.ok) return refuse(verdict.reason);

    log("Seeding demo dataset…");
    try {
      await writeDemoDataset({
        dataset: buildDemoDataset(),
        auth: admin.auth,
        db: admin.db,
        serverTimestamp: admin.serverTimestamp,
        beforeComplete: () => {
          const blocked = egress.blockedAttempts().length;
          if (blocked > 0) throw new Error(`${blocked} non-emulator connection attempt(s) were blocked during seeding.`);
        },
        log,
      });
    } catch (e) {
      error(e.message);
      error(failureHelp(e.phase));
      return 1;
    }
    if (egress.blockedAttempts().length > 0) {
      error(
        `A non-emulator connection was attempted while ${SEED_META.collection}/${SEED_META.id} was being marked ` +
          `"complete"; it was blocked. Treat the dataset as unverified. ${restartHelp}`,
      );
      return 1;
    }
    log("Seed complete.");
    return 0;
  } finally {
    await Promise.resolve(admin.close?.()).catch(() => {});
  }
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
  const code = await runSeed({ args: process.argv.slice(2) });
  process.exit(code);
}
