// B14 — copies legacy `halaqat/{id}.meetingLink` values into the canonical
// `halaqaMeetingLinks/{id}` documents. Milestone 1: the isolated Firestore
// emulator for `demo-rafiq-rules` only; there is no mode for a real project.
//
//   node scripts/migrate-meeting-links.mjs                          (plan only)
//   node scripts/migrate-meeting-links.mjs --project demo-rafiq-rules       (dry run)
//   node scripts/migrate-meeting-links.mjs --project demo-rafiq-rules --apply \
//     --confirm meeting-link-migration:demo-rafiq-rules
//
// Required for a dry run or apply:
//   MEETING_LINK_MIGRATION_EMULATOR=1
//   MEETING_LINK_MIGRATION_PORTS="<firestorePort>,<hubPort>" (non-default, distinct)
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:<firestorePort>
//   FIREBASE_EMULATOR_HUB=127.0.0.1:<hubPort>
//
// Layered guards, none sufficient alone: fixed project constant; environment
// consistency checks (they only detect misconfiguration); a process-wide
// egress guard installed before firebase-admin loads (the actual network
// boundary, limited to this process's net/dns modules); an emulator hub check;
// a check of the project firebase-admin resolved; and a narrow data surface
// (a read-only store, plus in apply mode a writer whose only operation is the
// per-halaqa transaction below).
//
// Writes: only `tx.create` of a missing canonical document, decided from a
// transactional re-read of the halaqa and its canonical document. Nothing is
// ever overwritten, repaired or deleted, and `halaqat` is never written.
// The race argument relies on every canonical writer (setHalaqaMeetingLink,
// adminCreateHalaqa) also writing the halaqa document in the same
// transaction; run this only while that holds.
//
// Output: one JSON report of counts, reason codes and capped halaqa ids.
// Link values, any part of a URL, student/supervisor ids and raw error
// messages are never printed.
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { installEgressGuard } from "./seed-emulator-egress.mjs";
import {
  LINK_ISSUES,
  MALFORMED_REASONS,
  classifyCanonical,
  classifyLegacy,
  decide,
  isValidDocumentId,
} from "./meeting-link-migration-core.mjs";

export { LINK_ISSUES, MALFORMED_REASONS, classifyCanonical, classifyLegacy, decide, isValidDocumentId };

export const SCRIPT_ID = "meeting-link-migration";
export const EMULATOR_PROJECT = "demo-rafiq-rules";
export const KNOWN_REAL_PROJECTS = Object.freeze([
  "rafiq-academy",
  "rafiq-academy-staging",
  "rafiq-academy-prod",
]);
export const OPT_IN_ENV = "MEETING_LINK_MIGRATION_EMULATOR";
export const PORTS_ENV = "MEETING_LINK_MIGRATION_PORTS";
export const CONFIRM_TOKEN = `${SCRIPT_ID}:${EMULATOR_PROJECT}`;
export const PAGE_SIZE = 200;
export const ID_CAP = 50;

const HALAQAT = "halaqat";
const LINKS = "halaqaMeetingLinks";
const READABLE_COLLECTIONS = new Set([HALAQAT, LINKS, "users", "studentProfiles"]);
const GET_ALL_CHUNK = 100;
const DEFAULT_EMULATOR_PORTS = new Set([
  4000, 4400, 4500, 5000, 5001, 8080, 8085, 9000, 9099, 9150, 9199, 9299, 9499,
]);
const PROJECT_ENV_KEYS = ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT", "GCP_PROJECT", "CLOUDSDK_CORE_PROJECT"];
const LOOPBACK_HOST = /^(127\.0\.0\.1|localhost|\[::1\]):\d{1,5}$/;
const PRELOAD_FLAG = /(^|\s)(--require|-r|--import|--loader|--experimental-loader)(=|\s|$)/;

