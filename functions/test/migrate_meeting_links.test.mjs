/**
 * B14 meeting-link migration — unit and CLI-refusal tests. No emulator and no
 * network: classification uses the compiled B14 validator (build functions
 * first), the migration loop runs on an in-memory store, and CLI children run
 * with an egress preload that also forbids loading firebase-admin.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  CONFIRM_TOKEN,
  EMULATOR_PROJECT,
  STRIP_CONFIRM_TOKEN,
  SurfaceViolation,
  checkInvocation,
  classifyCanonical,
  classifyLegacy,
  createIdList,
  decide,
  decideStrip,
  isValidDocumentId,
  readOnlyStore,
  runLegacyStrip,
  runMeetingLinkMigration,
  safeErrorCode,
  studentEligibility,
  supervisorStatus,
} from "../scripts/migrate-meeting-links.mjs";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const SCRIPT = join(functionsDir, "scripts", "migrate-meeting-links.mjs");
const PRELOAD = pathToFileURL(join(here, "migrate_meeting_links_egress_preload.mjs")).href;
const { meetingLinkIssue } = require("../lib/halaqa/meetingLinkFunctions.js");

// Synthetic fixtures only (reserved example domains); every one carries a marker.
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

function assertRedacted(text, label) {
  for (const needle of FORBIDDEN_OUTPUT) {
    assert.equal(text.includes(needle), false, `${label} must not contain ${JSON.stringify(needle)}`);
  }
}

const validEnv = () => ({
  MEETING_LINK_MIGRATION_EMULATOR: "1",
  MEETING_LINK_MIGRATION_PORTS: "38080,34400",
  FIRESTORE_EMULATOR_HOST: "127.0.0.1:38080",
  FIREBASE_EMULATOR_HUB: "127.0.0.1:34400",
});
const run = (argv, env = validEnv()) => checkInvocation({ argv, env });
const dryRunArgs = ["--project", EMULATOR_PROJECT];
const applyArgs = ["--project", EMULATOR_PROJECT, "--apply", "--confirm", CONFIRM_TOKEN];

// ── invocation gate ────────────────────────────────────────────────────────

test("no arguments is plan mode and needs no environment", () => {
  const result = checkInvocation({ argv: [], env: {} });
  assert.deepEqual(result.problems, []);
  assert.equal(result.mode, "plan");
});

test("dry run is the default; apply needs the exact confirmation token", () => {
  assert.equal(run(dryRunArgs).mode, "dry-run");
  assert.equal(run([...dryRunArgs, "--dry-run"]).mode, "dry-run");
  assert.equal(run(applyArgs).mode, "apply");
  for (const argv of [
    [...dryRunArgs, "--apply"],
    [...dryRunArgs, "--apply", "--confirm", "meeting-link-migration:rafiq-academy"],
    [...dryRunArgs, "--confirm", CONFIRM_TOKEN],
    [...applyArgs, "--dry-run"],
    ["--apply", "--confirm", CONFIRM_TOKEN],
    ["--dry-run"],
  ]) {
    const result = run(argv);
    assert.equal(result.mode, null, JSON.stringify(argv));
    assert.ok(result.problems.length > 0);
  }
});

test("real and unknown projects are refused without echoing other values", () => {
  for (const project of ["rafiq-academy", "rafiq-academy-staging", "rafiq-academy-prod"]) {
    const result = run(["--project", project]);
    assert.equal(result.mode, null);
    assert.ok(result.problems.some((p) => p.startsWith("Real Firebase projects are not supported")));
  }
  for (const project of ["demo-other", "zz-secret-project-77", "Not A Project", "demo-rafiq-rules "]) {
    const result = run(["--project", project]);
    assert.equal(result.mode, null);
    assert.ok(result.problems.some((p) => p.startsWith("--project is not supported")));
    for (const secret of ["demo-other", "zz-secret-project-77", "Not A Project"]) {
      assert.equal(result.problems.join("\n").includes(secret), false, `${secret} echoed`);
    }
  }
  const unknown = run([...dryRunArgs, "--token=zz-secret-77", "positional-zz"]);
  assert.equal(unknown.problems.join("\n").includes("zz-secret-77"), false);
  assert.equal(unknown.problems.join("\n").includes("positional-zz"), false);
});

test("environment must pin a loopback emulator and carry no real-project settings", () => {
  const cases = {
    "missing opt-in": { MEETING_LINK_MIGRATION_EMULATOR: undefined },
    "missing ports": { MEETING_LINK_MIGRATION_PORTS: undefined },
    "default ports": {
      MEETING_LINK_MIGRATION_PORTS: "8080,4400",
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
      FIREBASE_EMULATOR_HUB: "127.0.0.1:4400",
    },
    "same port twice": { MEETING_LINK_MIGRATION_PORTS: "38080,38080", FIREBASE_EMULATOR_HUB: "127.0.0.1:38080" },
    "firestore host unset": { FIRESTORE_EMULATOR_HOST: undefined },
    "firestore host remote": { FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443" },
    "firestore host other port": { FIRESTORE_EMULATOR_HOST: "127.0.0.1:38081" },
    "hub mismatch": { FIREBASE_EMULATOR_HUB: "127.0.0.1:34401" },
    "other emulator remote": { FIREBASE_AUTH_EMULATOR_HOST: "10.0.0.5:9099" },
    credentials: { GOOGLE_APPLICATION_CREDENTIALS: "C:\\keys\\sa.json" },
    "client certificate": { GOOGLE_API_USE_CLIENT_CERTIFICATE: "true" },
    "project env": { GOOGLE_CLOUD_PROJECT: "rafiq-academy" },
    "gcloud project": { CLOUDSDK_CORE_PROJECT: "rafiq-academy" },
    "firebase config": { FIREBASE_CONFIG: JSON.stringify({ projectId: "rafiq-academy" }) },
    "firebase config unparsable": { FIREBASE_CONFIG: "{" },
    "node preload": { NODE_OPTIONS: "--import ./x.mjs" },
    "node require": { NODE_OPTIONS: "-r ./x.cjs" },
  };
  for (const [label, patch] of Object.entries(cases)) {
    const env = { ...validEnv(), ...patch };
    for (const [key, value] of Object.entries(patch)) if (value === undefined) delete env[key];
    const result = run(dryRunArgs, env);
    assert.equal(result.mode, null, label);
    assert.ok(result.problems.length > 0, label);
    const text = result.problems.join("\n");
    assert.equal(text.includes("googleapis"), false, `${label}: host echoed`);
    assert.equal(text.includes("sa.json"), false, `${label}: path echoed`);
  }
  const matching = run(dryRunArgs, {
    ...validEnv(),
    GCLOUD_PROJECT: EMULATOR_PROJECT,
    FIREBASE_CONFIG: JSON.stringify({ projectId: EMULATOR_PROJECT }),
  });
  assert.equal(matching.mode, "dry-run");
});

// ── classification ─────────────────────────────────────────────────────────

test("legacy values: missing, empty, non-string, invalid by reason, valid and trim-required", () => {
  const c = (data) => classifyLegacy(data, meetingLinkIssue);
  assert.deepEqual(c({}), { category: "missing" });
  assert.deepEqual(c({ meetingLink: "" }), { category: "empty" });
  assert.deepEqual(c({ meetingLink: " \t " }), { category: "empty" });
  for (const raw of [null, 5, true, { url: LINK_A }, [LINK_A]]) {
    assert.deepEqual(c({ meetingLink: raw }), { category: "nonString" });
  }
  for (const [reason, raw] of Object.entries(INVALID)) {
    assert.deepEqual(c({ meetingLink: raw }), { category: "invalid", reason }, reason);
  }
  assert.deepEqual(c({ meetingLink: LINK_A }), { category: "valid", value: LINK_A, trimRequired: false });
  assert.deepEqual(c({ meetingLink: PADDED }), { category: "valid", value: PADDED.trim(), trimRequired: true });
});

class FakeTimestamp {}
const TS = new FakeTimestamp();
const isTs = (v) => v instanceof FakeTimestamp;

test("canonical documents: well-formed or malformed by reason", () => {
  const c = (data) => classifyCanonical(data, meetingLinkIssue, isTs);
  assert.deepEqual(c({ meetingLink: LINK_A, updatedAt: TS }), { malformed: false, value: LINK_A });
  const reasons = {
    missing_meeting_link: { updatedAt: TS },
    extra_keys: { meetingLink: LINK_A, updatedAt: TS, note: "x" },
    non_string: { meetingLink: 7, updatedAt: TS },
    untrimmed: { meetingLink: ` ${LINK_A}`, updatedAt: TS },
    invalid_link: { meetingLink: INVALID.not_https, updatedAt: TS },
    bad_updated_at: { meetingLink: LINK_A, updatedAt: "yesterday" },
  };
  for (const [reason, data] of Object.entries(reasons)) {
    assert.deepEqual(c(data), { malformed: true, reason }, reason);
  }
  assert.deepEqual(c({ meetingLink: LINK_A }), { malformed: true, reason: "bad_updated_at" });
});

test("decisions never write over an existing canonical document", () => {
  const valid = { category: "valid", value: LINK_A };
  assert.equal(decide(valid, null), "candidate");
  for (const category of ["missing", "empty", "nonString", "invalid"]) {
    assert.equal(decide({ category }, null), "noAction");
    assert.equal(decide({ category }, { malformed: false, value: LINK_A }), "withoutValidLegacy");
  }
  assert.equal(decide(valid, { malformed: false, value: LINK_A }), "alreadyMigrated");
  assert.equal(decide(valid, { malformed: false, value: LINK_B }), "conflict");
  assert.equal(decide(valid, { malformed: true, reason: "untrimmed" }), "malformed");
});

test("student eligibility mirrors the canonical read rule; supervisors are checked by role", () => {
  const student = { role: "student", isActive: true };
  assert.equal(studentEligibility(null, {}), "missingUser");
  assert.equal(studentEligibility({ ...student, isActive: false }, {}), "inactive");
  assert.equal(studentEligibility({ role: "parent" }, {}), "nonStudentRole");
  assert.equal(studentEligibility(student, null), "missingProfile");
  assert.equal(studentEligibility(student, { lifecycle: "archived" }), "archived");
  assert.equal(studentEligibility(student, { lifecycle: " archived_old" }), "archived");
  assert.equal(studentEligibility(student, { lifecycle: "Active" }), "eligible");
  assert.equal(studentEligibility({ role: "student" }, {}), "eligible");
  assert.equal(supervisorStatus(null), "missingUser");
  assert.equal(supervisorStatus({ role: "supervisor", isActive: false }), "inactive");
  assert.equal(supervisorStatus({ role: "teacher" }), "wrongRole");
  assert.equal(supervisorStatus({ role: "supervisor" }), "ok");
});

test("error codes and id lists never carry messages or unsafe ids", () => {
  assert.equal(safeErrorCode({ code: 10, message: LINK_A }), "aborted");
  assert.equal(safeErrorCode({ code: 3 }), "invalid-argument");
  assert.equal(safeErrorCode({ code: LINK_A }), "unknown");
  assert.equal(safeErrorCode(new Error(LINK_A)), "unknown");
  const ids = createIdList(2);
  for (const id of ["h1", "h/2", LINK_A, "h3", "h4"]) ids.add(id);
  assert.deepEqual(ids.toJSON(), { total: 5, ids: ["h1", "h3"], truncated: true, unprintable: 2 });
});

// ── migration loop on an in-memory store ───────────────────────────────────

function memoryStore(collections) {
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

function memoryWriter(collections, { failIds = new Set() } = {}) {
  return {
    migrateOne: async (id) => {
      if (failIds.has(id)) throw Object.assign(new Error(`write failed for ${LINK_A}`), { code: 14 });
      const halaqa = collections.halaqat.get(id);
      if (!halaqa) return "halaqaGone";
      if (collections.halaqaMeetingLinks.has(id)) return "canonicalAppeared";
      const legacy = classifyLegacy(halaqa, meetingLinkIssue);
      if (legacy.category !== "valid") return legacy.category;
      collections.halaqaMeetingLinks.set(id, { meetingLink: legacy.value, updatedAt: TS });
      return "migrated";
    },
  };
}

function fixture() {
  const halaqat = new Map([
    ["hMissing", { name: "n", supervisorId: "sup1", studentIds: ["s1"] }],
    ["hEmpty", { meetingLink: "", supervisorId: "sup1" }],
    ["hNonString", { meetingLink: 42, supervisorId: "sup1" }],
    ["hValid", { meetingLink: LINK_A, supervisorId: "sup1", studentIds: ["s1", "sNoProfile"] }],
    ["hPadded", { meetingLink: PADDED, supervisorId: "supInactive", studentIds: ["sArchived"] }],
    ["hSame", { meetingLink: LINK_A, supervisorId: "", studentIds: [7, ""] }],
    ["hConflict", { meetingLink: LINK_A, supervisorId: "teacher1" }],
    ["hMalformed", { meetingLink: LINK_A, supervisorId: "sup1" }],
    ["hMirror", { meetingLink: "", supervisorId: "supMissing" }],
    ...Object.entries(INVALID).map(([reason, raw]) => [`hInv_${reason}`, { meetingLink: raw, supervisorId: "sup1" }]),
  ]);
  const halaqaMeetingLinks = new Map([
    ["hSame", { meetingLink: LINK_A, updatedAt: TS }],
    ["hConflict", { meetingLink: LINK_B, updatedAt: TS }],
    ["hMalformed", { meetingLink: LINK_A, updatedAt: TS, extra: true }],
    ["hMirror", { meetingLink: LINK_B, updatedAt: TS }],
    ["hOrphan", { meetingLink: LINK_B, updatedAt: TS }],
  ]);
  const users = new Map([
    ["s1", { role: "student", isActive: true }],
    ["sNoProfile", { role: "student" }],
    ["sArchived", { role: "student" }],
    ["sup1", { role: "supervisor" }],
    ["supInactive", { role: "supervisor", isActive: false }],
    ["teacher1", { role: "teacher" }],
  ]);
  const studentProfiles = new Map([
    ["s1", { lifecycle: "active" }],
    ["sArchived", { lifecycle: "archived" }],
  ]);
  return { halaqat, halaqaMeetingLinks, users, studentProfiles };
}

test("dry run counts every category and writes nothing", async () => {
  const data = fixture();
  const before = JSON.stringify([...data.halaqaMeetingLinks]);
  const report = await runMeetingLinkMigration({
    store: memoryStore(data),
    mode: "dry-run",
    issueOf: meetingLinkIssue,
    isTimestamp: isTs,
    pageSize: 3,
  });
  assert.equal(JSON.stringify([...data.halaqaMeetingLinks]), before);
  const h = report.halaqat;
  assert.equal(h.scanned, 17);
  assert.deepEqual(h.legacy, { missing: 1, empty: 2, nonString: 1, invalid: 8, valid: 5, trimRequired: 1 });
  for (const reason of Object.keys(INVALID)) assert.equal(h.invalidByReason[reason], 1, reason);
  assert.deepEqual(h.canonical, { absent: 13, alreadyMigrated: 1, conflict: 1, malformed: 1, withoutValidLegacy: 1 });
  assert.equal(h.malformedByReason.extra_keys, 1);
  assert.equal(h.candidates, 2);
  assert.equal(h.wouldMigrate, 2);
  assert.equal(h.migrated, 0);
  assert.deepEqual(report.orphanCanonical, { scanned: 5, orphans: 1 });
  assert.deepEqual(report.review.orphanIds.ids, ["hOrphan"]);
  assert.deepEqual(report.review.conflictIds.ids, ["hConflict"]);
  assert.deepEqual(report.roster, {
    entries: 4,
    malformedEntries: 2,
    distinctStudents: 3,
    missingUser: 0,
    inactive: 0,
    nonStudentRole: 0,
    missingProfile: 1,
    archived: 1,
    eligible: 1,
    ineligibleOnHalaqatWithValidLink: 2,
  });
  assert.deepEqual(report.supervisors, { halaqatWithoutSupervisor: 1, malformed: 0, missingUser: 1, inactive: 1, wrongRole: 1 });
  assert.equal(report.summary.needsReview, true);
  assert.equal(report.summary.exitCode, 0);
  const legacySum = Object.entries(h.legacy).filter(([k]) => k !== "trimRequired").reduce((a, [, v]) => a + v, 0);
  assert.equal(legacySum, h.scanned);
  assert.equal(Object.values(h.canonical).reduce((a, b) => a + b, 0), h.scanned);
});

test("apply creates only missing canonical docs, trimmed; rerun writes nothing", async () => {
  const data = fixture();
  const opts = { mode: "apply", issueOf: meetingLinkIssue, isTimestamp: isTs, pageSize: 4 };
  const first = await runMeetingLinkMigration({ ...opts, store: memoryStore(data), writer: memoryWriter(data) });
  assert.equal(first.halaqat.migrated, 2);
  assert.equal(data.halaqaMeetingLinks.get("hValid").meetingLink, LINK_A);
  assert.equal(data.halaqaMeetingLinks.get("hPadded").meetingLink, PADDED.trim());
  assert.equal(data.halaqaMeetingLinks.get("hConflict").meetingLink, LINK_B);
  assert.equal(data.halaqaMeetingLinks.get("hMirror").meetingLink, LINK_B);
  assert.equal(data.halaqaMeetingLinks.has("hEmpty"), false);
  assert.equal(data.halaqaMeetingLinks.has("hInv_not_https"), false);
  const again = await runMeetingLinkMigration({ ...opts, store: memoryStore(data), writer: memoryWriter(data) });
  assert.equal(again.halaqat.migrated, 0);
  assert.equal(again.halaqat.candidates, 0);
  assert.equal(again.halaqat.canonical.alreadyMigrated, 3);
});

test("per-record failures are counted by code, the run continues, and exit code is 4", async () => {
  const data = fixture();
  const report = await runMeetingLinkMigration({
    store: memoryStore(data),
    writer: memoryWriter(data, { failIds: new Set(["hValid"]) }),
    mode: "apply",
    issueOf: meetingLinkIssue,
    isTimestamp: isTs,
  });
  assert.deepEqual(report.failures, { total: 1, byCode: { unavailable: 1 } });
  assert.deepEqual(report.review.failedIds.ids, ["hValid"]);
  assert.equal(report.halaqat.migrated, 1);
  assert.equal(report.summary.exitCode, 4);
  assertRedacted(JSON.stringify(report), "failure report");
});

const BAD_DOC_IDS = [".", "..", "__x__", "____", "a/b", "u".repeat(1501), "\ud800", ""];

test("document ids: Firestore's naming rules decide validity", () => {
  for (const id of ["s1", "a b", "___", "_x_", "x__", "__x", "\u00e9", "u".repeat(1500)]) {
    assert.equal(isValidDocumentId(id), true, JSON.stringify(id.slice(0, 8)));
  }
  for (const id of [...BAD_DOC_IDS, 7, null, undefined]) {
    assert.equal(isValidDocumentId(id), false, JSON.stringify(String(id).slice(0, 8)));
  }
});

/** In-memory store that rejects invalid ids the way Firestore does (INVALID_ARGUMENT). */
function firestoreLikeStore(collections, requested) {
  const inner = memoryStore(collections);
  return {
    page: inner.page,
    getMany: async (name, ids) => {
      for (const id of ids) {
        requested.push(id);
        if (!isValidDocumentId(id)) throw Object.assign(new Error(`invalid id ${id}`), { code: 3 });
      }
      return inner.getMany(name, ids);
    },
  };
}

