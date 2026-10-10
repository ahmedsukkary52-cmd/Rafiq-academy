// Demo dataset seeder for the local Emulator Suite only.
//
//   npm run seed:emulator        (emulators started with `npm run serve`)
//
// Order, each step failing closed before the next:
//  1. no extra Node options (NODE_OPTIONS, execArgv, npm node-options) (exit 64)
//  2. no arguments                      (exit 64)
//  3. firebase.json emulator ports      (exit 64)
//  4. env: exact project, no credentials, no proxies, emulator hosts (exit 64)
//  5. network allowlist + self-test     (exit 64)
//  6. emulator readiness over 127.0.0.1 (exit 64)
//  7. emulator identity: hub pid + locator file + UI projectId (exit 64)
//  8. load firebase-admin, re-check project and emulator hosts (exit 64)
//  9. read-only probes through the SDK; any blocked connection or existing
//     data refuses the run              (exit 64); a leftover "in_progress"
//     marker also prints a read-only diagnosis of the partial seed
// 10. writes (create-only, one bounded wait per step, no seeder retries)
//                                       (exit 1 on failure or timeout, nothing deleted)
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { REPO_ROOT } from "./deploy-functions.mjs";
import {
  buildDemoDataset,
  classifyEmulatorState,
  diagnosePartialSeed,
  SEED_COMPLETION_PHASE,
  SEED_MARKER_PHASE,
  SEED_META,
  SEED_STEP_TIMEOUT_MS,
  SeedWriteError,
  USER_PROBE_PAGE,
  writeDemoDataset,
} from "./seed-emulator-dataset.mjs";
import { installEgressGuard } from "./seed-emulator-egress.mjs";
import {
  checkNodePreload,
  checkSeedEnvironment,
  readEmulatorPorts,
  SEED_PROJECT_ID,
} from "./seed-emulator-guards.mjs";
import { checkEmulatorIdentity, checkEmulatorReadiness } from "./seed-emulator-readiness.mjs";

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

export const RETRY_HELP =
  "Do not re-run the seeder against this emulator session. To retry: stop `npm run serve` (Ctrl+C in its " +
  "terminal), start a new session with `npm run serve` only (never --import or --export-on-exit), then run " +
  "`npm run seed:emulator`. Restarting does not by itself prove the emulator is empty: the seeder's own " +
  "pre-write checks decide whether the new session is accepted.";

export function failureHelp(phase, session = {}, timedOut = false) {
  const marker = `${SEED_META.collection}/${SEED_META.id}`;
  const where = session.hubPid ? ` (emulator hub pid ${session.hubPid})` : "";
  const outcome = timedOut
    ? `The ${phase} step did not answer in time. Its request was not cancelled and may still be applied, ` +
      "so the emulator may hold more partial data than this run saw. "
    : "";
  if (phase === SEED_MARKER_PHASE) {
    return (
      `Nothing was deleted, and no Auth user or document was written. ${outcome}Creating ${marker}${where} ` +
      `failed, so it may or may not exist. ${RETRY_HELP}`
    );
  }
  if (phase === SEED_COMPLETION_PHASE) {
    return (
      `Nothing was deleted. Every Auth user and document had been written and verified. ${outcome}` +
      `${marker}${where} may be "in_progress" or "complete": the outcome of its update is unknown, so treat the ` +
      `dataset as unverified. ${RETRY_HELP}`
    );
  }
  if (phase === undefined) {
    return (
      `Nothing was deleted. ${outcome}The run stopped on an unexpected error, so which writes were applied is ` +
      `unknown and the state of ${marker}${where} is indeterminate (missing, or "in_progress"). ${RETRY_HELP}`
    );
  }
  return (
    `Nothing was deleted. ${outcome}The failed step's own write may or may not have been applied. ` +
    `This run created ${marker}${where} as "in_progress" and sent no update to it, so it is not "complete" ` +
    `unless something else changed it; the next run reads it and refuses to start. ${RETRY_HELP}`
  );
}