const CHANGED_DURING_RUN = Object.freeze([
  "halaqaGone",
  "canonicalAppeared",
  "missing",
  "empty",
  "nonString",
  "invalid",
]);

// ── small pure helpers ─────────────────────────────────────────────────────

const hasOwn = (data, key) => Object.prototype.hasOwnProperty.call(data, key);

const GRPC_CODES = {
  1: "cancelled",
  2: "unknown",
  3: "invalid-argument",
  4: "deadline-exceeded",
  5: "not-found",
  6: "already-exists",
  7: "permission-denied",
  8: "resource-exhausted",
  9: "failed-precondition",
  10: "aborted",
  13: "internal",
  14: "unavailable",
  16: "unauthenticated",
};

/** Error code only; messages can quote document data and are never printed. */
export function safeErrorCode(error) {
  const code = error?.code;
  if (typeof code === "number") return GRPC_CODES[code] ?? `grpc-${code}`;
  if (typeof code === "string" && /^[a-z0-9/_-]{1,60}$/i.test(code)) return code;
  return "unknown";
}

/** Document ids that may appear in the report. */
export function isSafeId(id) {
  return typeof id === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(id);
}

export function createIdList(cap = ID_CAP) {
  const ids = [];
  let total = 0;
  let unprintable = 0;
  return {
    add(id) {
      total += 1;
      if (!isSafeId(id)) unprintable += 1;
      else if (ids.length < cap) ids.push(id);
    },
    toJSON() {
      return { total, ids, truncated: total - unprintable > ids.length, unprintable };
    },
  };
}

function zeroCounts(keys) {
  return Object.fromEntries(keys.map((key) => [key, 0]));
}

// ── invocation gate (pure) ─────────────────────────────────────────────────

/** Returns { problems, mode: "plan" | "dry-run" | "apply" | null, config }. Never echoes values. */
export function checkInvocation({ argv, env }) {
  const problems = [];
  const opts = { project: null, apply: false, dryRun: false, confirm: null };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      problems.push(`Unexpected positional argument #${i + 1}.`);
      continue;
    }
    const eq = arg.indexOf("=");
    const flag = eq === -1 ? arg : arg.slice(0, eq);
    const inline = eq === -1 ? undefined : arg.slice(eq + 1);
    const value = () => {
      if (inline !== undefined) return inline;
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) return null;
      i += 1;
      return next;
    };
    switch (flag) {
      case "--project":
        opts.project = value();
        if (opts.project === null) problems.push("--project needs a value.");
        break;
      case "--confirm":
        opts.confirm = value();
        if (opts.confirm === null) problems.push("--confirm needs a value.");
        break;
      case "--apply":
      case "--dry-run":
        if (inline !== undefined) problems.push(`${flag} takes no value.`);
        if (flag === "--apply") opts.apply = true;
        else opts.dryRun = true;
        break;
      default:
        problems.push(/^--[a-z-]{1,30}$/.test(flag) ? `Unknown flag ${flag}.` : "Unknown flag.");
    }
  }

  if (opts.apply && opts.dryRun) problems.push("--apply and --dry-run cannot be combined.");
  if (opts.confirm !== null && !opts.apply) problems.push("--confirm is only accepted together with --apply.");

  if (opts.project === null) {
    if (opts.apply || opts.dryRun) problems.push(`--project ${EMULATOR_PROJECT} is required.`);
    return { problems, mode: problems.length ? null : "plan", config: opts };
  }

  if (opts.project !== EMULATOR_PROJECT) {
    problems.push(
      KNOWN_REAL_PROJECTS.includes(opts.project)
        ? `Real Firebase projects are not supported; only ${EMULATOR_PROJECT} on the local emulator.`
        : `--project is not supported; only ${EMULATOR_PROJECT} on the local emulator.`,
    );
  }
  if (opts.apply && opts.confirm !== CONFIRM_TOKEN) {
    problems.push(`--apply needs --confirm ${CONFIRM_TOKEN}`);
  }
  problems.push(...environmentProblems(env, opts));
  const mode = problems.length ? null : opts.apply ? "apply" : "dry-run";
  return { problems, mode, config: opts };
}