test("malformed roster and supervisor ids are skipped before Firestore; every other halaqa still migrates", async () => {
  const halaqat = new Map([
    ["h1", { meetingLink: LINK_A, supervisorId: "sup1", studentIds: ["s1"] }],
    ["h2", { meetingLink: PADDED, supervisorId: "..", studentIds: ["__x__", ".", "..", "u".repeat(1501), "s1"] }],
    ["h3", { meetingLink: LINK_B, supervisorId: "__sup__", studentIds: ["a/b"] }],
    ["h4", { meetingLink: LINK_A, supervisorId: "a/b", studentIds: ["____", "s1"] }],
    ["h5", { meetingLink: LINK_B, supervisorId: "sup1", studentIds: ["s1"] }],
  ]);
  const data = {
    halaqat,
    halaqaMeetingLinks: new Map(),
    users: new Map([["s1", { role: "student" }], ["sup1", { role: "supervisor" }]]),
    studentProfiles: new Map([["s1", { lifecycle: "active" }]]),
  };
  const requested = [];
  await assert.rejects(firestoreLikeStore(data, []).getMany("users", ["__x__"]), { code: 3 });

  for (const mode of ["dry-run", "apply"]) {
    const report = await runMeetingLinkMigration({
      store: firestoreLikeStore(data, requested),
      writer: mode === "apply" ? memoryWriter(data) : null,
      mode,
      issueOf: meetingLinkIssue,
      isTimestamp: isTs,
      pageSize: 1,
    });
    assert.equal(report.halaqat.scanned, 5, mode);
    assert.equal(report.halaqat.candidates, 5, mode);
    assert.equal(mode === "apply" ? report.halaqat.migrated : report.halaqat.wouldMigrate, 5, mode);
    assert.equal(report.roster.malformedEntries, 6, mode);
    assert.equal(report.roster.entries, 4, mode);
    assert.equal(report.roster.eligible, 1, mode);
    assert.equal(report.supervisors.malformed, 3, mode);
    assert.deepEqual(report.failures, { total: 0, byCode: {} }, mode);
    assert.equal(report.summary.exitCode, 0, mode);
    assertRedacted(JSON.stringify(report), `${mode} report`);
    assert.equal(JSON.stringify(report).includes("__x__"), false);
  }
  assert.deepEqual([...data.halaqaMeetingLinks.keys()].sort(), ["h1", "h2", "h3", "h4", "h5"]);
  assert.equal(data.halaqaMeetingLinks.get("h2").meetingLink, PADDED.trim());
  assert.equal(requested.every((id) => isValidDocumentId(id)), true, "no invalid id reached the store");
});