export async function runSeed({
  args,
  env = process.env,
  execArgv = process.execArgv,
  platform = process.platform,
  readFirebaseJson = () => JSON.parse(readFileSync(join(REPO_ROOT, "firebase.json"), "utf8")),
  fileExists = existsSync,
  installEgress = installEgressGuard,
  readiness = checkEmulatorReadiness,
  identity = checkEmulatorIdentity,
  loadAdmin = loadFirebaseAdmin,
  writeStepTimeoutMs = SEED_STEP_TIMEOUT_MS,
  diagnose = diagnosePartialSeed,
  log = console.log,
  error = console.error,
}) {
  const refuse = (lines) => {
    for (const line of [].concat(lines)) error(`Seed refused: ${line}`);
    return REFUSED;
  };

  const preloadProblems = checkNodePreload({ env, execArgv });
  if (preloadProblems.length > 0) return refuse(preloadProblems);

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
    egress = installEgress({ allowedPorts: [ports.auth, ports.firestore, ports.hub, ports.ui] });
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

  const { problems: identityProblems, hubPid, cliVersion } = await identity({ ports });
  if (identityProblems.length > 0) return refuse(identityProblems);
  const session = { hubPid, cliVersion };
  log(`Emulator hub pid ${hubPid} (firebase-tools ${cliVersion}) verified for ${SEED_PROJECT_ID}`);

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
          admin.auth.listUsers(USER_PROBE_PAGE),
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
          : `emulator state probe failed: ${e.message}; the emulator's state is unknown.`,
      );
    }
    if (egress.blockedAttempts().length > 0) {
      return refuse("firebase-admin attempted non-emulator network access; refusing to write.");
    }

    const verdict = classifyEmulatorState(state);
    if (!verdict.ok) {
      refuse(verdict.reason);
      if (state.meta?.status === "in_progress") {
        const blockedBefore = egress.blockedAttempts().length;
        try {
          const lines = await withTimeout(
            diagnose({
              dataset: buildDemoDataset(),
              auth: admin.auth,
              db: admin.db,
              collectionIds: state.collectionIds,
              userCount: state.userCount,
            }),
            "partial-seed diagnosis",
          );
          for (const line of lines) error(line);
        } catch (e) {
          error(`Read-only diagnosis failed: ${e.message}. This says nothing about which data exists.`);
        }
        const blockedDuring = egress.blockedAttempts().length - blockedBefore;
        if (blockedDuring > 0) {
          error(
            `Read-only diagnosis: ${blockedDuring} non-emulator connection attempt(s) were blocked; ` +
              "its output may be incomplete and says nothing certain about which data exists.",
          );
        }
      }
      return REFUSED;
    }

    log("Seeding demo dataset…");
    try {
      await writeDemoDataset({
        dataset: buildDemoDataset(),
        auth: admin.auth,
        db: admin.db,
        serverTimestamp: admin.serverTimestamp,
        session,
        stepTimeoutMs: writeStepTimeoutMs,
        beforeComplete: () => {
          const blocked = egress.blockedAttempts().length;
          if (blocked > 0) throw new Error(`${blocked} non-emulator connection attempt(s) were blocked during seeding.`);
        },
        log,
      });
    } catch (e) {
      error(e.message);
      const known = e instanceof SeedWriteError;
      error(failureHelp(known ? e.phase : undefined, session, known && e.timedOut === true));
      return 1;
    }
    if (egress.blockedAttempts().length > 0) {
      error(
        `A non-emulator connection was attempted while ${SEED_META.collection}/${SEED_META.id} was being marked ` +
          `"complete"; it was blocked. Treat the dataset as unverified. ${RETRY_HELP}`,
      );
      return 1;
    }
    log("Seed complete.");
    return 0;
  } finally {
    await withTimeout(Promise.resolve().then(() => admin.close?.()), "closing firebase-admin").catch(() => {});
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