function environmentProblems(env, opts) {
  const problems = [];
  if (env[OPT_IN_ENV] !== "1") problems.push(`${OPT_IN_ENV}=1 is required.`);

  const pins = String(env[PORTS_ENV] ?? "").split(",").map(Number);
  const portsValid = pins.length === 2 && pins.every((p) => Number.isInteger(p) && p >= 1024 && p <= 65535);
  if (!portsValid) {
    problems.push(`${PORTS_ENV} must be "<firestorePort>,<hubPort>".`);
  } else {
    const [firestorePort, hubPort] = pins;
    if (pins.some((p) => DEFAULT_EMULATOR_PORTS.has(p))) {
      problems.push("Pinned ports must not be default emulator ports (possibly shared).");
    }
    if (firestorePort === hubPort) problems.push("Pinned ports must be distinct.");
    if (env.FIRESTORE_EMULATOR_HOST !== `127.0.0.1:${firestorePort}`) {
      problems.push("FIRESTORE_EMULATOR_HOST does not match the pinned Firestore port on 127.0.0.1.");
    }
    if (env.FIREBASE_EMULATOR_HUB !== `127.0.0.1:${hubPort}`) {
      problems.push("FIREBASE_EMULATOR_HUB does not match the pinned hub port on 127.0.0.1.");
    }
    opts.firestorePort = firestorePort;
    opts.hubPort = hubPort;
  }

  for (const key of Object.keys(env)) {
    if (key.toUpperCase().endsWith("_EMULATOR_HOST") && env[key] && !LOOPBACK_HOST.test(env[key])) {
      problems.push(`${key} does not point at a loopback emulator.`);
    }
  }
  if (env.GOOGLE_APPLICATION_CREDENTIALS) {
    problems.push("GOOGLE_APPLICATION_CREDENTIALS must be unset; the emulator run never uses credentials.");
  }
  if (env.GOOGLE_API_USE_CLIENT_CERTIFICATE) {
    problems.push("GOOGLE_API_USE_CLIENT_CERTIFICATE must be unset.");
  }
  for (const key of PROJECT_ENV_KEYS) {
    if (env[key] && env[key] !== EMULATOR_PROJECT) problems.push(`${key} names a different project.`);
  }
  if (env.FIREBASE_CONFIG) {
    let parsed;
    try {
      parsed = JSON.parse(env.FIREBASE_CONFIG);
    } catch {
      parsed = undefined;
    }
    if (parsed?.projectId !== EMULATOR_PROJECT) problems.push("FIREBASE_CONFIG does not name the emulator project.");
  }
  if (PRELOAD_FLAG.test(String(env.NODE_OPTIONS ?? ""))) {
    problems.push("NODE_OPTIONS must not preload modules (they would run before the egress guard).");
  }
  return problems;
}

export function buildPlan() {
  return {
    script: SCRIPT_ID,
    mode: "plan",
    connects: false,
    project: EMULATOR_PROJECT,
    scope: {
      reads: [HALAQAT, LINKS, "users", "studentProfiles"],
      writes: `apply only: create missing ${LINKS}/{halaqaId} from a valid legacy value; never overwrite, repair or delete; never write ${HALAQAT}`,
      realProjects: "not supported in this milestone",
    },
    requiredForDryRunOrApply: [
      `--project ${EMULATOR_PROJECT}`,
      `${OPT_IN_ENV}=1`,
      `${PORTS_ENV}=<firestorePort>,<hubPort> matching FIRESTORE_EMULATOR_HOST and FIREBASE_EMULATOR_HUB on 127.0.0.1`,
    ],
    requiredForApply: [`--apply --confirm ${CONFIRM_TOKEN}`],
  };
}