test("reports never contain link values, URL parts or person ids", async () => {
  for (const mode of ["dry-run", "apply"]) {
    const data = fixture();
    const report = await runMeetingLinkMigration({
      store: memoryStore(data),
      writer: mode === "apply" ? memoryWriter(data) : null,
      mode,
      issueOf: meetingLinkIssue,
      isTimestamp: isTs,
    });
    const text = JSON.stringify(report);
    assertRedacted(text, mode);
    for (const personId of ["s1", "sNoProfile", "sArchived", "supInactive", "supMissing", "teacher1"]) {
      assert.equal(text.includes(`"${personId}"`), false, `${mode}: ${personId} leaked`);
    }
  }
});

test("the read-only store exposes no write surface and only four collections", async () => {
  const store = readOnlyStore({}, "__name__");
  for (const prop of ["set", "update", "delete", "create", "batch", "runTransaction", "collection", "db"]) {
    assert.throws(() => store[prop], SurfaceViolation, prop);
  }
  assert.throws(() => {
    store.extra = 1;
  }, SurfaceViolation);
  await assert.rejects(store.page("users", null, 1), SurfaceViolation);
  await assert.rejects(store.getMany("auditLogs", ["x"]), SurfaceViolation);
});

// ── legacy strip (J.9) ─────────────────────────────────────────────────────

