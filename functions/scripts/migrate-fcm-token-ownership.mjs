// One-off backfill of FCM token ownership (H2) for device records written
// before the reconcileFcmTokenOwnership trigger existed.
//
//   node scripts/migrate-fcm-token-ownership.mjs --project <id>            (dry run)
//   node scripts/migrate-fcm-token-ownership.mjs --project demo-rafiq-rules --apply \
//     --confirm fcm-token-ownership:demo-rafiq-rules                     (emulator only)
//
// Dry run is read-only and is the default. --apply is refused for every
// project except WRITE_PROJECT, and only while FIRESTORE_EMULATOR_HOST points
// at a loopback emulator; real-project writes are not enabled in this runner.
//
// The whole fcmTokens/{uid}/devices collection group is scanned first (a
// shared token can span pages); a scan that hits maxDocs aborts before any
// write. Enabled records are grouped by sha256(token) and each group is
// classified against fcmTokenOwners/{hash}:
//   - owned / owned with stale holders / released / owner not holding /
//     malformed owner: reported, never written. Senders already skip every
//     holder the owner record does not name.
//   - legacy (no owner record) with one holder, or with a single strictly
//     newest holder by server updateTime: apply reconciles through the same
//     transaction as the trigger (newest first, so it claims; older holders
//     are disabled with disabledReason "token_transferred").
//   - legacy with a tie for newest: ambiguous, reported, never written.
// Before writing a group, its owner doc and holders are re-read; any change
// since the scan skips the group. Re-running converges (owned groups are
// left alone). Output is counts plus capped uid/deviceId lists; tokens and
// token hashes are never printed or persisted.
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
  bump,
  checkMigrationTarget,
  credentialFileProjectId,
  isSafeId,
  parseMigrationArgs,
  safeErrorCode,
} from "./migrate-guards.mjs";

export const SCRIPT_ID = "fcm-token-ownership";

/** The only project --apply may target: the local Firestore emulator demo. */
export const WRITE_PROJECT = "demo-rafiq-rules";

export const FCM_TOKENS_COLLECTION = "fcmTokens";
export const FCM_DEVICES_SUBCOLLECTION = "devices";
export const FCM_TOKEN_OWNERS_COLLECTION = "fcmTokenOwners";
const MAX_TOKEN_LENGTH = 4096;
const LOOPBACK_HOST = /^(127\.0\.0\.1|localhost):\d{1,5}$/;

export const GROUP = Object.freeze({
  owned: "owned",
  ownedWithStaleHolders: "ownedWithStaleHolders",
  released: "releasedWithStaleHolders",
  ownerNotHolding: "ownerNotHolding",
  ownerMalformed: "ownerMalformed",
  legacySingle: "legacySingleHolder",
  legacyShared: "legacySharedNewestWins",
  legacyTie: "legacyAmbiguousTie",
});

const WRITABLE = new Set([GROUP.legacySingle, GROUP.legacyShared]);
const REVIEW = [
  GROUP.ownedWithStaleHolders,
  GROUP.released,
  GROUP.ownerNotHolding,
  GROUP.ownerMalformed,
  GROUP.legacyTie,
];

/** Same predicate as fcmTokenContract.isUsableToken. */
export function isUsableToken(value) {
  return typeof value === "string" && value.trim().length > 0 && value.length <= MAX_TOKEN_LENGTH;
}

/** Same id as fcmTokenOwnership.tokenOwnerDocId. */
export function tokenHash(token) {
  return createHash("sha256").update(token.trim()).digest("hex");
}

/** Hash of the enabled token held by device [data], else null. */
function enabledTokenHash(data) {
  if (!data || data.disabled === true || !isUsableToken(data.token)) return null;
  return tokenHash(data.token);
}