// ── roster checks (pure; classification lives in meeting-link-migration-core.mjs) ──

const isArchivedLifecycle = (profile) =>
  typeof profile?.lifecycle === "string" && profile.lifecycle.includes("archived");

/** Mirrors the halaqaMeetingLinks student read rule; first failing condition wins. */
export function studentEligibility(user, profile) {
  if (!user) return "missingUser";
  if (user.isActive === false) return "inactive";
  if (user.role !== "student") return "nonStudentRole";
  if (!profile) return "missingProfile";
  if (isArchivedLifecycle(profile)) return "archived";
  return "eligible";
}

export function supervisorStatus(user) {
  if (!user) return "missingUser";
  if (user.isActive === false) return "inactive";
  if (user.role !== "supervisor") return "wrongRole";
  return "ok";
}

// ── data surfaces ──────────────────────────────────────────────────────────

export class SurfaceViolation extends Error {
  constructor(what) {
    super(`${what} is not available to the meeting-link migration.`);
    this.code = "surface-violation";
  }
}

function locked(target, label) {
  const frozen = Object.freeze(target);
  return new Proxy(frozen, {
    get(t, prop) {
      if (typeof prop === "symbol" || prop === "then") return undefined;
      if (!hasOwn(t, prop)) throw new SurfaceViolation(`${label}.${String(prop)}`);
      return t[prop];
    },
    set(_t, prop) {
      throw new SurfaceViolation(`assigning ${label}.${String(prop)}`);
    },
    defineProperty(_t, prop) {
      throw new SurfaceViolation(`defining ${label}.${String(prop)}`);
    },
    deleteProperty(_t, prop) {
      throw new SurfaceViolation(`deleting ${label}.${String(prop)}`);
    },
    setPrototypeOf() {
      throw new SurfaceViolation(`re-prototyping ${label}`);
    },
  });
}

const docView = (snap) => Object.freeze({ id: snap.id, exists: snap.exists, data: snap.exists ? snap.data() ?? {} : null });

/** Reads only: id-ordered pages of halaqat / halaqaMeetingLinks and getAll on four collections. */
export function readOnlyStore(db, documentId) {
  const requireCollection = (name) => {
    if (!READABLE_COLLECTIONS.has(name)) throw new SurfaceViolation(`collection ${name}`);
  };
  return locked(
    {
      page: async (collection, afterId, pageSize) => {
        if (collection !== HALAQAT && collection !== LINKS) throw new SurfaceViolation(`paging ${collection}`);
        let query = db.collection(collection).orderBy(documentId).limit(pageSize);
        if (afterId !== null) query = query.startAfter(afterId);
        const snap = await query.get();
        return Object.freeze(snap.docs.map(docView));
      },
      getMany: async (collection, ids) => {
        requireCollection(collection);
        const out = [];
        for (let i = 0; i < ids.length; i += GET_ALL_CHUNK) {
          const refs = ids.slice(i, i + GET_ALL_CHUNK).map((id) => db.collection(collection).doc(id));
          if (refs.length === 0) continue;
          for (const snap of await db.getAll(...refs)) out.push(docView(snap));
        }
        return Object.freeze(out);
      },
    },
    "store",
  );
}

/**
 * Apply-mode writer. Its only operation re-reads the halaqa and its canonical
 * document in one transaction and creates the canonical document only when it
 * is still absent and the legacy value is still valid. `afterRead` is a test
 * hook (not reachable from the CLI).
 */
export function canonicalWriter(db, { canonicalData, issueOf, afterRead = null }) {
  return locked(
    {
      migrateOne: (halaqaId) =>
        db.runTransaction(
          async (tx) => {
            const halaqaRef = db.collection(HALAQAT).doc(halaqaId);
            const linkRef = db.collection(LINKS).doc(halaqaId);
            const [halaqa, link] = await tx.getAll(halaqaRef, linkRef);
            if (afterRead) await afterRead(halaqaId);
            if (!halaqa.exists) return "halaqaGone";
            if (link.exists) return "canonicalAppeared";
            const legacy = classifyLegacy(halaqa.data() ?? {}, issueOf);
            if (legacy.category !== "valid") return legacy.category;
            tx.create(linkRef, canonicalData(legacy.value));
            return "migrated";
          },
          { maxAttempts: 5 },
        ),
    },
    "writer",
  );
}