const stripArgs = [...dryRunArgs, "--strip-legacy"];
const stripApplyArgs = [...stripArgs, "--apply", "--confirm", STRIP_CONFIRM_TOKEN];

test("strip: dry run by default; apply needs the strip token, never the copy token", () => {
  assert.notEqual(STRIP_CONFIRM_TOKEN, CONFIRM_TOKEN);
  const dry = run(stripArgs);
  assert.equal(dry.mode, "dry-run");
  assert.equal(dry.config.strip, true);
  const apply = run(stripApplyArgs);
  assert.equal(apply.mode, "apply");
  assert.equal(apply.config.strip, true);
  assert.equal(run(applyArgs).config.strip, false);
  for (const argv of [
    [...stripArgs, "--apply"],
    [...stripArgs, "--apply", "--confirm", CONFIRM_TOKEN],
    [...applyArgs.slice(0, 3), "--confirm", STRIP_CONFIRM_TOKEN],
    [...stripApplyArgs, "--dry-run"],
    ["--strip-legacy=1", ...dryRunArgs],
    ["--strip-legacy", "--apply", "--confirm", STRIP_CONFIRM_TOKEN],
    ["--project", "rafiq-academy", "--strip-legacy"],
  ]) {
    const result = run(argv);
    assert.equal(result.mode, null, JSON.stringify(argv));
    assert.ok(result.problems.length > 0);
  }
  assert.equal(run(stripArgs, {}).mode, null, "strip needs the same pinned emulator environment");
  assert.deepEqual(checkInvocation({ argv: ["--strip-legacy"], env: {} }).mode, "plan");
});

