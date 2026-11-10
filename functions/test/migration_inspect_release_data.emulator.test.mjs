/**
 * Release data inspection against the real Firebase Admin SDK and an
 * isolated Firestore emulator (`demo-rafiq-rules`, non-default ports).
 * Synthetic data only; build functions first. Same environment as the B14
 * migration emulator suite:
 *
 *   MEETING_LINK_MIGRATION_EMULATOR=1 MEETING_LINK_MIGRATION_PORTS=38080,34400 \
 *   firebase emulators:exec --config <isolated firebase.json> \
 *     --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 <repo>/functions/test/migration_inspect_release_data.emulator.test.mjs"
 *
 * The last test leaves its fixture in the emulator, so `--export-on-exit`
 * yields an export that the import rehearsal can load.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";
import { EMULATOR_PROJECT } from "../scripts/migrate-meeting-links.mjs";
import { idsDigest } from "../scripts/migration-inspect-release-data.mjs";

const PORTS = String(process.env.MEETING_LINK_MIGRATION_PORTS ?? "").split(",").map(Number);
const [FS_PORT, HUB_PORT] = PORTS;
{
  const problems = [];
  if (process.env.MEETING_LINK_MIGRATION_EMULATOR !== "1") problems.push("MEETING_LINK_MIGRATION_EMULATOR must be 1");
  if (PORTS.length !== 2 || PORTS.some((p) => !Number.isInteger(p) || p < 1024 || p > 65535)) {
    problems.push("MEETING_LINK_MIGRATION_PORTS must be firestore,hub");
  }
  if (PORTS.some((p) => [8080, 4400, 4000, 4500, 5001, 9099, 9199, 9150].includes(p))) {
    problems.push("default (possibly shared) emulator ports are refused");
  }
  if (process.env.FIRESTORE_EMULATOR_HOST !== `127.0.0.1:${FS_PORT}`) problems.push("FIRESTORE_EMULATOR_HOST mismatch");
  if (process.env.FIREBASE_EMULATOR_HUB !== `127.0.0.1:${HUB_PORT}`) problems.push("FIREBASE_EMULATOR_HUB mismatch");
  for (const key of ["GCLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT"]) {
    if (process.env[key] && process.env[key] !== EMULATOR_PROJECT) problems.push(`${key} is not ${EMULATOR_PROJECT}`);
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) problems.push("GOOGLE_APPLICATION_CREDENTIALS must be unset");
  if (problems.length > 0) throw new Error(`release data inspection emulator suite refused: ${problems.join("; ")}`);
}

process.env.METADATA_SERVER_DETECTION = "none";
const guard = installEgressGuard({ allowedPorts: [FS_PORT, HUB_PORT] });
assert.equal(await guard.selfTest(), true, "egress guard must be active");

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const SCRIPT = join(functionsDir, "scripts", "migration-inspect-release-data.mjs");
const PRELOAD = pathToFileURL(join(here, "migrate_meeting_links_egress_preload.mjs")).href;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: EMULATOR_PROJECT });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const MARK = "zqinspect";
const LINK_A = `https://meet.example.test/${MARK}-a`;
const LINK_B = `https://video.example.org/j/${MARK}-b`;
const TITLE = `${MARK} event title`;
const FORBIDDEN_OUTPUT = [MARK, "://", "example.test", "example.org", "stu1"];

async function clearFirestore() {
  const res = await fetch(
    `http://127.0.0.1:${FS_PORT}/emulator/v1/projects/${EMULATOR_PROJECT}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed(docs) {
  const batch = db.batch();
  for (const [path, data] of Object.entries(docs)) batch.set(db.doc(path), data);
  await batch.commit();
}

function fixtureDocs() {
  const now = Timestamp.now();
  const date = Timestamp.fromDate(new Date(Date.UTC(2026, 9, 28)));
  return {
    "halaqat/hNeedsCopy": { name: TITLE, meetingLink: LINK_A },
    "users/stu1": { role: "student", isActive: true },
    "studentProfiles/stu1": { lifecycle: "active" },
    "halaqat/hSame": { name: TITLE, meetingLink: LINK_A, studentIds: ["stu1"] },
    "halaqat/hConflict": { name: TITLE, meetingLink: LINK_A },
    "halaqat/hEmpty": { name: TITLE, meetingLink: "" },
    "halaqat/hInvalid": { name: TITLE, meetingLink: `http://meet.example.test/${MARK}-nh` },
    "halaqat/hMalformed": { name: TITLE, meetingLink: LINK_A },
    "halaqaMeetingLinks/hSame": { meetingLink: LINK_A, updatedAt: now },
    "halaqaMeetingLinks/hConflict": { meetingLink: LINK_B, updatedAt: now },
    "halaqaMeetingLinks/hMalformed": { meetingLink: ` ${LINK_A}`, updatedAt: now },
    "halaqaMeetingLinks/hOrphan": { meetingLink: LINK_B, updatedAt: now },
    "calendarEvents/eMissing": { title: TITLE, date },
    "calendarEvents/eNull": { title: TITLE, date, halaqaId: null },
    "calendarEvents/eHalaqa": { title: TITLE, date, halaqaId: "hSame" },
    "calendarEvents/eGone": { title: TITLE, date, halaqaId: "hDeleted" },
    "calendarEvents/eNoDate": { title: TITLE, halaqaId: null },
  };
}

/** path -> updateTime for every document in every collection. */
async function snapshotAll() {
  const out = new Map();
  for (const collection of await db.listCollections()) {
    for (const doc of (await collection.get()).docs) {
      out.set(doc.ref.path, `${doc.updateTime.seconds}.${doc.updateTime.nanoseconds}`);
    }
  }
  return out;
}