// ── migration ──────────────────────────────────────────────────────────────

function emptyReport(mode) {
  return {
    script: SCRIPT_ID,
    project: EMULATOR_PROJECT,
    mode,
    halaqat: {
      scanned: 0,
      legacy: { missing: 0, empty: 0, nonString: 0, invalid: 0, valid: 0, trimRequired: 0 },
      invalidByReason: zeroCounts([...LINK_ISSUES, "other"]),
      canonical: { absent: 0, alreadyMigrated: 0, conflict: 0, malformed: 0, withoutValidLegacy: 0 },
      malformedByReason: zeroCounts(MALFORMED_REASONS),
      candidates: 0,
      wouldMigrate: 0,
      migrated: 0,
      changedDuringRun: zeroCounts(CHANGED_DURING_RUN),
    },
    orphanCanonical: { scanned: 0, orphans: 0 },
    roster: {
      entries: 0,
      malformedEntries: 0,
      distinctStudents: 0,
      missingUser: 0,
      inactive: 0,
      nonStudentRole: 0,
      missingProfile: 0,
      archived: 0,
      eligible: 0,
      ineligibleOnHalaqatWithValidLink: 0,
    },
    supervisors: { halaqatWithoutSupervisor: 0, malformed: 0, missingUser: 0, inactive: 0, wrongRole: 0 },
    failures: { total: 0, byCode: {} },
    review: {
      conflictIds: createIdList(),
      malformedIds: createIdList(),
      withoutValidLegacyIds: createIdList(),
      orphanIds: createIdList(),
      invalidIds: createIdList(),
      changedDuringRunIds: createIdList(),
      failedIds: createIdList(),
    },
    summary: { needsReview: false, exitCode: 0 },
  };
}

async function loadById(store, collection, ids, cache) {
  const missing = [...new Set(ids)].filter((id) => !cache.has(id));
  for (const view of await store.getMany(collection, missing)) cache.set(view.id, view.exists ? view.data : null);
}

/**
 * Scans every halaqa (both modes), migrates candidates (apply), then scans
 * canonical documents for orphans. Returns the JSON-safe report.
 */