test("strip decision: only an empty legacy key or a well-formed canonical doc allows removal", () => {
  const legacy = (raw) => classifyLegacy(raw === undefined ? {} : { meetingLink: raw }, meetingLinkIssue);
  const good = classifyCanonical({ meetingLink: LINK_A, updatedAt: TS }, meetingLinkIssue, isTs);
  const bad = classifyCanonical({ meetingLink: LINK_A, updatedAt: TS, extra: 1 }, meetingLinkIssue, isTs);
  assert.equal(decideStrip(legacy(undefined), null), "noLegacy");
  assert.equal(decideStrip(legacy(undefined), good), "noLegacy");
  assert.equal(decideStrip(legacy(""), null), "strip");
  assert.equal(decideStrip(legacy("   "), null), "strip");
  assert.equal(decideStrip(legacy(LINK_A), null), "needsCopy");
  assert.equal(decideStrip(legacy(PADDED), null), "needsCopy");
  assert.equal(decideStrip(legacy(INVALID.not_https), null), "invalidLegacy");
  assert.equal(decideStrip(legacy(42), null), "invalidLegacy");
  for (const raw of ["", LINK_A, LINK_B, INVALID.not_https, 42]) {
    assert.equal(decideStrip(legacy(raw), good), "strip", JSON.stringify(raw).slice(0, 12));
    assert.equal(decideStrip(legacy(raw), bad), "canonicalMalformed");
  }
});

function memoryStripper(collections, { failIds = new Set(), before = null } = {}) {
  return {
    stripOne: async (id) => {
      if (before) before(id);
      if (failIds.has(id)) throw Object.assign(new Error(`strip failed for ${LINK_A}`), { code: 10 });
      const halaqa = collections.halaqat.get(id);
      if (!halaqa) return "halaqaGone";
      const link = collections.halaqaMeetingLinks.get(id);
      const canonical = link ? classifyCanonical(link, meetingLinkIssue, isTs) : null;
      const decision = decideStrip(classifyLegacy(halaqa, meetingLinkIssue), canonical);
      if (decision !== "strip") return decision;
      delete halaqa.meetingLink;
      return "stripped";
    },
  };
}

const legacyKeys = (data) => [...data.halaqat].filter(([, h]) => Object.hasOwn(h, "meetingLink")).map(([id]) => id).sort();

test("strip dry run counts and writes nothing", async () => {
  const data = fixture();
  const before = JSON.stringify([...data.halaqat]);
  const report = await runLegacyStrip({
    store: memoryStore(data),
    mode: "dry-run",
    issueOf: meetingLinkIssue,
    isTimestamp: isTs,
    pageSize: 3,
  });
  assert.equal(JSON.stringify([...data.halaqat]), before);
  assert.equal(report.operation, "strip-legacy");
  const h = report.halaqat;
  assert.equal(h.scanned, 17);
  assert.equal(h.legacyPresent, 16);
  // hEmpty, hSame, hConflict, hMirror
  assert.equal(h.strippable, 4);
  assert.equal(h.wouldStrip, 4);
  assert.equal(h.stripped, 0);
  assert.deepEqual(h.kept, { needsCopy: 2, invalidLegacy: 9, canonicalMalformed: 1 });
  assert.deepEqual(report.review.needsCopyIds.ids, ["hPadded", "hValid"]);
  assert.deepEqual(report.review.canonicalMalformedIds.ids, ["hMalformed"]);
  assert.equal(report.review.invalidLegacyIds.total, 9);
  // hConflict's legacy value differs from its canonical link: lost on strip.
  assert.equal(h.supersededLegacy, 1);
  assert.deepEqual(report.review.supersededLegacyIds.ids, ["hConflict"]);
  assert.equal(report.summary.legacyKeysRemaining, 16);
  assert.equal(report.summary.needsReview, true);
  assert.equal(report.summary.exitCode, 0);
  assertRedacted(JSON.stringify(report), "strip dry-run report");
  await assert.rejects(
    runLegacyStrip({ store: memoryStore(data), mode: "apply", issueOf: meetingLinkIssue, isTimestamp: isTs }),
    /apply needs a stripper/,
  );
});