/** { uid, deviceId } for `fcmTokens/{uid}/devices/{deviceId}`, else null. */
export function parseDevicePath(path) {
  const parts = path.split("/");
  if (parts.length !== 4) return null;
  if (parts[0] !== FCM_TOKENS_COLLECTION || parts[2] !== FCM_DEVICES_SUBCOLLECTION) return null;
  return { uid: parts[1], deviceId: parts[3] };
}

function compareTime(a, b) {
  if (a.seconds !== b.seconds) return a.seconds < b.seconds ? -1 : 1;
  if (a.nanoseconds !== b.nanoseconds) return a.nanoseconds < b.nanoseconds ? -1 : 1;
  return 0;
}

const validTime = (t) => Number.isInteger(t?.seconds) && Number.isInteger(t?.nanoseconds);

/**
 * Decides what to do with one token. Pure. [holders]: enabled records
 * holding it, `{ uid, deviceId, updateTime }`. [owner]: the owner doc's data,
 * or null when there is none. Returns `{ group, newest? }`.
 */
export function classifyTokenGroup({ holders, owner }) {
  if (owner) {
    if (typeof owner.uid === "string" && typeof owner.deviceId === "string") {
      const ownerHolds = holders.some((h) => h.uid === owner.uid && h.deviceId === owner.deviceId);
      if (!ownerHolds) return { group: GROUP.ownerNotHolding };
      return { group: holders.length === 1 ? GROUP.owned : GROUP.ownedWithStaleHolders };
    }
    if (owner.uid === undefined && owner.deviceId === undefined && owner.releasedAt !== undefined) {
      return { group: GROUP.released };
    }
    return { group: GROUP.ownerMalformed };
  }
  if (holders.length === 0) throw new Error("a token group needs at least one holder");
  if (holders.some((h) => !validTime(h.updateTime))) return { group: GROUP.legacyTie };
  const sorted = [...holders].sort((a, b) => compareTime(b.updateTime, a.updateTime));
  if (sorted.length === 1) return { group: GROUP.legacySingle, newest: sorted[0] };
  if (compareTime(sorted[0].updateTime, sorted[1].updateTime) === 0) return { group: GROUP.legacyTie };
  return { group: GROUP.legacyShared, newest: sorted[0] };
}

/** Capped list of `uid/deviceId` refs; refs with unsafe ids are only counted. */
function createRefList(cap = 50) {
  const refs = [];
  let total = 0;
  let unprintable = 0;
  return {
    add({ uid, deviceId }) {
      total += 1;
      if (!isSafeId(uid) || !isSafeId(deviceId)) unprintable += 1;
      else if (refs.length < cap) refs.push(`${uid}/${deviceId}`);
    },
    toJSON() {
      return { total, refs, truncated: total - unprintable > refs.length, unprintable };
    },
  };
}

/** Throws unless writes would land on the loopback emulator of WRITE_PROJECT. */
export function assertEmulatorWriteTarget({ projectId, env }) {
  if (projectId !== WRITE_PROJECT) throw new Error("apply is limited to the emulator demo project");
  if (!LOOPBACK_HOST.test(env.FIRESTORE_EMULATOR_HOST ?? "")) {
    throw new Error("apply needs FIRESTORE_EMULATOR_HOST on loopback");
  }
}

/**
 * Problems specific to this runner, on top of checkMigrationTarget. Checked
 * independently of it so a widened migration allowlist cannot open writes.
 */
export function applyTargetProblems({ args, env }) {
  if (!args.apply) return [];
  const problems = [];
  if (args.project !== WRITE_PROJECT) {
    problems.push(`--apply is limited to ${WRITE_PROJECT}; real-project writes are not enabled in this runner.`);
  }
  if (!LOOPBACK_HOST.test(env.FIRESTORE_EMULATOR_HOST ?? "")) {
    problems.push("--apply needs FIRESTORE_EMULATOR_HOST pointing at a loopback emulator.");
  }
  if (env.GOOGLE_APPLICATION_CREDENTIALS) {
    problems.push("--apply refuses to run with GOOGLE_APPLICATION_CREDENTIALS set.");
  }
  return problems;
}