export async function runMeetingLinkMigration({ store, writer = null, mode, issueOf, isTimestamp, pageSize = PAGE_SIZE }) {
  if (mode !== "dry-run" && mode !== "apply") throw new Error("mode must be dry-run or apply");
  if (mode === "apply" && writer === null) throw new Error("apply needs a writer");
  const report = emptyReport(mode);
  const h = report.halaqat;
  const r = report.roster;
  const users = new Map();
  const profiles = new Map();
  const studentsSeen = new Set();

  let afterId = null;
  for (;;) {
    const page = await store.page(HALAQAT, afterId, pageSize);
    if (page.length === 0) break;
    const ids = page.map((doc) => doc.id);
    const canonicalById = new Map((await store.getMany(LINKS, ids)).map((view) => [view.id, view]));

    const rosterEntries = [];
    const supervisorIds = [];
    for (const doc of page) {
      h.scanned += 1;
      const data = doc.data ?? {};
      const legacy = classifyLegacy(data, issueOf);
      h.legacy[legacy.category] += 1;
      if (legacy.category === "invalid") {
        h.invalidByReason[legacy.reason] += 1;
        report.review.invalidIds.add(doc.id);
      }
      if (legacy.category === "valid" && legacy.trimRequired) h.legacy.trimRequired += 1;

      const view = canonicalById.get(doc.id);
      const canonical = view?.exists ? classifyCanonical(view.data, issueOf, isTimestamp) : null;
      const decision = decide(legacy, canonical);
      if (canonical === null) h.canonical.absent += 1;
      if (decision === "malformed") {
        h.canonical.malformed += 1;
        h.malformedByReason[canonical.reason] += 1;
        report.review.malformedIds.add(doc.id);
      } else if (decision === "alreadyMigrated") {
        h.canonical.alreadyMigrated += 1;
      } else if (decision === "conflict") {
        h.canonical.conflict += 1;
        report.review.conflictIds.add(doc.id);
      } else if (decision === "withoutValidLegacy") {
        h.canonical.withoutValidLegacy += 1;
        report.review.withoutValidLegacyIds.add(doc.id);
      } else if (decision === "candidate") {
        h.candidates += 1;
        if (mode === "dry-run") {
          h.wouldMigrate += 1;
        } else {
          try {
            const outcome = await writer.migrateOne(doc.id);
            if (outcome === "migrated") {
              h.migrated += 1;
            } else {
              h.changedDuringRun[CHANGED_DURING_RUN.includes(outcome) ? outcome : "halaqaGone"] += 1;
              report.review.changedDuringRunIds.add(doc.id);
            }
          } catch (error) {
            const code = safeErrorCode(error);
            report.failures.total += 1;
            report.failures.byCode[code] = (report.failures.byCode[code] ?? 0) + 1;
            report.review.failedIds.add(doc.id);
          }
        }
      }

      const hasValidLink = legacy.category === "valid";
      if (hasOwn(data, "studentIds")) {
        if (!Array.isArray(data.studentIds)) {
          r.malformedEntries += 1;
        } else {
          for (const entry of data.studentIds) {
            if (typeof entry !== "string" || entry.trim() === "" || !isValidDocumentId(entry)) {
              r.malformedEntries += 1;
            } else {
              r.entries += 1;
              rosterEntries.push({ studentId: entry, hasValidLink });
            }
          }
        }
      }
      const supervisorId = typeof data.supervisorId === "string" ? data.supervisorId.trim() : "";
      if (supervisorId === "") report.supervisors.halaqatWithoutSupervisor += 1;
      else if (!isValidDocumentId(supervisorId)) report.supervisors.malformed += 1;
      else supervisorIds.push(supervisorId);
    }

    const studentIds = rosterEntries.map((e) => e.studentId);
    await loadById(store, "users", [...studentIds, ...supervisorIds], users);
    await loadById(store, "studentProfiles", studentIds, profiles);
    for (const { studentId, hasValidLink } of rosterEntries) {
      const status = studentEligibility(users.get(studentId), profiles.get(studentId));
      if (!studentsSeen.has(studentId)) {
        studentsSeen.add(studentId);
        r.distinctStudents += 1;
        r[status] += 1;
      }
      if (hasValidLink && status !== "eligible") r.ineligibleOnHalaqatWithValidLink += 1;
    }
    for (const id of supervisorIds) {
      const status = supervisorStatus(users.get(id));
      if (status !== "ok") report.supervisors[status] += 1;
    }

    if (page.length < pageSize) break;
    afterId = page[page.length - 1].id;
  }

  afterId = null;
  for (;;) {
    const page = await store.page(LINKS, afterId, pageSize);
    if (page.length === 0) break;
    report.orphanCanonical.scanned += page.length;
    const halaqat = await store.getMany(HALAQAT, page.map((doc) => doc.id));
    for (const view of halaqat) {
      if (!view.exists) {
        report.orphanCanonical.orphans += 1;
        report.review.orphanIds.add(view.id);
      }
    }
    if (page.length < pageSize) break;
    afterId = page[page.length - 1].id;
  }

  const c = h.canonical;
  report.summary.needsReview =
    c.conflict + c.malformed + c.withoutValidLegacy + h.legacy.invalid + report.orphanCanonical.orphans +
      r.ineligibleOnHalaqatWithValidLink > 0;
  report.summary.exitCode = report.failures.total > 0 ? 4 : 0;
  return JSON.parse(JSON.stringify(report));
}

