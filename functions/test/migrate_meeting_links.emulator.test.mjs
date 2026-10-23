/**
 * B14 meeting-link migration against the real Firebase Admin SDK and an
 * isolated Firestore emulator (`demo-rafiq-rules`, non-default ports).
 * Synthetic data only; build functions first.
 *
 * Refuses to start unless MEETING_LINK_MIGRATION_EMULATOR=1,
 * MEETING_LINK_MIGRATION_PORTS="<firestore>,<hub>" (non-default) and the
 * emulator env vars point at exactly those loopback ports. A process-wide
 * egress guard is installed before firebase-admin loads, and every CLI child
 * also gets migrate_meeting_links_egress_preload.mjs.
 *
 *   MEETING_LINK_MIGRATION_EMULATOR=1 MEETING_LINK_MIGRATION_PORTS=38080,34400 \
 *   firebase emulators:exec --config <isolated firebase.json> \
 *     --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 <repo>/functions/test/migrate_meeting_links.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";
import {
  CONFIRM_TOKEN,
  EMULATOR_PROJECT,
  canonicalWriter,
  readOnlyStore,
  runMeetingLinkMigration,
} from "../scripts/migrate-meeting-links.mjs";

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
  if (problems.length > 0) throw new Error(`B14 migration emulator suite refused: ${problems.join("; ")}`);
}

process.env.METADATA_SERVER_DETECTION = "none";
const guard = installEgressGuard({ allowedPorts: [FS_PORT, HUB_PORT] });
assert.equal(await guard.selfTest(), true, "egress guard must be active");

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const SCRIPT = join(functionsDir, "scripts", "migrate-meeting-links.mjs");
const PRELOAD = pathToFileURL(join(here, "migrate_meeting_links_egress_preload.mjs")).href;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: EMULATOR_PROJECT });
const db = admin.firestore();
const { Timestamp, FieldPath } = admin.firestore;
const { meetingLinkIssue, canonicalMeetingLinkData, setHalaqaMeetingLinkCore } = require(
  "../lib/halaqa/meetingLinkFunctions.js",
);

const MARK = "zqmark";
const LINK_A = `https://meet.example.test/${MARK}-a`;
const LINK_B = `https://video.example.org/j/${MARK}-b`;
const PADDED = `  https://meet.example.test/${MARK}-p  `;
const INVALID = {
  not_https: `http://meet.example.test/${MARK}-nh`,
  credentials: `https://user:pw@meet.example.test/${MARK}-cr`,
  invalid_host: `https://localhost/${MARK}-ih`,
  whitespace: `https://meet.example.test/${MARK} ws`,
  unsupported_characters: `https://meet.example.test/${MARK}-\u00e9`,
  too_long: `https://meet.example.test/${MARK}-${"a".repeat(500)}`,
  malformed: `https://meet.example.test\\${MARK}-ml`,
  contact_info: `https://wa.me/966500000001?${MARK}=ci`,
};
const FORBIDDEN_OUTPUT = [MARK, "://", "example.test", "example.org", "wa.me", "966500000001"];
const PERSON_IDS = ["stuEligible", "stuNoProfile", "stuArchived", "stuInactive", "stuNoUser", "supInactive", "supGone", "teacherAsSup"];
const outputs = [];

const store = () => readOnlyStore(db, FieldPath.documentId());
const writer = (afterRead = null) =>
  canonicalWriter(db, { canonicalData: canonicalMeetingLinkData, issueOf: meetingLinkIssue, afterRead });
const isTimestamp = (v) => v instanceof Timestamp;
const runInProcess = (mode, extra = {}) =>
  runMeetingLinkMigration({
    store: store(),
    writer: mode === "apply" ? writer() : null,
    mode,
    issueOf: meetingLinkIssue,
    isTimestamp,
    ...extra,
  });

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

const ts = () => admin.firestore.FieldValue.serverTimestamp();

function fixtureDocs() {
  const docs = {
    "users/admin1": { role: "admin", isActive: true },
    "users/sup1": { role: "supervisor", isActive: true },
    "users/supInactive": { role: "supervisor", isActive: false },
    "users/teacherAsSup": { role: "teacher" },
    "users/stuEligible": { role: "student", isActive: true },
    "users/stuNoProfile": { role: "student" },
    "users/stuArchived": { role: "student" },
    "users/stuInactive": { role: "student", isActive: false },
    "studentProfiles/stuEligible": { lifecycle: "active" },
    "studentProfiles/stuArchived": { lifecycle: " archived " },
    "studentProfiles/stuInactive": { lifecycle: "active" },
    "halaqat/hMissing": { name: "n", supervisorId: "sup1", studentIds: ["stuEligible"] },
    "halaqat/hEmpty": { meetingLink: "", supervisorId: "sup1" },
    "halaqat/hNonString": { meetingLink: 42, supervisorId: "sup1" },
    "halaqat/hValid": {
      meetingLink: LINK_A,
      supervisorId: "sup1",
      studentIds: ["stuEligible", "stuNoProfile", "stuArchived", "stuInactive", "stuNoUser"],
    },
    "halaqat/hPadded": { meetingLink: PADDED, supervisorId: "supInactive" },
    "halaqat/hSame": { meetingLink: LINK_A, supervisorId: "", studentIds: [7, ""] },
    "halaqat/hConflict": { meetingLink: LINK_A, supervisorId: "teacherAsSup" },
    "halaqat/hMalformed": { meetingLink: LINK_A, supervisorId: "sup1" },
    "halaqat/hMirror": { meetingLink: "", supervisorId: "supGone" },
    "halaqaMeetingLinks/hSame": { meetingLink: LINK_A, updatedAt: ts() },
    "halaqaMeetingLinks/hConflict": { meetingLink: LINK_B, updatedAt: ts() },
    "halaqaMeetingLinks/hMalformed": { meetingLink: ` ${LINK_A}`, updatedAt: ts() },
    "halaqaMeetingLinks/hMirror": { meetingLink: LINK_B, updatedAt: ts() },
    "halaqaMeetingLinks/hOrphan": { meetingLink: LINK_B, updatedAt: ts() },
  };
  for (const [reason, raw] of Object.entries(INVALID)) {
    docs[`halaqat/hInv_${reason}`] = { meetingLink: raw, supervisorId: "sup1" };
  }
  return docs;
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
    child.on("close", (code) => {
      outputs.push({ label: args.join(" "), text: stdout + stderr });
      resolveRun({ code, stdout, stderr });
    });
  });
}

const DRY = ["--project", EMULATOR_PROJECT];
const APPLY = ["--project", EMULATOR_PROJECT, "--apply", "--confirm", CONFIRM_TOKEN];
const delay = (ms) => new Promise((done) => setTimeout(done, ms));

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
    ["--project", "rafiq-academy", "--apply", "--confirm", "meeting-link-migration:rafiq-academy"],
    ["--project", EMULATOR_PROJECT, "--apply"],
    ["--project", EMULATOR_PROJECT, "--apply", "--confirm", "meeting-link-migration:rafiq-academy"],
  ]) {
    const result = await runCli(args);
    assert.equal(result.code, 2, args.join(" "));
    assert.equal(result.stdout, "");
  }
  assert.deepEqual(await snapshotAll(), before);
});

test("CLI dry run (real SDK): exact counts, zero writes", async () => {
  await seed(fixtureDocs());
  const before = await snapshotAll();
  const { code, stdout, stderr } = await runCli(DRY);
  assert.equal(code, 0, stderr);
  assert.deepEqual(await snapshotAll(), before, "dry run must not write");
  const report = JSON.parse(stdout);
  const h = report.halaqat;
  assert.equal(report.mode, "dry-run");
  assert.equal(h.scanned, 17);
  assert.deepEqual(h.legacy, { missing: 1, empty: 2, nonString: 1, invalid: 8, valid: 5, trimRequired: 1 });
  for (const reason of Object.keys(INVALID)) assert.equal(h.invalidByReason[reason], 1, reason);
  assert.deepEqual(h.canonical, { absent: 13, alreadyMigrated: 1, conflict: 1, malformed: 1, withoutValidLegacy: 1 });
  assert.equal(h.malformedByReason.untrimmed, 1);
  assert.equal(h.wouldMigrate, 2);
  assert.equal(h.migrated, 0);
  assert.deepEqual(report.orphanCanonical, { scanned: 5, orphans: 1 });
  assert.deepEqual(report.roster, {
    entries: 6,
    malformedEntries: 2,
    distinctStudents: 5,
    missingUser: 1,
    inactive: 1,
    nonStudentRole: 0,
    missingProfile: 1,
    archived: 1,
    eligible: 1,
    ineligibleOnHalaqatWithValidLink: 4,
  });
  assert.deepEqual(report.supervisors, { halaqatWithoutSupervisor: 1, malformed: 0, missingUser: 1, inactive: 1, wrongRole: 1 });
  assert.equal(report.summary.needsReview, true);
  assert.equal(report.summary.exitCode, 0);
  for (const id of PERSON_IDS) assert.equal(stdout.includes(id), false, `${id} leaked`);
});

test("CLI apply (real SDK): creates only the two valid missing docs, trimmed, with the exact schema", async () => {
  await seed(fixtureDocs());
  const before = await snapshotAll();
  const { code, stdout, stderr } = await runCli(APPLY);
  assert.equal(code, 0, stderr);
  const report = JSON.parse(stdout);
  assert.equal(report.halaqat.migrated, 2);
  assert.equal(report.halaqat.candidates, 2);
  assert.equal(report.failures.total, 0);

  const after = await snapshotAll();
  const created = [...after.keys()].filter((path) => !before.has(path)).sort();
  assert.deepEqual(created, ["halaqaMeetingLinks/hPadded", "halaqaMeetingLinks/hValid"]);
  for (const [path, time] of before) assert.equal(after.get(path), time, `${path} must be untouched`);

  for (const [id, expected] of [["hValid", LINK_A], ["hPadded", PADDED.trim()]]) {
    const data = (await db.doc(`halaqaMeetingLinks/${id}`).get()).data();
    assert.deepEqual(Object.keys(data).sort(), ["meetingLink", "updatedAt"]);
    assert.equal(data.meetingLink, expected);
    assert.ok(data.updatedAt instanceof Timestamp);
  }
  assert.equal((await db.doc("halaqat/hPadded").get()).data().meetingLink, PADDED, "legacy value untouched");
  assert.equal((await db.doc("halaqaMeetingLinks/hConflict").get()).data().meetingLink, LINK_B);
  for (const id of PERSON_IDS) assert.equal(stdout.includes(id), false, `${id} leaked`);
});

test("CLI rerun (real SDK): nothing to migrate and no updateTime changes", async () => {
  await seed(fixtureDocs());
  assert.equal((await runCli(APPLY)).code, 0);
  const before = await snapshotAll();
  const { code, stdout, stderr } = await runCli(APPLY);
  assert.equal(code, 0, stderr);
  const report = JSON.parse(stdout);
  assert.equal(report.halaqat.migrated, 0);
  assert.equal(report.halaqat.candidates, 0);
  assert.equal(report.halaqat.canonical.alreadyMigrated, 3);
  assert.deepEqual(await snapshotAll(), before);
});

test("paging (real SDK): every halaqa visited once across pages", async () => {
  const docs = {};
  for (let i = 0; i < 7; i += 1) docs[`halaqat/hPage${i}`] = { meetingLink: `${LINK_A}-${i}`, supervisorId: "" };
  for (let i = 0; i < 4; i += 1) docs[`halaqaMeetingLinks/hOrphanPage${i}`] = { meetingLink: LINK_B, updatedAt: ts() };
  await seed(docs);
  const report = await runInProcess("apply", { pageSize: 3 });
  assert.equal(report.halaqat.scanned, 7);
  assert.equal(report.halaqat.migrated, 7);
  assert.deepEqual(report.orphanCanonical, { scanned: 11, orphans: 4 });
  for (let i = 0; i < 7; i += 1) {
    assert.equal((await db.doc(`halaqaMeetingLinks/hPage${i}`).get()).data().meetingLink, `${LINK_A}-${i}`);
  }
});

test("per-record failure (real SDK): counted by code, others migrated; a rerun resumes", async () => {
  await seed({
    "halaqat/hOk1": { meetingLink: LINK_A },
    "halaqat/hBad": { meetingLink: LINK_B },
    "halaqat/hOk2": { meetingLink: LINK_A },
  });
  const real = writer();
  const failing = {
    migrateOne: (id) =>
      id === "hBad"
        ? Promise.reject(Object.assign(new Error(`failed for ${LINK_B}`), { code: 14 }))
        : real.migrateOne(id),
  };
  const first = await runInProcess("apply", { writer: failing });
  assert.deepEqual(first.failures, { total: 1, byCode: { unavailable: 1 } });
  assert.deepEqual(first.review.failedIds.ids, ["hBad"]);
  assert.equal(first.halaqat.migrated, 2);
  assert.equal(first.summary.exitCode, 4);
  assert.equal((await db.doc("halaqaMeetingLinks/hBad").get()).exists, false);
  outputs.push({ label: "failure report", text: JSON.stringify(first) });

  const second = await runInProcess("apply");
  assert.equal(second.halaqat.migrated, 1);
  assert.equal(second.halaqat.canonical.alreadyMigrated, 2);
  assert.equal(second.summary.exitCode, 0);
  assert.equal((await db.doc("halaqaMeetingLinks/hBad").get()).data().meetingLink, LINK_B);
});

const malformedIdDocs = () => ({
  "users/stuEligible": { role: "student", isActive: true },
  "studentProfiles/stuEligible": { lifecycle: "active" },
  "users/sup1": { role: "supervisor", isActive: true },
  "halaqat/hIds1": { meetingLink: LINK_A, supervisorId: "sup1", studentIds: ["stuEligible"] },
  "halaqat/hIds2": { meetingLink: PADDED, supervisorId: "..", studentIds: ["__x__", ".", "..", "u".repeat(1501), "stuEligible"] },
  "halaqat/hIds3": { meetingLink: LINK_B, supervisorId: "__sup__", studentIds: ["____"] },
  "halaqat/hIds4": { meetingLink: LINK_A, supervisorId: ".", studentIds: ["stuEligible"] },
});

test("malformed ids (real SDK): never sent to Firestore; every halaqa still migrates", async () => {
  await assert.rejects(db.getAll(db.doc("users/__x__")), { code: 3 }, "the emulator rejects reserved ids");

  await seed(malformedIdDocs());
  const paged = await runInProcess("apply", { pageSize: 1 });
  assert.equal(paged.halaqat.scanned, 4);
  assert.equal(paged.halaqat.migrated, 4);
  assert.equal(paged.roster.malformedEntries, 5);
  assert.equal(paged.roster.entries, 3);
  assert.equal(paged.supervisors.malformed, 3);
  assert.deepEqual(paged.failures, { total: 0, byCode: {} });
  assert.equal(paged.summary.exitCode, 0);
  assert.equal((await db.doc("halaqaMeetingLinks/hIds2").get()).data().meetingLink, PADDED.trim());
  outputs.push({ label: "malformed ids report", text: JSON.stringify(paged) });

  await clearFirestore();
  await seed(malformedIdDocs());
  const dry = await runCli(DRY);
  assert.equal(dry.code, 0, dry.stderr);
  assert.equal(JSON.parse(dry.stdout).halaqat.wouldMigrate, 4);
  const applied = await runCli(APPLY);
  assert.equal(applied.code, 0, applied.stderr);
  const report = JSON.parse(applied.stdout);
  assert.equal(report.halaqat.migrated, 4);
  assert.equal(report.roster.malformedEntries, 5);
  assert.equal(report.supervisors.malformed, 3);
  assert.equal(applied.stdout.includes("__x__") || applied.stderr.includes("__x__"), false);
  for (const id of ["hIds1", "hIds2", "hIds3", "hIds4"]) {
    assert.equal((await db.doc(`halaqaMeetingLinks/${id}`).get()).exists, true, id);
  }
});

function staleStore(pages) {
  return {
    page: async (collection, afterId) => (collection === "halaqat" && afterId === null ? pages : []),
    getMany: async (collection, ids) => ids.map((id) => ({ id, exists: false, data: null })),
  };
}

test("stale scan (real SDK): the write decision comes from the transactional re-read", async () => {
  await seed({
    "users/admin1": { role: "admin", isActive: true },
    "halaqat/hCleared": { meetingLink: LINK_A, supervisorId: "" },
    "halaqat/hReplaced": { meetingLink: LINK_A, supervisorId: "" },
  });
  const pages = [
    { id: "hCleared", exists: true, data: { meetingLink: LINK_A } },
    { id: "hReplaced", exists: true, data: { meetingLink: LINK_A } },
  ];
  const clear = await setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hCleared", clear: true });
  assert.equal(clear.operation, "clear");
  const set = await setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hReplaced", meetingLink: LINK_B });
  assert.equal(set.operation, "update");

  const report = await runInProcess("apply", { store: staleStore(pages) });
  assert.equal(report.halaqat.candidates, 2);
  assert.equal(report.halaqat.migrated, 0);
  assert.equal(report.halaqat.changedDuringRun.empty, 1);
  assert.equal(report.halaqat.changedDuringRun.canonicalAppeared, 1);
  assert.equal((await db.doc("halaqaMeetingLinks/hCleared").get()).exists, false, "a cleared link is not resurrected");
  assert.equal((await db.doc("halaqaMeetingLinks/hReplaced").get()).data().meetingLink, LINK_B, "the admin's link is kept");
});

async function raceRound(competitor) {
  await clearFirestore();
  await seed({
    "users/admin1": { role: "admin", isActive: true },
    "halaqat/hRace": { meetingLink: LINK_A, supervisorId: "" },
  });
  let competing = null;
  const raced = writer(async () => {
    if (competing === null) {
      competing = competitor().then(
        (value) => ({ status: "fulfilled", value }),
        (reason) => ({ status: "rejected", code: reason?.code }),
      );
      await delay(30);
    }
  });
  const [migration] = await Promise.allSettled([raced.migrateOne("hRace")]);
  const other = await competing;
  const canonical = await db.doc("halaqaMeetingLinks/hRace").get();
  const legacy = (await db.doc("halaqat/hRace").get()).data().meetingLink;
  return {
    migration: migration.status === "fulfilled" ? migration.value : `rejected:${migration.reason?.code}`,
    other,
    canonical: canonical.exists ? canonical.data().meetingLink : null,
    legacy,
  };
}

test("concurrent clear (real SDK, 8 rounds): a link cleared by the admin never survives", async () => {
  const seen = [];
  for (let round = 0; round < 8; round += 1) {
    const r = await raceRound(() => setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hRace", clear: true }));
    seen.push(`${r.migration}/${r.other.status}`);
    if (r.other.status === "fulfilled") {
      assert.equal(r.other.value.operation, "clear");
      assert.equal(r.canonical, null, `round ${round}: cleared link resurrected`);
      assert.equal(r.legacy, "");
    } else {
      assert.equal(r.legacy, LINK_A, `round ${round}: a failed clear changed nothing`);
      assert.ok(r.canonical === null || r.canonical === LINK_A, `round ${round}`);
    }
    assert.ok(!(r.canonical !== null && r.legacy === ""), `round ${round}: canonical without legacy`);
  }
  console.log(`concurrent clear outcomes (migration/clear): ${seen.join(", ")}`);
});

test("concurrent set (real SDK, 8 rounds): the admin's new link is never overwritten", async () => {
  const seen = [];
  for (let round = 0; round < 8; round += 1) {
    const r = await raceRound(() => setHalaqaMeetingLinkCore(db, "admin1", { halaqaId: "hRace", meetingLink: LINK_B }));
    seen.push(`${r.migration}/${r.other.status}`);
    if (r.other.status === "fulfilled") {
      assert.equal(r.canonical, LINK_B, `round ${round}: admin link overwritten`);
      assert.equal(r.legacy, LINK_B);
    } else {
      assert.equal(r.legacy, LINK_A);
      assert.ok(r.canonical === null || r.canonical === LINK_A, `round ${round}`);
    }
  }
  console.log(`concurrent set outcomes (migration/set): ${seen.join(", ")}`);
});

test("redaction: no CLI or report output contains link values, URL parts or person ids", () => {
  assert.ok(outputs.length >= 8, "outputs were collected");
  for (const { label, text } of outputs) {
    for (const needle of FORBIDDEN_OUTPUT) {
      assert.equal(text.includes(needle), false, `${label}: contains ${JSON.stringify(needle)}`);
    }
    for (const id of PERSON_IDS) assert.equal(text.includes(id), false, `${label}: ${id} leaked`);
    assert.equal(text.includes("egress blocked"), false, `${label}: preload blocked a connection`);
    assert.equal(text.includes("non-emulator connection"), false, `${label}: script guard blocked a connection`);
  }
});

test("no connection outside the isolated emulator was attempted by the test process", () => {
  assert.deepEqual(guard.blockedAttempts(), []);
});
