// Release data inspection (read-only). Reports, before any real migration,
// what the approved runners would find in `calendarEvents`, `halaqat` and
// `halaqaMeetingLinks`. It runs only against the isolated Firestore emulator
// for `demo-rafiq-rules`, normally loaded with a downloaded production export
// (`firebase emulators:exec --import <export dir>`), so it never connects to a
// real project and never writes anything.
//
//   node scripts/migration-inspect-release-data.mjs                          (plan only)
//   node scripts/migration-inspect-release-data.mjs --project demo-rafiq-rules  (inspect)
//
// Same environment as migrate-meeting-links.mjs (its invocation checks are
// reused): MEETING_LINK_MIGRATION_EMULATOR=1, MEETING_LINK_MIGRATION_PORTS,
// FIRESTORE_EMULATOR_HOST and FIREBASE_EMULATOR_HUB on 127.0.0.1, no
// credentials. The egress guard, hub check and project check are the same.
//
// Output: one JSON report of counts, id digests and capped document ids.
// Event titles, link values, URLs and person ids are never printed.
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { isValidDocumentId } from "./meeting-link-migration-core.mjs";
import {
  EMULATOR_PROJECT,
  KNOWN_REAL_PROJECTS,
  PAGE_SIZE,
  checkInvocation as checkEmulatorInvocation,
  createIdList,
  readOnlyStore,
  runLegacyStrip,
  runMeetingLinkMigration,
  safeErrorCode,
  startEgressGuard,
  verifyHub,
} from "./migrate-meeting-links.mjs";

export const SCRIPT_ID = "release-data-inspection";
export const CALENDAR_SCOPES = Object.freeze([
  "missing",
  "null",
  "halaqa",
  "orphanHalaqa",
  "emptyString",
  "invalidId",
  "nonString",
]);

const HALAQAT = "halaqat";
const LINKS = "halaqaMeetingLinks";
const CALENDAR = "calendarEvents";
/** Collections the export must contain; the copy dry run reads users and studentProfiles for roster checks. */
export const EXPORT_COLLECTIONS = Object.freeze([HALAQAT, LINKS, CALENDAR, "users", "studentProfiles"]);
const GET_ALL_CHUNK = 100;

const hasOwn = (data, key) => Object.prototype.hasOwnProperty.call(data, key);

// ── invocation gate (pure) ─────────────────────────────────────────────────

/** Returns { problems, mode: "plan" | "inspect" | null, config }. Never echoes values. */
export function checkInvocation({ argv, env }) {
  const problems = [];
  let project = null;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--project") {
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) problems.push("--project needs a value.");
      else project = next;
      i += 1;
    } else if (arg.startsWith("--project=")) {
      project = arg.slice("--project=".length);
    } else if (/^--(apply|confirm|strip-legacy|dry-run)(=|$)/.test(arg)) {
      problems.push("This inspection is read-only; it takes no apply, confirm or strip flags.");
    } else {
      problems.push(/^--[a-z-]{1,30}$/.test(arg) ? `Unknown flag ${arg}.` : "Unknown argument.");
    }
  }
  if (project === null) return { problems, mode: problems.length ? null : "plan", config: null };
  const emulator = checkEmulatorInvocation({ argv: ["--project", project], env });
  problems.push(...emulator.problems);
  return { problems, mode: problems.length ? null : "inspect", config: emulator.config };
}

export function buildPlan() {
  return {
    script: SCRIPT_ID,
    mode: "plan",
    connects: false,
    project: EMULATOR_PROJECT,
    scope: {
      reads: [...EXPORT_COLLECTIONS],
      writes: "none",
      realProjects: `not supported; load an export of ${KNOWN_REAL_PROJECTS[0]} into the emulator instead`,
    },
    requiredForInspect: [
      `--project ${EMULATOR_PROJECT}`,
      "the migrate-meeting-links.mjs emulator environment (opt-in, pinned ports, no credentials)",
    ],
  };
}