test("strip apply removes only eligible keys, never touches canonical docs; copy then strip leaves only review items", async () => {
  const data = fixture();
  const canonicalBefore = JSON.stringify([...data.halaqaMeetingLinks]);
  const opts = { mode: "apply", issueOf: meetingLinkIssue, isTimestamp: isTs, pageSize: 4 };
  const first = await runLegacyStrip({ ...opts, store: memoryStore(data), stripper: memoryStripper(data) });
  assert.equal(first.halaqat.stripped, 4);
  assert.equal(JSON.stringify([...data.halaqaMeetingLinks]), canonicalBefore);
  for (const id of ["hEmpty", "hSame", "hConflict", "hMirror"]) assert.equal(Object.hasOwn(data.halaqat.get(id), "meetingLink"), false, id);
  assert.equal(data.halaqat.get("hValid").meetingLink, LINK_A, "an uncopied link is kept");
  assert.equal(data.halaqat.get("hMalformed").meetingLink, LINK_A);
  assert.equal(first.summary.legacyKeysRemaining, 12);

  const again = await runLegacyStrip({ ...opts, store: memoryStore(data), stripper: memoryStripper(data) });
  assert.equal(again.halaqat.stripped, 0);
  assert.equal(again.halaqat.strippable, 0);

  await runMeetingLinkMigration({ ...opts, store: memoryStore(data), writer: memoryWriter(data) });
  const afterCopy = await runLegacyStrip({ ...opts, store: memoryStore(data), stripper: memoryStripper(data) });
  assert.equal(afterCopy.halaqat.stripped, 2);
  assert.deepEqual(legacyKeys(data), ["hMalformed", "hNonString", ...Object.keys(INVALID).map((r) => `hInv_${r}`)].sort());
  assertRedacted(JSON.stringify([first, again, afterCopy]), "strip apply reports");
});

test("strip apply: changes between scan and transaction are reported, failures counted, exit code 4", async () => {
  const data = fixture();
  const stripper = memoryStripper(data, {
    failIds: new Set(["hConflict"]),
    before: (id) => {
      if (id === "hEmpty") data.halaqat.delete("hEmpty");
      if (id === "hSame") data.halaqaMeetingLinks.set("hSame", { meetingLink: LINK_A, updatedAt: "not-a-ts" });
      if (id === "hMirror") delete data.halaqat.get("hMirror").meetingLink;
    },
  });
  const report = await runLegacyStrip({ store: memoryStore(data), stripper, mode: "apply", issueOf: meetingLinkIssue, isTimestamp: isTs });
  assert.equal(report.halaqat.stripped, 0);
  assert.equal(report.halaqat.changedDuringRun.halaqaGone, 1);
  assert.equal(report.halaqat.changedDuringRun.canonicalMalformed, 1);
  assert.equal(report.halaqat.changedDuringRun.noLegacy, 1);
  assert.deepEqual(report.review.changedDuringRunIds.ids.sort(), ["hEmpty", "hMirror", "hSame"]);
  assert.deepEqual(report.failures, { total: 1, byCode: { aborted: 1 } });
  assert.deepEqual(report.review.failedIds.ids, ["hConflict"]);
  assert.equal(data.halaqat.get("hSame").meetingLink, LINK_A);
  assert.equal(report.summary.exitCode, 4);
  assertRedacted(JSON.stringify(report), "strip race report");
});

// ── source contracts ───────────────────────────────────────────────────────

const read = (...parts) => readFileSync(join(functionsDir, ...parts), "utf8");

