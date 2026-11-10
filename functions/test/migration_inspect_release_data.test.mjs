/**
 * Release data inspection (read-only): invocation gate, calendar
 * classification, id digests and the combined report, on in-memory data.
 * Build functions first (the B14 validator comes from lib/).
 *
 *   node --test functions/test/migration_inspect_release_data.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  CALENDAR_SCOPES,
  EXPORT_COLLECTIONS,
  buildPlan,
  checkInvocation,
  classifyCalendarDate,
  classifyCalendarScope,
  idsDigest,
  inspectionStore,
  runCalendarInspection,
  runReleaseDataInspection,
} from "../scripts/migration-inspect-release-data.mjs";
import { EMULATOR_PROJECT } from "../scripts/migrate-meeting-links.mjs";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const { meetingLinkIssue } = require("../lib/halaqa/meetingLinkFunctions.js");

const MARK = "zqinspect";
const LINK_A = `https://meet.example.test/${MARK}-a`;
const LINK_B = `https://video.example.org/j/${MARK}-b`;
const TITLE = `${MARK} title`;

class FakeTimestamp {}
const TS = new FakeTimestamp();
const isTs = (v) => v instanceof FakeTimestamp;

const validEnv = () => ({
  MEETING_LINK_MIGRATION_EMULATOR: "1",
  MEETING_LINK_MIGRATION_PORTS: "38080,34400",
  FIRESTORE_EMULATOR_HOST: "127.0.0.1:38080",
  FIREBASE_EMULATOR_HUB: "127.0.0.1:34400",
});

function memoryLinkStore(collections) {
  const sorted = (name) => [...(collections[name] ?? new Map()).keys()].sort();
  return {
    page: async (name, afterId, size) => {
      const ids = sorted(name).filter((id) => afterId === null || id > afterId).slice(0, size);
      return ids.map((id) => ({ id, exists: true, data: collections[name].get(id) }));
    },
    getMany: async (name, ids) =>
      ids.map((id) => {
        const data = collections[name]?.get(id);
        return { id, exists: data !== undefined, data: data ?? null };
      }),
  };
}

function memoryInspectionStore(collections) {
  const sorted = (name) => [...(collections[name] ?? new Map()).keys()].sort();
  return {
    page: async (name, afterId, size) => {
      const ids = sorted(name).filter((id) => afterId === null || id > afterId).slice(0, size);
      return ids.map((id) => ({ id, exists: true, data: collections[name].get(id) }));
    },
    halaqaExists: async (ids) => new Map(ids.map((id) => [id, collections.halaqat.has(id)])),
  };
}

function fixture() {
  return {
    halaqat: new Map([
      ["h1", { name: "n", meetingLink: LINK_A, studentIds: ["s1"] }],
      ["h2", { name: "n", meetingLink: LINK_A }],
      ["h3", { name: "n" }],
    ]),
    users: new Map([["s1", { role: "student", isActive: true }]]),
    studentProfiles: new Map([["s1", { lifecycle: "active" }]]),
    halaqaMeetingLinks: new Map([
      ["h2", { meetingLink: LINK_B, updatedAt: TS }],
      ["h3", { meetingLink: LINK_B, updatedAt: TS }],
    ]),
    calendarEvents: new Map([
      ["eMissing", { title: TITLE, date: TS }],
      ["eNull", { title: TITLE, date: TS, halaqaId: null }],
      ["eH1", { title: TITLE, date: TS, halaqaId: "h1" }],
      ["eGone", { title: TITLE, date: TS, halaqaId: "hDeleted" }],
      ["eEmpty", { title: TITLE, date: TS, halaqaId: "" }],
      ["eNum", { title: TITLE, date: TS, halaqaId: 7 }],
      ["eBadId", { title: TITLE, date: TS, halaqaId: "a/b" }],
      ["eNoDate", { title: TITLE, halaqaId: null }],
      ["eStrDate", { title: TITLE, date: "2026-10-28", halaqaId: "h1" }],
    ]),
  };
}

// ── invocation gate ────────────────────────────────────────────────────────

test("plan mode without arguments; inspect only on the emulator project", () => {
  assert.deepEqual(checkInvocation({ argv: [], env: {} }), { problems: [], mode: "plan", config: null });
  const ok = checkInvocation({ argv: ["--project", EMULATOR_PROJECT], env: validEnv() });
  assert.deepEqual(ok.problems, []);
  assert.equal(ok.mode, "inspect");
  assert.equal(ok.config.firestorePort, 38080);
  assert.equal(ok.config.hubPort, 34400);
  assert.equal(checkInvocation({ argv: [`--project=${EMULATOR_PROJECT}`], env: validEnv() }).mode, "inspect");
  const plan = buildPlan();
  assert.equal(plan.connects, false);
  assert.equal(plan.scope.writes, "none");
});

test("real projects, write flags, unknown flags and a bad environment are refused", () => {
  for (const project of ["rafiq-academy", "rafiq-academy-prod", "demo-other"]) {
    const result = checkInvocation({ argv: ["--project", project], env: validEnv() });
    assert.equal(result.mode, null, project);
    assert.ok(result.problems.length > 0, project);
  }
  for (const flag of ["--apply", "--confirm", "--strip-legacy", "--dry-run", "--apply=1"]) {
    const result = checkInvocation({ argv: ["--project", EMULATOR_PROJECT, flag], env: validEnv() });
    assert.equal(result.mode, null, flag);
    assert.ok(result.problems.some((p) => p.includes("read-only")), flag);
  }
  assert.equal(checkInvocation({ argv: ["--project", EMULATOR_PROJECT, "--force"], env: validEnv() }).mode, null);
  assert.equal(checkInvocation({ argv: ["--project"], env: validEnv() }).mode, null);
  for (const env of [
    {},
    { ...validEnv(), GOOGLE_APPLICATION_CREDENTIALS: "key.json" },
    { ...validEnv(), FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443" },
    { ...validEnv(), GOOGLE_CLOUD_PROJECT: "rafiq-academy" },
    { ...validEnv(), MEETING_LINK_MIGRATION_PORTS: "8080,4400" },
  ]) {
    assert.equal(checkInvocation({ argv: ["--project", EMULATOR_PROJECT], env }).mode, null);
  }
});

test("the script source has no write path", () => {
  const source = readFileSync(join(here, "..", "scripts", "migration-inspect-release-data.mjs"), "utf8");
  // Firestore writes need a transaction, batch, bulk writer, FieldValue or a
  // DocumentReference/CollectionReference write; none may appear.
  for (const forbidden of [
    /\.doc\([^)]*\)\s*\.(set|update|create|delete)\(/, /\.collection\([^)]*\)\s*\.add\(/, /\btx\./,
    /batch\(/, /bulkWriter/, /runTransaction/, /FieldValue/, /recursiveDelete/,
    /\bref\.(set|update|create|delete)\(/,
  ]) {
    assert.doesNotMatch(source, forbidden, String(forbidden));
  }
  // Only read-side helpers come from the migration entry point (no writers).
  const imported = source.match(/import \{([^}]*)\} from "\.\/migrate-meeting-links\.mjs"/)[1]
    .split(",").map((name) => name.trim()).filter(Boolean).sort();
  assert.deepEqual(imported, [
    "EMULATOR_PROJECT", "KNOWN_REAL_PROJECTS", "PAGE_SIZE", "checkInvocation as checkEmulatorInvocation",
    "createIdList", "readOnlyStore", "runLegacyStrip", "runMeetingLinkMigration", "safeErrorCode",
    "startEgressGuard", "verifyHub",
  ]);
});

// ── classification ─────────────────────────────────────────────────────────

test("calendar halaqaId: missing differs from explicit null", () => {
  assert.equal(classifyCalendarScope({}), "missing");
  assert.equal(classifyCalendarScope({ halaqaId: undefined }), "nonString");
  assert.equal(classifyCalendarScope({ halaqaId: null }), "null");
  assert.equal(classifyCalendarScope({ halaqaId: "h1" }), "halaqa");
  assert.equal(classifyCalendarScope({ halaqaId: "  " }), "emptyString");
  assert.equal(classifyCalendarScope({ halaqaId: 3 }), "nonString");
  assert.equal(classifyCalendarScope({ halaqaId: "a/b" }), "invalidId");
  assert.equal(classifyCalendarScope({ halaqaId: "__x__" }), "invalidId");
  assert.deepEqual([...CALENDAR_SCOPES].sort(), ["emptyString", "halaqa", "invalidId", "missing", "nonString", "null", "orphanHalaqa"]);
});

test("calendar date: only Timestamps match the month query", () => {
  assert.equal(classifyCalendarDate({ date: TS }, isTs), "timestamp");
  assert.equal(classifyCalendarDate({}, isTs), "missing");
  assert.equal(classifyCalendarDate({ date: null }, isTs), "missing");
  assert.equal(classifyCalendarDate({ date: "2026-10-28" }, isTs), "other");
});

test("id digests are order-independent and change with the id set", () => {
  assert.equal(idsDigest(["b", "a"]), idsDigest(["a", "b"]));
  assert.notEqual(idsDigest(["a", "b"]), idsDigest(["a", "b", "c"]));
  assert.match(idsDigest([]), /^[0-9a-f]{64}$/);
});

// ── reports ────────────────────────────────────────────────────────────────

test("calendar inspection counts every category across pages and lists ids only", async () => {
  const data = fixture();
  const { inventory, report } = await runCalendarInspection({ store: memoryInspectionStore(data), isTimestamp: isTs, pageSize: 2 });
  assert.equal(inventory.documents, 9);
  assert.equal(inventory.idsSha256, idsDigest([...data.calendarEvents.keys()]));
  assert.equal(report.scanned, 9);
  assert.deepEqual(report.halaqaId, {
    missing: 1, null: 2, halaqa: 2, orphanHalaqa: 1, emptyString: 1, invalidId: 1, nonString: 1,
  });
  assert.deepEqual(report.date, { timestamp: 7, missing: 1, other: 1 });
  assert.equal(report.wouldBackfillToNull, 1);
  assert.deepEqual(report.review.missingHalaqaIdIds.ids, ["eMissing"]);
  assert.deepEqual(report.review.orphanHalaqaIds.ids, ["eGone"]);
  assert.deepEqual(report.review.invalidHalaqaIdIds.ids.sort(), ["eBadId", "eEmpty", "eNum"]);
  assert.deepEqual(report.review.invalidDateIds.ids.sort(), ["eNoDate", "eStrDate"]);
  assert.equal(report.needsReview, true);
});

test("a clean calendar needs no review", async () => {
  const data = { halaqat: new Map([["h1", {}]]), calendarEvents: new Map([
    ["a", { date: TS, halaqaId: null }],
    ["b", { date: TS, halaqaId: "h1" }],
  ]) };
  const { report } = await runCalendarInspection({ store: memoryInspectionStore(data), isTimestamp: isTs });
  assert.equal(report.needsReview, false);
  assert.equal(report.wouldBackfillToNull, 0);
});

test("combined report: backup inventory, calendar and both meeting-link dry runs, no values", async () => {
  const data = fixture();
  const report = await runReleaseDataInspection({
    linkStore: memoryLinkStore(data),
    store: memoryInspectionStore(data),
    issueOf: meetingLinkIssue,
    isTimestamp: isTs,
    pageSize: 2,
  });
  assert.equal(report.mode, "inspect");
  assert.equal(report.writes, 0);
  assert.deepEqual(Object.keys(report.backup.collections).sort(), [...EXPORT_COLLECTIONS].sort());
  assert.deepEqual(report.backup.collections.halaqat, { documents: 3, idsSha256: idsDigest(["h1", "h2", "h3"]) });
  assert.deepEqual(report.backup.collections.halaqaMeetingLinks, { documents: 2, idsSha256: idsDigest(["h2", "h3"]) });
  assert.equal(report.backup.collections.calendarEvents.documents, 9);
  assert.equal(report.backup.collections.users.documents, 1);
  assert.equal(report.backup.collections.studentProfiles.documents, 1);
  assert.equal(report.backup.totalDocuments, 16);
  assert.deepEqual(report.backup.emptyCollections, []);
  assert.equal(report.meetingLinks.copy.roster.eligible, 1);
  assert.equal(report.meetingLinks.copy.roster.missingUser, 0);
  assert.equal(report.meetingLinks.copy.mode, "dry-run");
  assert.equal(report.meetingLinks.strip.mode, "dry-run");
  assert.equal(report.meetingLinks.notYetCopied, 1);
  assert.equal(report.meetingLinks.lostOnStrip, 1);
  assert.deepEqual(report.meetingLinks.copy.review.conflictIds.ids, ["h2"]);
  assert.deepEqual(report.meetingLinks.strip.review.needsCopyIds.ids, ["h1"]);
  assert.deepEqual(report.meetingLinks.strip.review.supersededLegacyIds.ids, ["h2"]);
  assert.equal(report.meetingLinks.strip.halaqat.stripped, 0);
  assert.equal(report.meetingLinks.copy.halaqat.migrated, 0);
  assert.equal(report.summary.needsReview, true);
  const text = JSON.stringify(report);
  for (const forbidden of [MARK, "://", "example.test", "example.org", "2026-10-28"]) {
    assert.ok(!text.includes(forbidden), `report must not contain ${forbidden}`);
  }
  assert.equal(data.halaqat.get("h1").meetingLink, LINK_A, "in-memory data unchanged");
  assert.equal(data.halaqat.size, 3);
});

test("an export without users / studentProfiles is flagged instead of reporting missing students", async () => {
  const data = fixture();
  delete data.users;
  delete data.studentProfiles;
  const report = await runReleaseDataInspection({
    linkStore: memoryLinkStore(data),
    store: memoryInspectionStore(data),
    issueOf: meetingLinkIssue,
    isTimestamp: isTs,
  });
  assert.deepEqual(report.backup.emptyCollections, ["users", "studentProfiles"]);
  assert.equal(report.backup.totalDocuments, 14);
  assert.equal(report.meetingLinks.copy.roster.missingUser, 1);
  assert.equal(report.summary.needsReview, true);
});

test("the inspection store refuses collections outside the export scope", async () => {
  const fakeDb = { collection: () => assert.fail("must refuse before querying") };
  const store = inspectionStore(fakeDb, "__id__");
  await assert.rejects(store.page("auditLogs", null, 10), /outside the inspection scope/);
});