// ── classification (pure) ──────────────────────────────────────────────────

/**
 * How the calendar month queries see an event's `halaqaId`. "missing" is a
 * general event the `isNull` query never returns (backfill candidate);
 * "halaqa" still needs the Halaqa to exist (otherwise "orphanHalaqa").
 */
export function classifyCalendarScope(data) {
  if (!hasOwn(data, "halaqaId")) return "missing";
  const value = data.halaqaId;
  if (value === null) return "null";
  if (typeof value !== "string") return "nonString";
  if (value.trim() === "") return "emptyString";
  return isValidDocumentId(value) ? "halaqa" : "invalidId";
}

/** "timestamp" | "missing" | "other"; the month query only matches Timestamps. */
export function classifyCalendarDate(data, isTimestamp) {
  if (!hasOwn(data, "date") || data.date === null) return "missing";
  return isTimestamp(data.date) ? "timestamp" : "other";
}

/** Order-independent digest of document ids, comparable across imports. */
export function idsDigest(ids) {
  const hash = createHash("sha256");
  for (const id of [...ids].sort()) hash.update(`${id}\n`);
  return hash.digest("hex");
}

// ── data surface ───────────────────────────────────────────────────────────

const docView = (snap) => Object.freeze({ id: snap.id, exists: snap.exists, data: snap.exists ? snap.data() ?? {} : null });

/** Reads only: id-ordered pages of the export collections and existence of halaqat. */
export function inspectionStore(db, documentId) {
  return Object.freeze({
    page: async (collection, afterId, pageSize) => {
      if (!EXPORT_COLLECTIONS.includes(collection)) throw new Error("collection is outside the inspection scope");
      let query = db.collection(collection).orderBy(documentId).limit(pageSize);
      if (afterId !== null) query = query.startAfter(afterId);
      return Object.freeze((await query.get()).docs.map(docView));
    },
    halaqaExists: async (ids) => {
      const out = new Map();
      for (let i = 0; i < ids.length; i += GET_ALL_CHUNK) {
        const refs = ids.slice(i, i + GET_ALL_CHUNK).map((id) => db.collection(HALAQAT).doc(id));
        if (refs.length === 0) continue;
        for (const snap of await db.getAll(...refs)) out.set(snap.id, snap.exists);
      }
      return out;
    },
  });
}

// ── inspection ─────────────────────────────────────────────────────────────

/** Counts and digests every document id of one export collection. */
async function collectionInventory(store, collection, pageSize) {
  const ids = [];
  let afterId = null;
  for (;;) {
    const page = await store.page(collection, afterId, pageSize);
    if (page.length === 0) break;
    for (const doc of page) ids.push(doc.id);
    if (page.length < pageSize) break;
    afterId = page[page.length - 1].id;
  }
  return { documents: ids.length, idsSha256: idsDigest(ids) };
}