async function getAllChunked(db, refs, size = 100) {
  const out = [];
  for (let i = 0; i < refs.length; i += size) out.push(...(await db.getAll(...refs.slice(i, i + size))));
  return out;
}

const ownerRef = (db, hash) => db.collection(FCM_TOKEN_OWNERS_COLLECTION).doc(hash);
const deviceRef = (db, { uid, deviceId }) =>
  db.collection(FCM_TOKENS_COLLECTION).doc(uid).collection(FCM_DEVICES_SUBCOLLECTION).doc(deviceId);

/**
 * In "apply" mode only legacy groups write, each through [reconcile]
 * (`(db, { uid, deviceId, skipReleased: true }) => outcome`, i.e.
 * fcmTokenOwnership.reconcileDeviceTokenOwnership), after
 * [assertWriteTarget] passes.
 */
export async function runTokenOwnershipBackfill({
  db,
  mode,
  documentId,
  reconcile,
  assertWriteTarget,
  pageSize = 300,
  maxDocs = 50_000,
}) {
  if (mode !== "dry-run" && mode !== "apply") throw new Error("mode must be dry-run or apply");
  if (mode === "apply") {
    if (typeof reconcile !== "function" || typeof assertWriteTarget !== "function") {
      throw new Error("apply needs reconcile and assertWriteTarget");
    }
    assertWriteTarget();
  }

  const scan = { documents: 0, nonFcmPaths: 0, disabledOrUnusable: 0, enabledRecords: 0, tokens: 0 };
  const groups = new Map();
  let last = null;
  for (;;) {
    let query = db.collectionGroup(FCM_DEVICES_SUBCOLLECTION).orderBy(documentId).limit(pageSize);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    for (const doc of page.docs) {
      scan.documents += 1;
      const ids = parseDevicePath(doc.ref.path);
      if (!ids) {
        scan.nonFcmPaths += 1;
        continue;
      }
      const hash = enabledTokenHash(doc.data());
      if (hash === null) {
        scan.disabledOrUnusable += 1;
        continue;
      }
      scan.enabledRecords += 1;
      if (!groups.has(hash)) groups.set(hash, []);
      groups.get(hash).push({ ...ids, updateTime: doc.updateTime });
    }
    if (scan.documents > maxDocs) {
      return { script: SCRIPT_ID, mode, aborted: "scanLimitExceeded", maxDocs, scan, written: emptyWritten() };
    }
    if (page.docs.length < pageSize) break;
    last = page.docs[page.docs.length - 1];
  }
  scan.tokens = groups.size;

  const hashes = [...groups.keys()].sort();
  const ownerSnaps = await getAllChunked(db, hashes.map((h) => ownerRef(db, h)));
  const counts = Object.fromEntries(Object.values(GROUP).map((g) => [g, 0]));
  const review = Object.fromEntries(
    [...REVIEW, "skippedChangedSinceScan", "unexpectedOutcome", "failed"].map((k) => [k, createRefList()]),
  );
  const plan = [];
  hashes.forEach((hash, i) => {
    const holders = groups.get(hash);
    const owner = ownerSnaps[i].exists ? ownerSnaps[i].data() ?? {} : null;
    const { group, newest } = classifyTokenGroup({ holders, owner });
    counts[group] += 1;
    if (review[group]) {
      const flagged = group === GROUP.ownedWithStaleHolders
        ? holders.filter((h) => h.uid !== owner.uid || h.deviceId !== owner.deviceId)
        : holders;
      flagged.forEach((h) => review[group].add(h));
    }
    if (WRITABLE.has(group)) plan.push({ hash, holders, newest });
  });

  const written = emptyWritten();
  const errors = {};
  if (mode === "apply") {
    for (const { hash, holders, newest } of plan) {
      const others = holders.filter((h) => h !== newest);
      const [ownerNow, ...holderNow] = await db.getAll(
        ownerRef(db, hash),
        ...holders.map((h) => deviceRef(db, h)),
      );
      const unchanged = !ownerNow.exists && holderNow.every((snap, i) =>
        snap.exists &&
        enabledTokenHash(snap.data()) === hash &&
        validTime(snap.updateTime) &&
        compareTime(snap.updateTime, holders[i].updateTime) === 0);
      if (!unchanged) {
        written.skippedChangedSinceScan += 1;
        review.skippedChangedSinceScan.add(newest);
        continue;
      }
      try {
        assertWriteTarget();
        const first = await reconcile(db, { uid: newest.uid, deviceId: newest.deviceId, skipReleased: true });
        if (first !== "claimed") {
          written.unexpectedOutcome += 1;
          review.unexpectedOutcome.add(newest);
          continue;
        }
        written.claimed += 1;
        for (const holder of others) {
          const outcome = await reconcile(db, { uid: holder.uid, deviceId: holder.deviceId, skipReleased: true });
          if (outcome === "lost_to_newer") written.olderHoldersDisabled += 1;
          else {
            written.unexpectedOutcome += 1;
            review.unexpectedOutcome.add(holder);
          }
        }
      } catch (error) {
        bump(errors, safeErrorCode(error));
        review.failed.add(newest);
      }
    }
  }

  return {
    script: SCRIPT_ID,
    mode,
    aborted: null,
    scan,
    groups: counts,
    plannedGroups: plan.length,
    written,
    errors,
    review: Object.fromEntries(Object.entries(review).map(([key, list]) => [key, list.toJSON()])),
  };
}