// ── CLI ────────────────────────────────────────────────────────────────────

/** Installs the process-wide egress allowlist and proves it is active. */
export async function startEgressGuard(ports) {
  const guard = installEgressGuard({ allowedPorts: ports });
  return (await guard.selfTest()) ? guard : null;
}

async function verifyHub(config) {
  const res = await fetch(`http://127.0.0.1:${config.hubPort}/emulators`);
  if (!res.ok) return "the emulator hub did not answer on the pinned port.";
  const listing = await res.json();
  const fs = listing?.firestore;
  if (!fs || fs.port !== config.firestorePort || !["127.0.0.1", "::1"].includes(fs.host)) {
    return "the emulator hub does not report Firestore on the pinned loopback port.";
  }
  if (listing?.hub?.port !== config.hubPort) return "the emulator hub reports a different hub port.";
  return null;
}

function refuse(problem, code = 2) {
  console.error(`refused: ${problem}`);
  process.exit(code);
}

async function main() {
  const { problems, mode, config } = checkInvocation({ argv: process.argv.slice(2), env: process.env });
  if (problems.length > 0) {
    for (const problem of problems) console.error(`refused: ${problem}`);
    process.exit(2);
  }
  if (mode === "plan") {
    console.log(JSON.stringify(buildPlan(), null, 2));
    return;
  }

  process.env.METADATA_SERVER_DETECTION = "none";
  const guard = await startEgressGuard([config.firestorePort, config.hubPort]);
  if (!guard) refuse("egress guard is not active.");
  const hubProblem = await verifyHub(config).catch(() => "the emulator hub could not be reached.");
  if (hubProblem) refuse(hubProblem);

  const here = dirname(fileURLToPath(import.meta.url));
  let links;
  try {
    links = await import(pathToFileURL(join(here, "..", "lib", "halaqa", "meetingLinkFunctions.js")).href);
  } catch {
    refuse("build functions first (lib/halaqa/meetingLinkFunctions.js could not be loaded).");
  }
  const issueOf = links.meetingLinkIssue ?? links.default?.meetingLinkIssue;
  const canonicalData = links.canonicalMeetingLinkData ?? links.default?.canonicalMeetingLinkData;
  const maxLength = links.MAX_MEETING_LINK_LENGTH ?? links.default?.MAX_MEETING_LINK_LENGTH;
  if (typeof issueOf !== "function" || typeof canonicalData !== "function" || maxLength !== 500) {
    refuse("lib/halaqa/meetingLinkFunctions.js does not export the B14 validator.");
  }

  const { initializeApp, deleteApp } = await import("firebase-admin/app");
  const { getFirestore, FieldPath, Timestamp } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: EMULATOR_PROJECT }, SCRIPT_ID);
  if (app.options.projectId !== EMULATOR_PROJECT) refuse("firebase-admin resolved a different project.");
  const db = getFirestore(app);

  const report = await runMeetingLinkMigration({
    store: readOnlyStore(db, FieldPath.documentId()),
    writer: mode === "apply" ? canonicalWriter(db, { canonicalData, issueOf }) : null,
    mode,
    issueOf,
    isTimestamp: (value) => value instanceof Timestamp,
  });
  await deleteApp(app);

  const blocked = guard.blockedAttempts().length;
  if (blocked > 0) {
    console.error(`${SCRIPT_ID}: ${blocked} non-emulator connection attempt(s) were blocked.`);
    process.exit(3);
  }
  console.log(JSON.stringify(report, null, 2));
  process.exitCode = report.summary.exitCode;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main().catch((error) => {
    console.error(`${SCRIPT_ID} failed: ${safeErrorCode(error)}`);
    process.exit(1);
  });
}