export async function runCalendarInspection({ store, isTimestamp, pageSize = PAGE_SIZE }) {
  const scope = Object.fromEntries(CALENDAR_SCOPES.map((key) => [key, 0]));
  const date = { timestamp: 0, missing: 0, other: 0 };
  const review = {
    missingHalaqaIdIds: createIdList(),
    orphanHalaqaIds: createIdList(),
    invalidHalaqaIdIds: createIdList(),
    invalidDateIds: createIdList(),
  };
  const ids = [];
  let afterId = null;
  for (;;) {
    const page = await store.page(CALENDAR, afterId, pageSize);
    if (page.length === 0) break;
    const scoped = [];
    for (const doc of page) {
      ids.push(doc.id);
      const data = doc.data ?? {};
      const category = classifyCalendarScope(data);
      if (category === "halaqa") scoped.push({ id: doc.id, halaqaId: data.halaqaId });
      else scope[category] += 1;
      if (category === "missing") review.missingHalaqaIdIds.add(doc.id);
      if (category === "emptyString" || category === "invalidId" || category === "nonString") {
        review.invalidHalaqaIdIds.add(doc.id);
      }
      const dateCategory = classifyCalendarDate(data, isTimestamp);
      date[dateCategory] += 1;
      if (dateCategory !== "timestamp") review.invalidDateIds.add(doc.id);
    }
    const exists = await store.halaqaExists([...new Set(scoped.map((e) => e.halaqaId))]);
    for (const { id, halaqaId } of scoped) {
      if (exists.get(halaqaId) === true) {
        scope.halaqa += 1;
      } else {
        scope.orphanHalaqa += 1;
        review.orphanHalaqaIds.add(id);
      }
    }
    if (page.length < pageSize) break;
    afterId = page[page.length - 1].id;
  }
  const needsReview = scope.missing + scope.orphanHalaqa + scope.emptyString + scope.invalidId + scope.nonString +
    date.missing + date.other > 0;
  return JSON.parse(JSON.stringify({
    inventory: { documents: ids.length, idsSha256: idsDigest(ids) },
    report: {
      scanned: ids.length,
      halaqaId: scope,
      date,
      wouldBackfillToNull: scope.missing,
      review,
      needsReview,
    },
  }));
}

/** The whole read-only report: backup inventory, calendar, and both meeting-link dry runs. */
export async function runReleaseDataInspection({ linkStore, store, issueOf, isTimestamp, pageSize = PAGE_SIZE }) {
  const collections = {};
  for (const name of EXPORT_COLLECTIONS) {
    if (name !== CALENDAR) collections[name] = await collectionInventory(store, name, pageSize);
  }
  const cal = await runCalendarInspection({ store, isTimestamp, pageSize });
  collections[CALENDAR] = cal.inventory;
  const copy = await runMeetingLinkMigration({ store: linkStore, mode: "dry-run", issueOf, isTimestamp, pageSize });
  const strip = await runLegacyStrip({ store: linkStore, mode: "dry-run", issueOf, isTimestamp, pageSize });
  // An empty collection usually means it was left out of the export; roster
  // checks without users/studentProfiles report every student as missing.
  const emptyCollections = EXPORT_COLLECTIONS.filter((name) => collections[name].documents === 0);
  const report = {
    script: SCRIPT_ID,
    project: EMULATOR_PROJECT,
    mode: "inspect",
    writes: 0,
    backup: {
      collections,
      totalDocuments: Object.values(collections).reduce((sum, c) => sum + c.documents, 0),
      emptyCollections,
    },
    calendarEvents: cal.report,
    meetingLinks: {
      // Dry runs only: what the approved copy and strip would do with this data.
      copy,
      strip,
      lostOnStrip: strip.halaqat.supersededLegacy,
      notYetCopied: copy.halaqat.wouldMigrate,
    },
    summary: {
      needsReview:
        emptyCollections.length > 0 || cal.report.needsReview || copy.summary.needsReview || strip.summary.needsReview,
      exitCode: 0,
    },
  };
  return JSON.parse(JSON.stringify(report));
}

// ── CLI ────────────────────────────────────────────────────────────────────

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
  const maxLength = links.MAX_MEETING_LINK_LENGTH ?? links.default?.MAX_MEETING_LINK_LENGTH;
  if (typeof issueOf !== "function" || maxLength !== 500) {
    refuse("lib/halaqa/meetingLinkFunctions.js does not export the B14 validator.");
  }

  const { initializeApp, deleteApp } = await import("firebase-admin/app");
  const { getFirestore, FieldPath, Timestamp } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: EMULATOR_PROJECT }, SCRIPT_ID);
  if (app.options.projectId !== EMULATOR_PROJECT) refuse("firebase-admin resolved a different project.");
  const db = getFirestore(app);
  const isTimestamp = (value) => value instanceof Timestamp;

  const report = await runReleaseDataInspection({
    linkStore: readOnlyStore(db, FieldPath.documentId()),
    store: inspectionStore(db, FieldPath.documentId()),
    issueOf,
    isTimestamp,
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