function cleanEnv(extra) {
  const env = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (/(_EMULATOR_HOST|_EMULATOR_HUB)$|^(FIREBASE_|GOOGLE_|GCLOUD_|GCP_|CLOUDSDK_|MEETING_LINK_|B14_)|^NODE_OPTIONS$/i.test(key)) continue;
    env[key] = value;
  }
  return { ...env, ...extra };
}

function runCli(args) {
  return new Promise((resolveRun) => {
    const child = spawn(process.execPath, ["--import", PRELOAD, SCRIPT, ...args], {
      cwd: functionsDir,
      env: cleanEnv({
        MEETING_LINK_MIGRATION_EMULATOR: "1",
        MEETING_LINK_MIGRATION_PORTS: `${FS_PORT},${HUB_PORT}`,
        FIRESTORE_EMULATOR_HOST: `127.0.0.1:${FS_PORT}`,
        FIREBASE_EMULATOR_HUB: `127.0.0.1:${HUB_PORT}`,
        B14_MIGRATION_PRELOAD_PORTS: `${FS_PORT},${HUB_PORT}`,
      }),
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.on("close", (code) => resolveRun({ code, stdout, stderr }));
  });
}

const assertNoValues = (text) => {
  for (const forbidden of FORBIDDEN_OUTPUT) assert.ok(!text.includes(forbidden), `output must not contain ${forbidden}`);
};

test.beforeEach(async () => {
  await clearFirestore();
});

test("isolation: the hub lists only this run's Firestore on the pinned port", async () => {
  const listing = await (await fetch(`http://127.0.0.1:${HUB_PORT}/emulators`)).json();
  assert.equal(listing.firestore.port, FS_PORT);
  assert.equal(listing.hub.port, HUB_PORT);
  for (const other of ["auth", "functions", "storage", "database", "pubsub", "hosting"]) {
    assert.equal(listing[other], undefined, `${other} emulator must not run`);
  }
});

test("CLI refusals inside the emulator environment touch no data", async () => {
  await seed(fixtureDocs());
  const before = await snapshotAll();
  for (const args of [
    ["--project", "rafiq-academy"],
    ["--project", EMULATOR_PROJECT, "--apply"],
    ["--project", EMULATOR_PROJECT, "--strip-legacy"],
    ["--project", EMULATOR_PROJECT, "--confirm", "meeting-link-strip:demo-rafiq-rules"],
  ]) {
    const result = await runCli(args);
    assert.equal(result.code, 2, args.join(" "));
    assert.equal(result.stdout, "");
    assertNoValues(result.stderr);
  }
  assert.deepEqual(await snapshotAll(), before);
});

// Keep last: its fixture stays in the emulator for the export/import rehearsal.
test("CLI inspection reports every category and writes nothing", async () => {
  await seed(fixtureDocs());
  const before = await snapshotAll();
  const result = await runCli(["--project", EMULATOR_PROJECT]);
  assert.equal(result.code, 0, result.stderr);
  assert.doesNotMatch(result.stderr, /blocked/);
  assertNoValues(result.stdout + result.stderr);
  assert.deepEqual(await snapshotAll(), before, "no document changed");

  const report = JSON.parse(result.stdout);
  assert.equal(report.writes, 0);
  const inv = report.backup.collections;
  assert.deepEqual(inv.halaqat, {
    documents: 6,
    idsSha256: idsDigest(["hNeedsCopy", "hSame", "hConflict", "hEmpty", "hInvalid", "hMalformed"]),
  });
  assert.deepEqual(inv.halaqaMeetingLinks, { documents: 4, idsSha256: idsDigest(["hSame", "hConflict", "hMalformed", "hOrphan"]) });
  assert.deepEqual(inv.calendarEvents, {
    documents: 5,
    idsSha256: idsDigest(["eMissing", "eNull", "eHalaqa", "eGone", "eNoDate"]),
  });
  assert.deepEqual(inv.users, { documents: 1, idsSha256: idsDigest(["stu1"]) });
  assert.deepEqual(inv.studentProfiles, { documents: 1, idsSha256: idsDigest(["stu1"]) });
  assert.equal(report.backup.totalDocuments, 17);
  assert.deepEqual(report.backup.emptyCollections, []);
  assert.equal(report.meetingLinks.copy.roster.eligible, 1);

  const cal = report.calendarEvents;
  assert.deepEqual(cal.halaqaId, { missing: 1, null: 2, halaqa: 1, orphanHalaqa: 1, emptyString: 0, invalidId: 0, nonString: 0 });
  assert.deepEqual(cal.date, { timestamp: 4, missing: 1, other: 0 });
  assert.equal(cal.wouldBackfillToNull, 1);
  assert.deepEqual(cal.review.missingHalaqaIdIds.ids, ["eMissing"]);
  assert.deepEqual(cal.review.orphanHalaqaIds.ids, ["eGone"]);

  const { copy, strip } = report.meetingLinks;
  assert.equal(copy.mode, "dry-run");
  assert.equal(copy.halaqat.scanned, 6);
  assert.equal(copy.halaqat.wouldMigrate, 1);
  assert.equal(copy.halaqat.migrated, 0);
  assert.equal(copy.halaqat.canonical.conflict, 1);
  assert.equal(copy.halaqat.canonical.malformed, 1);
  assert.equal(copy.halaqat.legacy.invalid, 1);
  assert.equal(copy.orphanCanonical.orphans, 1);
  assert.equal(strip.mode, "dry-run");
  assert.equal(strip.halaqat.legacyPresent, 6);
  assert.equal(strip.halaqat.strippable, 3);
  assert.equal(strip.halaqat.stripped, 0);
  assert.deepEqual(strip.halaqat.kept, { needsCopy: 1, invalidLegacy: 1, canonicalMalformed: 1 });
  assert.deepEqual(strip.review.supersededLegacyIds.ids, ["hConflict"]);
  assert.equal(strip.summary.legacyKeysRemaining, 6);
  assert.equal(report.meetingLinks.notYetCopied, 1);
  assert.equal(report.meetingLinks.lostOnStrip, 1);
  assert.equal(report.summary.needsReview, true);
  assert.equal(report.summary.exitCode, 0);
});