function emptyWritten() {
  return { claimed: 0, olderHoldersDisabled: 0, skippedChangedSinceScan: 0, unexpectedOutcome: 0 };
}

async function main() {
  const env = process.env;
  const args = parseMigrationArgs(process.argv.slice(2));
  const credential = credentialFileProjectId(env, (path) => readFileSync(path, "utf8"));
  const { problems, mode } = checkMigrationTarget({
    scriptId: SCRIPT_ID,
    args,
    env,
    credentialProjectId: credential.projectId,
    needsAuth: false,
  });
  if (credential.problem) problems.push(credential.problem);
  problems.push(...applyTargetProblems({ args, env }));
  const libPath = join(dirname(fileURLToPath(import.meta.url)), "..", "lib", "notifications", "fcmTokenOwnership.js");
  if (args.apply && !existsSync(libPath)) {
    problems.push("--apply needs the compiled functions (npm run build).");
  }
  if (problems.length > 0) {
    for (const problem of problems) console.error(`refused: ${problem}`);
    process.exit(2);
  }

  const { initializeApp } = await import("firebase-admin/app");
  const { getFirestore, FieldPath } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: args.project });
  if (app.options.projectId !== args.project) {
    console.error("refused: firebase-admin resolved a different project.");
    process.exit(2);
  }
  let reconcile;
  let assertWriteTarget;
  if (mode === "apply") {
    const ownership = await import(pathToFileURL(libPath).href);
    reconcile = ownership.reconcileDeviceTokenOwnership ?? ownership.default?.reconcileDeviceTokenOwnership;
    assertWriteTarget = () => assertEmulatorWriteTarget({ projectId: app.options.projectId, env: process.env });
  }
  console.error(`${SCRIPT_ID}: ${mode} on ${args.project}`);
  const report = await runTokenOwnershipBackfill({
    db: getFirestore(app),
    mode,
    documentId: FieldPath.documentId(),
    reconcile,
    assertWriteTarget,
  });
  console.log(JSON.stringify({ project: args.project, ...report }, null, 2));
  if (report.aborted) process.exit(3);
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main().catch((error) => {
    console.error(`${SCRIPT_ID} failed: ${safeErrorCode(error)}`);
    process.exit(1);
  });
}