test("canonical writers never store a link on the halaqa and delete a legacy copy in the same transaction", () => {
  const links = read("src", "halaqa", "meetingLinkFunctions.ts");
  const core = links.slice(links.indexOf("export async function setHalaqaMeetingLinkCore"));
  assert.match(core, /await tx\.getAll\(halaqaRef, linkRef\)/);
  assert.match(core, /tx\.delete\(linkRef\)/);
  assert.match(core, /tx\.set\(linkRef, canonicalMeetingLinkData\(request\.link\)\)/);
  assert.match(core, /if \(stored\.legacyPresent\) \{\s*tx\.update\(halaqaRef, \{\s*meetingLink: FieldValue\.delete\(\),/);
  assert.doesNotMatch(links, /meetingLink: request\.link/);

  const create = read("src", "halaqa", "halaqaScheduleFunctions.ts");
  const halaqaCreate = create.match(/tx\.create\(halaqaRef, \{[\s\S]*?\}\);/)?.[0];
  assert.ok(halaqaCreate, "adminCreateHalaqa creates the halaqa in its transaction");
  assert.doesNotMatch(halaqaCreate, /meetingLink/);
  assert.match(create, /tx\.set\(linkRef, canonicalMeetingLinkData\(meetingLink\)\)/);
  assert.match(create, /tx\.delete\(linkRef\)/);

  const writers = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith(".ts")) {
        const text = readFileSync(path, "utf8");
        if (/HALAQA_MEETING_LINKS_COLLECTION|["']halaqaMeetingLinks["']/.test(text)) {
          writers.push(path.slice(join(functionsDir, "src").length + 1).replaceAll("\\", "/"));
        }
      }
    }
  };
  walk(join(functionsDir, "src"));
  assert.deepEqual(writers.sort(), ["halaqa/halaqaScheduleFunctions.ts", "halaqa/meetingLinkFunctions.ts"]);
});

test("the script uses the compiled B14 validator and has exactly one copy write and one strip write", () => {
  const source = read("scripts", "migrate-meeting-links.mjs");
  assert.match(source, /join\(here, "\.\.", "lib", "halaqa", "meetingLinkFunctions\.js"\)/);
  for (const copied of ["PRINTABLE_ASCII", "HOST_LABEL", "WHITESPACE_OR_CONTROL", "googleapis"]) {
    assert.equal(source.includes(copied), false, copied);
  }
  assert.equal(source.match(/tx\.create\(/g)?.length, 1);
  assert.equal(source.match(/tx\.update\(/g)?.length, 1);
  assert.match(source, /tx\.update\(halaqaRef, \{ meetingLink: deleteField\(\) \}\)/);
  assert.doesNotMatch(source, /tx\.(set|delete)\(|\.batch\(|(?<!\btx)\.(set|update|delete)\(\s*(linkRef|halaqaRef|doc)/);
  assert.doesNotMatch(source, /console\.(log|error)\([^)]*\b(raw|legacy\.value|link|meetingLink|data)\b/);
});

// ── CLI refusals (child processes, firebase-admin forbidden) ───────────────

function cleanEnv(extra) {
  const env = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (/(_EMULATOR_HOST|_EMULATOR_HUB)$|^(FIREBASE_|GOOGLE_|GCLOUD_|GCP_|CLOUDSDK_|MEETING_LINK_|B14_)|^NODE_OPTIONS$/i.test(key)) continue;
    env[key] = value;
  }
  return { ...env, ...extra };
}

function runCli(args, extraEnv, { noAdmin = true, ports = "" } = {}) {
  return new Promise((resolveRun) => {
    const child = spawn(process.execPath, ["--import", PRELOAD, SCRIPT, ...args], {
      cwd: functionsDir,
      env: cleanEnv({
        ...extraEnv,
        B14_MIGRATION_PRELOAD_PORTS: ports,
        ...(noAdmin ? { B14_MIGRATION_PRELOAD_NO_ADMIN: "1" } : {}),
      }),
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.on("close", (code) => resolveRun({ code, stdout, stderr }));
  });
}

test("CLI: plan mode prints the scope and never loads firebase-admin", async () => {
  const { code, stdout, stderr } = await runCli([], {});
  assert.equal(code, 0, stderr);
  const plan = JSON.parse(stdout);
  assert.equal(plan.mode, "plan");
  assert.equal(plan.connects, false);
  assert.equal(stderr.includes("firebase-admin load attempted"), false);
  assert.equal(stderr.includes("egress blocked"), false);
});

test("CLI: real projects and misdirected emulator settings are refused before the SDK loads", async () => {
  const runs = [
    ["--project", "rafiq-academy"],
    ["--project", "rafiq-academy-staging", "--apply", "--confirm", "meeting-link-migration:rafiq-academy-staging"],
    ["--project", "rafiq-academy-prod"],
    ["--project", "zz-hidden-project-91"],
  ];
  for (const args of runs) {
    const result = await runCli(args, validEnv());
    assert.equal(result.code, 2, args.join(" "));
    assert.match(result.stderr, /refused:/);
    assert.equal(result.stdout, "");
    assert.equal(result.stderr.includes("zz-hidden-project-91"), false);
    assert.equal(result.stderr.includes("firebase-admin load attempted"), false);
    assert.equal(result.stderr.includes("egress blocked"), false);
  }
  const remote = await runCli(dryRunArgs, { ...validEnv(), FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443" });
  assert.equal(remote.code, 2);
  assert.equal(remote.stderr.includes("googleapis"), false);
  assert.equal(remote.stderr.includes("firebase-admin load attempted"), false);
  const creds = await runCli(dryRunArgs, { ...validEnv(), GOOGLE_APPLICATION_CREDENTIALS: "C:\\keys\\zz-key.json" });
  assert.equal(creds.code, 2);
  assert.equal(creds.stderr.includes("zz-key"), false);
});

test("CLI: with no emulator on the pinned ports the run stops at the hub check, before the SDK", async () => {
  const env = {
    MEETING_LINK_MIGRATION_EMULATOR: "1",
    MEETING_LINK_MIGRATION_PORTS: "38991,38992",
    FIRESTORE_EMULATOR_HOST: "127.0.0.1:38991",
    FIREBASE_EMULATOR_HUB: "127.0.0.1:38992",
  };
  const result = await runCli(dryRunArgs, env, { ports: "38991,38992" });
  assert.equal(result.code, 2, result.stderr);
  assert.match(result.stderr, /refused: the emulator hub could not be reached\./);
  assert.equal(result.stderr.includes("firebase-admin load attempted"), false);
  assert.equal(result.stderr.includes("egress blocked"), false);
});

// ── test preload: blocks before connecting / loading, on this Node and the runtime ─

const PRELOAD_PROBE = `
  import net from "node:net";
  import dns from "node:dns";
  import { createRequire } from "node:module";
  const out = { node: process.version };
  try { await import("firebase-admin/app"); out.esm = "loaded"; } catch { out.esm = "refused"; }
  const req = createRequire(${JSON.stringify(pathToFileURL(join(functionsDir, "package.json")).href)});
  for (const name of ["firebase-admin", "@google-cloud/firestore", "google-auth-library"]) {
    try { req(name); out[name] = "loaded"; } catch { out[name] = "refused"; }
  }
  const server = net.createServer();
  let accepted = 0;
  server.on("connection", (s) => { accepted += 1; s.destroy(); });
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  const connect = (host, port) => new Promise((done) => {
    const s = net.connect(port, host);
    s.once("connect", () => { s.destroy(); done("connected"); });
    s.once("error", (e) => done(e.code ?? "error"));
    setTimeout(() => done("timeout"), 4000);
  });
  out.loopbackUnlisted = await connect("127.0.0.1", server.address().port);
  out.remote = await connect("203.0.113.10", 443);
  out.metadataIp = await connect("169.254.169.254", 80);
  out.metadataHost = await connect("metadata.google.internal", 80);
  out.dns = await new Promise((done) => dns.lookup("firestore.googleapis.com", (e) => done(e?.code ?? "resolved")));
  out.dnsPromises = await dns.promises.lookup("oauth2.googleapis.com").then(() => "resolved", (e) => e.code);
  out.fetch = await fetch("https://firestore.googleapis.com/").then(() => "resolved", (e) => e.cause?.code ?? "error");
  await new Promise((done) => setTimeout(done, 200));
  out.accepted = accepted;
  server.close();
  console.log(JSON.stringify(out));
`;

function runPreloadProbe(nodeBin, { noAdmin }) {
  return new Promise((resolveRun) => {
    const child = spawn(nodeBin, ["--import", PRELOAD, "--input-type=module", "-e", PRELOAD_PROBE], {
      cwd: functionsDir,
      env: cleanEnv({ B14_MIGRATION_PRELOAD_PORTS: "38996", ...(noAdmin ? { B14_MIGRATION_PRELOAD_NO_ADMIN: "1" } : {}) }),
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.on("close", (code) => resolveRun({ code, stdout, stderr }));
  });
}

async function assertPreloadBarrier(nodeBin) {
  const blocked = await runPreloadProbe(nodeBin, { noAdmin: true });
  assert.equal(blocked.code, 0, blocked.stderr);
  const out = JSON.parse(blocked.stdout.trim().split("\n").pop());
  assert.equal(out.esm, "refused", "ESM import of firebase-admin");
  assert.equal(out["firebase-admin"], "refused", "CommonJS require of firebase-admin");
  assert.equal(out["@google-cloud/firestore"], "refused");
  assert.equal(out["google-auth-library"], "refused");
  for (const key of ["loopbackUnlisted", "remote", "metadataIp", "metadataHost"]) {
    assert.equal(out[key], "B14_PRELOAD_BLOCKED", key);
  }
  assert.equal(out.dns, "B14_PRELOAD_BLOCKED");
  assert.equal(out.dnsPromises, "B14_PRELOAD_BLOCKED");
  assert.notEqual(out.fetch, "resolved");
  assert.equal(out.accepted, 0, "the blocked loopback connection never reached the listening server");
  assert.match(blocked.stderr, /preload: firebase-admin load attempted/);
  assert.match(blocked.stderr, /preload: egress blocked \d+ attempt\(s\)/);

  const control = await runPreloadProbe(nodeBin, { noAdmin: false });
  assert.equal(control.code, 0, control.stderr);
  const loaded = JSON.parse(control.stdout.trim().split("\n").pop());
  assert.equal(loaded.esm, "loaded", "without NO_ADMIN the same import succeeds, so the refusal above is the hook");
  assert.equal(loaded["firebase-admin"], "loaded");
  assert.equal(loaded.remote, "B14_PRELOAD_BLOCKED", "network barrier does not depend on NO_ADMIN");
  assert.equal(control.stderr.includes("firebase-admin load attempted"), false);
  return out.node;
}

test("preload (this Node): SDK loading and non-emulator connections are refused before they happen", async () => {
  const version = await assertPreloadBarrier(process.execPath);
  assert.equal(version, process.version);
});

const RUNTIME_MAJOR = JSON.parse(readFileSync(join(functionsDir, "package.json"), "utf8")).engines.node;

test(`preload on the Functions runtime, Node ${RUNTIME_MAJOR} (B14_RUNTIME_NODE_BIN)`, async (t) => {
  const bin = process.version.startsWith(`v${RUNTIME_MAJOR}.`)
    ? process.execPath
    : process.env.B14_RUNTIME_NODE_BIN;
  if (!bin) {
    t.skip(`Node ${RUNTIME_MAJOR} not available: set B14_RUNTIME_NODE_BIN to a Node ${RUNTIME_MAJOR} executable`);
    return;
  }
  const version = await assertPreloadBarrier(bin);
  assert.match(version, new RegExp(`^v${RUNTIME_MAJOR}\\.`));
});

// ── egress proof: the guard stops the real SDK from reaching Google ────────

test("egress guard: firebase-admin with a non-emulator project and credential cannot reach the network", async () => {
  const probe = `
    import net from "node:net";
    import { generateKeyPairSync } from "node:crypto";
    process.env.METADATA_SERVER_DETECTION = "none";
    const { startEgressGuard } = await import(${JSON.stringify(pathToFileURL(SCRIPT).href)});
    const guard = await startEgressGuard([38993]);
    if (!guard) { console.log(JSON.stringify({ guard: false })); process.exit(0); }
    const { privateKey } = generateKeyPairSync("rsa", {
      modulusLength: 2048,
      privateKeyEncoding: { type: "pkcs8", format: "pem" },
      publicKeyEncoding: { type: "spki", format: "pem" },
    });
    const { initializeApp, cert } = await import("firebase-admin/app");
    const { getFirestore } = await import("firebase-admin/firestore");
    const projectId = "b14-egress-probe-not-real";
    const app = initializeApp({ projectId, credential: cert({ projectId, clientEmail: "probe@" + projectId + ".iam.gserviceaccount.com", privateKey }) }, "probe");
    let sdk = "resolved";
    try {
      await Promise.race([
        getFirestore(app).collection("probe").doc("probe").get(),
        new Promise((_, reject) => setTimeout(() => reject(Object.assign(new Error("t"), { code: "probe-timeout" })), 20000)),
      ]);
    } catch (error) { sdk = "rejected"; }
    let fetched = "resolved";
    try { await fetch("https://firestore.googleapis.com/"); } catch { fetched = "rejected"; }
    const socket = await new Promise((done) => {
      const s = net.connect(443, "203.0.113.10");
      s.once("connect", () => { s.destroy(); done("connected"); });
      s.once("error", (e) => done(e?.code === "SEED_EGRESS_BLOCKED" ? "blocked" : "error"));
      setTimeout(() => done("timeout"), 5000);
    });
    const attempts = guard.blockedAttempts();
    console.log(JSON.stringify({
      guard: true, sdk, fetched, socket,
      blocked: attempts.length,
      google: attempts.filter((a) => /googleapis\\.com$/.test(a.host ?? "")).length,
    }));
    process.exit(0);
  `;
  const result = await new Promise((resolveRun) => {
    const child = spawn(process.execPath, ["--input-type=module", "-e", probe], { cwd: functionsDir, env: cleanEnv({}) });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.on("close", (code) => resolveRun({ code, stdout, stderr }));
  });
  assert.equal(result.code, 0, result.stderr);
  const outcome = JSON.parse(result.stdout.trim().split("\n").pop());
  assert.equal(outcome.guard, true);
  assert.equal(outcome.sdk, "rejected", "the SDK call must fail");
  assert.equal(outcome.fetched, "rejected");
  assert.equal(outcome.socket, "blocked");
  assert.ok(outcome.google >= 1, "a googleapis.com connection was attempted and blocked");
  assert.ok(outcome.blocked >= 3);
});
