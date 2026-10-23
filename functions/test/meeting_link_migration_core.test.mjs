/**
 * B14 meeting-link migration core — pure unit tests. No emulator, no network,
 * no firebase-admin: the core is plain data in, plain data out. Link
 * classification uses the compiled B14 validator (build functions first).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

import {
  APPROVED_INTERVENING_ACTION_PROOFS,
  CANDIDATE_OUTCOMES,
  CANONICAL_SCHEMA_VERSION,
  MIGRATION_ID,
  OBSERVATION_MAX_DELAY_MS,
  OUTCOME_CLASSES,
  PLAN_TTL_MS,
  PlanInputError,
  RECORD_CATEGORIES,
  RECORD_SCHEMA_VERSION,
  REVIEW_CATEGORIES,
  RUN_STATES,
  TERMINAL_STATES,
  VERSION_COMPONENTS,
  abandonConfirmationToken,
  applyEvidencePaths,
  buildMigrationPlan,
  canonicalJson,
  checkTransactionalEvidence,
  classifyCanonical,
  classifyErrorCode,
  classifyLegacy,
  classifyRecord,
  completionVerdict,
  computePlanDigest,
  connectionTargetProblem,
  decideCandidateWrite,
  decideLockAcquisition,
  decideLockRelease,
  decideRollbackDelete,
  detectPlanDrift,
  isCleanCompletion,
  isValidatedPlan,
  lockPaths,
  manifestEntryFields,
  nextGenerationToTry,
  observedRecordFields,
  openPlan,
  orphanPlanRecord,
  outcomeRecordFields,
  planRecordFromScan,
  releaseGateDecision,
  resolveUncertainCommit,
  rollbackEvidence,
  rollbackEvidencePaths,
  runPaths,
  sha256Hex,
  summarizeRun,
  timeKey,
  transitionRun,
  validateOutcomeRecord,
  validatePlan,
} from "../scripts/meeting-link-migration-core.mjs";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const { meetingLinkIssue } = require("../lib/halaqa/meetingLinkFunctions.js");
const isTimestamp = (v) => timeKey(v) !== null;

const MARK = "zqcoremark";
const LINK_A = `https://meet.example.test/${MARK}-a`;
const LINK_B = `https://video.example.org/j/${MARK}-b`;
const PADDED = `  ${LINK_A}  `;
const FORBIDDEN = [MARK, "://", "example.test", "example.org"];
function assertNoLinks(value, label) {
  const text = typeof value === "string" ? value : JSON.stringify(value);
  for (const needle of FORBIDDEN) assert.equal(text.includes(needle), false, `${label} contains ${needle}`);
}

const T = (seconds, nanoseconds = 0) => ({ seconds, nanoseconds });
const hex = (c) => c.repeat(64);
const IDENTITY = { projectId: "demo-rafiq-rules", databaseId: "(default)", migrationId: MIGRATION_ID };
const CONNECTION = { projectId: IDENTITY.projectId, databaseId: IDENTITY.databaseId };
const VERSIONS = { entryPoint: hex("a"), core: hex("b"), adapter: hex("c"), validator: hex("d"), canonicalSchema: CANONICAL_SCHEMA_VERSION };
const ISSUED = 1_800_000_000_000;
const NOW = ISSUED + 1000;

function scan(halaqaId, legacyData, canonicalData, halaqaTime = T(100), canonicalTime = canonicalData ? T(200) : null) {
  return planRecordFromScan({
    halaqaId,
    legacy: classifyLegacy(legacyData, meetingLinkIssue),
    canonical: canonicalData ? classifyCanonical(canonicalData, meetingLinkIssue, isTimestamp) : null,
    halaqaUpdateTime: halaqaTime,
    canonicalUpdateTime: canonicalTime,
  });
}

function fixtureRecords() {
  return [
    scan("hValid", { meetingLink: LINK_A }, null),
    scan("hPadded", { meetingLink: PADDED }, null),
    scan("hMissing", {}, null),
    scan("hEmpty", { meetingLink: "  " }, null),
    scan("hInvalid", { meetingLink: `http://meet.example.test/${MARK}` }, null),
    scan("hNonString", { meetingLink: 7 }, null),
    scan("hSame", { meetingLink: LINK_A }, { meetingLink: LINK_A, updatedAt: T(5) }),
    scan("hConflict", { meetingLink: LINK_A }, { meetingLink: LINK_B, updatedAt: T(5) }),
    scan("hMalformed", { meetingLink: LINK_A }, { meetingLink: ` ${LINK_A}`, updatedAt: T(5) }),
    scan("hMirror", { meetingLink: "" }, { meetingLink: LINK_B, updatedAt: T(5) }),
    orphanPlanRecord({ halaqaId: "hOrphan", canonicalUpdateTime: T(300) }),
  ];
}
const plan = (overrides = {}) =>
  buildMigrationPlan({ identity: IDENTITY, versions: VERSIONS, mode: "apply", issuedAt: ISSUED, records: fixtureRecords(), ...overrides });
const DIGEST = plan().digest;
const EXPECTED = { identity: IDENTITY, versions: VERSIONS, mode: "apply", approvedDigest: DIGEST };

function opened(raw = plan()) {
  const result = openPlan(raw, { expected: { ...EXPECTED, approvedDigest: raw.digest }, now: NOW });
  assert.equal(result.ok, true, JSON.stringify(result.problems));
  return result.plan;
}
const candidateOnlyPlan = () => opened(plan({ records: fixtureRecords().filter((r) => r.category === "candidate") }));

const RUN = "run-2026-test-01";
const RB = "rb-2026-test-01";
const applyWriter = (overrides = {}) => ({ kind: "apply", runId: RUN, generation: 2, planDigest: DIGEST, targetRunId: null, ...overrides });
const rollbackWriter = (overrides = {}) => ({ kind: "rollback", runId: RB, generation: 3, planDigest: DIGEST, targetRunId: RUN, ...overrides });
const lockDataFor = (writer) => ({
  generation: writer.generation,
  runId: writer.runId,
  kind: writer.kind,
  planDigest: writer.planDigest,
  targetRunId: writer.kind === "rollback" ? writer.targetRunId : null,
  schemaVersion: RECORD_SCHEMA_VERSION,
});

/** Read set keyed by role; an override of `undefined` drops that path. */
function readSetFor(paths, views, { connection = CONNECTION, transactionId = "tx-1", extra = {} } = {}) {
  const docs = {};
  for (const [role, path] of Object.entries(paths)) if (views[role] !== undefined) docs[path] = views[role];
  return { transactionId, connection, docs: { ...docs, ...extra } };
}
function applyReadSet({ writer = applyWriter(), halaqaId = "hValid", views = {}, options } = {}) {
  const base = {
    halaqa: { exists: true, updateTime: T(100) },
    canonical: { exists: false },
    lock: { exists: true, data: lockDataFor(writer) },
    release: { exists: false },
    stop: { exists: false },
  };
  return readSetFor(applyEvidencePaths({ writer, halaqaId }), { ...base, ...views }, options);
}

// ── classification ─────────────────────────────────────────────────────────

test("every record classification outcome; review categories are never candidates", () => {
  const byId = Object.fromEntries(fixtureRecords().map((r) => [r.halaqaId, r]));
  assert.deepEqual(
    Object.fromEntries(Object.entries(byId).map(([id, r]) => [id, [r.category, r.reason, r.trimRequired]])),
    {
      hValid: ["candidate", null, false],
      hPadded: ["candidate", null, true],
      hMissing: ["noLink", "missing", false],
      hEmpty: ["noLink", "empty", false],
      hInvalid: ["invalidLegacy", "not_https", false],
      hNonString: ["malformedLegacy", null, false],
      hSame: ["alreadyMigrated", null, false],
      hConflict: ["conflict", null, false],
      hMalformed: ["canonicalMalformed", "untrimmed", false],
      hMirror: ["canonicalWithoutValidLegacy", null, false],
      hOrphan: ["orphanCanonical", null, false],
    },
  );
  assert.deepEqual(new Set(Object.values(byId).map((r) => r.category)), new Set(RECORD_CATEGORIES));
  for (const category of REVIEW_CATEGORIES) assert.notEqual(category, "candidate");
  assert.equal(classifyRecord({ category: "invalid", reason: "credentials" }, null).category, "invalidLegacy");
  assert.equal(classifyRecord({ category: "valid", value: LINK_A }, { malformed: true, reason: "extra_keys" }).category, "canonicalMalformed");
  assertNoLinks(fixtureRecords(), "plan records");
});

// ── plan and digest ────────────────────────────────────────────────────────

test("plan generation is deterministic and independent of input order", () => {
  const a = plan();
  const b = plan({ records: fixtureRecords().reverse() });
  assert.deepEqual(a, b);
  assert.equal(a.digest, computePlanDigest(a));
  assert.match(a.digest, /^[0-9a-f]{64}$/);
  assert.deepEqual(a.records.map((r) => r.halaqaId), [...a.records.map((r) => r.halaqaId)].sort());
  assert.equal(a.expiresAt - a.issuedAt, PLAN_TTL_MS);
  assert.equal(a.counts.candidate, 2);
  assert.deepEqual(Object.keys(a.versions).sort(), [...VERSION_COMPONENTS, "canonicalSchema"].sort());
  assert.equal(canonicalJson({ b: 1, a: [2, { d: null, c: "x" }] }), '{"a":[2,{"c":"x","d":null}],"b":1}');
});

test("the digest changes when any execution-relevant reviewed input changes (B6: every version component)", () => {
  const base = plan();
  const variants = {
    projectId: plan({ identity: { ...IDENTITY, projectId: "demo-rafiq-other" } }),
    databaseId: plan({ identity: { ...IDENTITY, databaseId: "other-db" } }),
    ...Object.fromEntries(VERSION_COMPONENTS.map((c) => [c, plan({ versions: { ...VERSIONS, [c]: hex("e") } })])),
    issuedAt: plan({ issuedAt: ISSUED + 1 }),
    ttl: plan({ ttlMs: PLAN_TTL_MS - 1 }),
    halaqaUpdateTime: plan({ records: fixtureRecords().map((r) => (r.halaqaId === "hValid" ? { ...r, halaqaUpdateTime: "100.000000001" } : r)) }),
    canonicalUpdateTime: plan({ records: fixtureRecords().map((r) => (r.halaqaId === "hSame" ? { ...r, canonicalUpdateTime: "201.000000000" } : r)) }),
    trimRequired: plan({ records: fixtureRecords().map((r) => (r.halaqaId === "hValid" ? { ...r, trimRequired: true } : r)) }),
    reason: plan({ records: fixtureRecords().map((r) => (r.halaqaId === "hInvalid" ? { ...r, reason: "credentials" } : r)) }),
    category: plan({ records: fixtureRecords().map((r) => (r.halaqaId === "hConflict" ? { ...r, category: "alreadyMigrated" } : r)) }),
    removed: plan({ records: fixtureRecords().filter((r) => r.halaqaId !== "hMissing") }),
  };
  const digests = new Set([base.digest]);
  for (const [name, variant] of Object.entries(variants)) {
    assert.notEqual(variant.digest, base.digest, name);
    digests.add(variant.digest);
  }
  assert.equal(digests.size, Object.keys(variants).length + 1);
  for (const field of ["mode", "schemaVersion", "kind", "counts"]) {
    const tampered = { ...base, [field]: field === "counts" ? { ...base.counts, candidate: 3 } : "x" };
    assert.notEqual(computePlanDigest(tampered), base.digest, field);
  }
  assert.equal(sha256Hex("abc"), sha256Hex(Buffer.from("abc")));
  assert.match(sha256Hex("abc"), /^[0-9a-f]{64}$/);
});

test("plans and digest inputs never contain link values, even when the caller passes them", () => {
  const leaky = fixtureRecords().map((r) => ({ ...r, value: LINK_A, meetingLink: LINK_B }));
  const built = plan({ records: leaky });
  assert.deepEqual(built, plan());
  assertNoLinks(built, "plan");
  assertNoLinks(canonicalJson(built), "digest input");
});

test("plan inputs are validated before a plan exists", () => {
  const bad = (overrides, code) => assert.throws(() => plan(overrides), (e) => e instanceof PlanInputError && e.problems.includes(code), code);
  bad({ mode: "dry-run" }, "mode_unknown");
  bad({ ttlMs: PLAN_TTL_MS + 1 }, "ttl_invalid");
  bad({ issuedAt: 1.5 }, "issued_at_invalid");
  bad({ identity: { ...IDENTITY, migrationId: "other" } }, "identity_invalid:migrationId");
  bad({ versions: { ...VERSIONS, canonicalSchema: 2 } }, "versions_invalid:canonicalSchema");
  bad({ versions: { ...VERSIONS, adapter: "short" } }, "versions_invalid:adapter");
  const { adapter, ...withoutAdapter } = VERSIONS;
  assert.ok(adapter);
  bad({ versions: withoutAdapter }, "versions_invalid");
  bad({ versions: { script: hex("a"), validator: hex("b"), canonicalSchema: 1 } }, "versions_invalid");
  bad({ records: [...fixtureRecords(), scan("hValid", { meetingLink: LINK_A }, null)] }, "record_duplicate");
  bad({ records: [{ ...fixtureRecords()[0], halaqaUpdateTime: null }] }, "metadata_invalid");
  bad({ records: [{ ...fixtureRecords()[0], halaqaId: "a/b" }] }, "record_invalid");
});

test("A4 validation: the approved digest is a required input; schema, versions, identity, mode, digest and expiry are enforced", () => {
  const good = plan();
  assert.deepEqual(validatePlan(good, { expected: EXPECTED, now: NOW }), { ok: true, problems: [] });
  const problems = (p, opts = {}) => validatePlan(p, { expected: EXPECTED, now: NOW, ...opts }).problems;

  assert.deepEqual(problems(good, { expected: { ...EXPECTED, approvedDigest: undefined } }), ["approved_digest_missing"]);
  assert.deepEqual(problems(good, { expected: { ...EXPECTED, approvedDigest: "x" } }), ["approved_digest_missing"]);
  assert.deepEqual(problems(good, { expected: { ...EXPECTED, approvedDigest: hex("0") } }), ["approved_digest_mismatch"]);
  assert.ok(validatePlan(good).problems.includes("approved_digest_missing"));
  const recomputed = (p) => ({ ...p, digest: computePlanDigest(p) });
  const resealed = recomputed({ ...good, records: good.records.filter((r) => r.halaqaId !== "hMissing"), counts: { ...good.counts, noLink: 1 } });
  assert.deepEqual(problems(resealed), ["approved_digest_mismatch"], "a self-consistent but unapproved plan is rejected");

  assert.deepEqual(problems({ ...good, schemaVersion: 1 }), ["schema_version_mismatch"]);
  assert.deepEqual(problems({ ...good, kind: "other" }), ["kind_mismatch"]);
  assert.deepEqual(problems({ ...good, extra: 1 }), ["plan_fields_invalid"]);
  assert.deepEqual(problems(null), ["plan_not_object"]);
  assert.deepEqual(problems(good, { now: good.expiresAt }), ["expired"]);
  assert.deepEqual(problems(good, { now: ISSUED - 6 * 60 * 1000 }), ["issued_in_future"]);
  assert.ok(problems(good, { expected: { ...EXPECTED, mode: "rollback" } }).includes("mode_mismatch"));
  assert.ok(problems(good, { expected: { ...EXPECTED, identity: { ...IDENTITY, projectId: "rafiq-academy" } } }).includes("identity_mismatch:projectId"));
  assert.ok(problems(good, { expected: { ...EXPECTED, identity: { ...IDENTITY, databaseId: "other-db" } } }).includes("identity_mismatch:databaseId"));
  for (const component of VERSION_COMPONENTS) {
    assert.ok(problems(good, { expected: { ...EXPECTED, versions: { ...VERSIONS, [component]: hex("e") } } }).includes(`version_mismatch:${component}`));
  }

  assert.ok(problems({ ...good, digest: hex("0") }).includes("digest_mismatch"));
  assert.ok(problems({ ...good, counts: { ...good.counts, candidate: 9 } }).includes("digest_mismatch"));
  const sealed = (p) => problems(recomputed(p), { expected: { ...EXPECTED, approvedDigest: computePlanDigest(p) } });
  assert.deepEqual(sealed({ ...good, counts: { ...good.counts, candidate: 9 } }), ["counts_mismatch"]);
  assert.deepEqual(sealed({ ...good, expiresAt: ISSUED + PLAN_TTL_MS + 1 }), ["validity_window_invalid"]);
  assert.deepEqual(sealed({ ...good, records: [...good.records].reverse() }), ["records_not_sorted_unique"]);
  assert.deepEqual(sealed({ ...good, records: [{ ...good.records[0], category: "wat" }] }), ["category_unknown"]);
  assert.deepEqual(sealed({ ...good, records: [{ ...good.records[0], meetingLink: LINK_A }] }), ["record_invalid"]);
});

test("A5 openPlan: only a validated, immutable handle reaches write decisions", () => {
  const raw = plan();
  assert.deepEqual(openPlan(raw, { expected: { ...EXPECTED, approvedDigest: undefined }, now: NOW }), {
    ok: false,
    problems: ["approved_digest_missing"],
  });
  const handle = opened(raw);
  assert.equal(isValidatedPlan(handle), true);
  assert.equal(Object.isFrozen(handle) && Object.isFrozen(handle.identity) && Object.isFrozen(handle.versions), true);
  assert.equal("records" in handle, false);
  assert.equal(handle.digest, DIGEST);
  raw.records.find((r) => r.halaqaId === "hValid").halaqaUpdateTime = "999.000000000";
  const after = decideCandidateWrite({ validatedPlan: handle, halaqaId: "hValid", now: NOW, writer: applyWriter(), readSet: applyReadSet(), legacyCategory: "valid" });
  assert.equal(after.write, true, "mutating the source plan after opening does not change the handle");
  for (const forged of [{ ...handle }, plan(), structuredClone(handle), null]) assert.equal(isValidatedPlan(forged), false);
});

// ── drift ──────────────────────────────────────────────────────────────────

test("drift: unchanged data is clean; a moved candidate is changedSinceReview without replanning", () => {
  const reviewed = plan();
  assert.deepEqual(detectPlanDrift(reviewed, fixtureRecords()), {
    replanRequired: false,
    reasons: [],
    changedSinceReview: [],
    metadataChangedNonCandidate: 0,
  });
  const moved = fixtureRecords().map((r) => {
    if (r.halaqaId === "hValid") return { ...r, halaqaUpdateTime: "101.000000000" };
    if (r.halaqaId === "hMissing") return { ...r, halaqaUpdateTime: "101.000000000" };
    return r;
  });
  const drift = detectPlanDrift(reviewed, moved);
  assert.equal(drift.replanRequired, false);
  assert.deepEqual(drift.changedSinceReview, ["hValid"]);
  assert.equal(drift.metadataChangedNonCandidate, 1);
});

test("drift: category changes, added and removed records require a new dry run", () => {
  const reviewed = plan();
  const appeared = fixtureRecords().map((r) =>
    r.halaqaId === "hValid" ? scan("hValid", { meetingLink: LINK_A }, { meetingLink: LINK_A, updatedAt: T(9) }) : r,
  );
  assert.deepEqual(detectPlanDrift(reviewed, appeared).reasons, ["category_changed", "counts_changed"]);
  assert.deepEqual(detectPlanDrift(reviewed, [...fixtureRecords(), scan("hNew", { meetingLink: LINK_B }, null)]).reasons, [
    "counts_changed",
    "record_added",
  ]);
  assert.deepEqual(detectPlanDrift(reviewed, fixtureRecords().filter((r) => r.halaqaId !== "hEmpty")).reasons, [
    "counts_changed",
    "record_removed",
  ]);
});

// ── in-transaction write decision ──────────────────────────────────────────

test("A5/A6 write decision: candidate looked up in the validated plan, expiry checked per write, read set decides", () => {
  const handle = opened();
  const d = (overrides = {}) =>
    decideCandidateWrite({
      validatedPlan: handle,
      halaqaId: "hValid",
      now: NOW,
      writer: applyWriter(),
      readSet: applyReadSet(),
      legacyCategory: "valid",
      ...overrides,
    });
  const ok = d();
  assert.equal(ok.write, true);
  assert.equal(ok.outcomeIfCommitted, "migrated");
  assert.deepEqual(ok.manifestEntry, {
    halaqaId: "hValid",
    runId: RUN,
    planDigest: DIGEST,
    lockGeneration: 2,
    priorCanonical: "absent",
    legacyTrimmed: false,
    schemaVersion: RECORD_SCHEMA_VERSION,
  });
  assert.equal(d({ halaqaId: "hPadded", readSet: applyReadSet({ halaqaId: "hPadded" }) }).manifestEntry.legacyTrimmed, true);
  assertNoLinks(ok, "write decision");

  const cases = [
    ["forged handle", { validatedPlan: { ...handle } }, "rejected", "plan_not_validated"],
    ["raw plan", { validatedPlan: plan() }, "rejected", "plan_not_validated"],
    ["arbitrary record object", { validatedPlan: { category: "candidate", halaqaUpdateTime: "100.000000000" } }, "rejected", "plan_not_validated"],
    ["unknown halaqa", { halaqaId: "hUnknown", readSet: applyReadSet({ halaqaId: "hUnknown" }) }, "rejected", "candidate_not_in_plan"],
    ["non-candidate", { halaqaId: "hSame", readSet: applyReadSet({ halaqaId: "hSame" }) }, "rejected", "not_a_candidate"],
    ["invalid id", { halaqaId: "a/b" }, "rejected", "halaqa_id_invalid"],
    ["writer bound to another plan", { writer: applyWriter({ planDigest: hex("f") }) }, "rejected", "plan_digest_mismatch"],
    ["rollback writer", { writer: rollbackWriter() }, "rejected", "writer_kind_mismatch"],
    ["missing writer", { writer: undefined }, "rejected", "writer_invalid"],
    ["now missing", { now: undefined }, "rejected", "now_invalid"],
    ["expired at boundary", { now: handle.expiresAt }, "planExpired", "expired"],
    ["expired later", { now: handle.expiresAt + 1 }, "planExpired", "expired"],
    ["clock far behind", { now: ISSUED - 6 * 60 * 1000 }, "planExpired", "issued_in_future"],
    ["halaqa gone", { readSet: applyReadSet({ views: { halaqa: { exists: false } } }) }, "halaqaGone", null],
    ["canonical appeared", { readSet: applyReadSet({ views: { canonical: { exists: true } } }) }, "canonicalAppeared", null],
    ["source moved", { readSet: applyReadSet({ views: { halaqa: { exists: true, updateTime: T(100, 1) } } }) }, "changedSinceReview", null],
    ["source metadata missing", { readSet: applyReadSet({ views: { halaqa: { exists: true, updateTime: null } } }) }, "metadataUnavailable", null],
    ["legacy emptied", { legacyCategory: "empty" }, "legacyNoLongerValid", "empty"],
    ["legacy category unknown", { legacyCategory: "write" }, "rejected", "legacy_category_invalid"],
  ];
  for (const [label, overrides, outcome, reason] of cases) {
    assert.deepEqual(d(overrides), { write: false, outcome, reason }, label);
    assert.ok(Object.hasOwn(CANDIDATE_OUTCOMES, outcome), `${label}: outcome is in the vocabulary`);
  }
  assert.equal(d({ now: handle.expiresAt - 1 }).write, true, "expiry is evaluated at each write, not once at open");
});

test("B2/B3/A8/B7 evidence and fencing: exact paths, own stop doc, lock kind/owner/generation/plan, connection target", () => {
  const handle = opened();
  const decide = (readSet, writer = applyWriter()) =>
    decideCandidateWrite({ validatedPlan: handle, halaqaId: "hValid", now: NOW, writer, readSet, legacyCategory: "valid" });
  const result = (readSet, writer) => {
    const r = decide(readSet, writer);
    return [r.outcome, r.reason];
  };
  const otherStop = runPaths("run-other-0001").stop;
  const paths = applyEvidencePaths({ writer: applyWriter(), halaqaId: "hValid" });
  const cases = [
    ["no read set", undefined, ["rejected", "missing_transactional_evidence"]],
    ["no transaction id", applyReadSet({ options: { transactionId: "" } }), ["rejected", "missing_transactional_evidence"]],
    ["own stop doc not read", applyReadSet({ views: { stop: undefined } }), ["rejected", "missing_transactional_evidence"]],
    ["lock not read", applyReadSet({ views: { lock: undefined } }), ["rejected", "missing_transactional_evidence"]],
    ["view without exists", applyReadSet({ views: { release: { data: null } } }), ["rejected", "missing_transactional_evidence"]],
    [
      "another run's stop doc instead of its own",
      applyReadSet({ views: { stop: undefined }, options: { extra: { [otherStop]: { exists: false } } } }),
      ["rejected", "unexpected_evidence"],
    ],
    ["extra doc", applyReadSet({ options: { extra: { "halaqat/hOther": { exists: true } } } }), ["rejected", "unexpected_evidence"]],
    ["no connection", applyReadSet({ options: { connection: null } }), ["rejected", "connection_target_unknown"]],
    ["other project", applyReadSet({ options: { connection: { ...CONNECTION, projectId: "rafiq-academy" } } }), ["rejected", "connection_target_mismatch"]],
    ["other database", applyReadSet({ options: { connection: { ...CONNECTION, databaseId: "other-db" } } }), ["rejected", "connection_target_mismatch"]],
    ["lock missing", applyReadSet({ views: { lock: { exists: false } } }), ["fenced", "lock_missing"]],
    ["lock schema", applyReadSet({ views: { lock: { exists: true, data: { ...lockDataFor(applyWriter()), acquiredAt: 1 } } } }), ["fenced", "lock_schema_invalid"]],
    ["lock owner", applyReadSet({ views: { lock: { exists: true, data: { ...lockDataFor(applyWriter()), runId: "run-other-0001" } } } }), ["fenced", "lock_owner_mismatch"]],
    ["lock kind", applyReadSet({ views: { lock: { exists: true, data: { ...lockDataFor(applyWriter()), kind: "rollback" } } } }), ["fenced", "lock_kind_mismatch"]],
    ["stale worker", applyReadSet({ views: { lock: { exists: true, data: { ...lockDataFor(applyWriter()), generation: 3 } } } }), ["fenced", "stale_worker"]],
    ["lock plan", applyReadSet({ views: { lock: { exists: true, data: { ...lockDataFor(applyWriter()), planDigest: hex("f") } } } }), ["fenced", "lock_plan_mismatch"]],
    ["lock target", applyReadSet({ views: { lock: { exists: true, data: { ...lockDataFor(applyWriter()), targetRunId: RB } } } }), ["fenced", "lock_target_mismatch"]],
    ["released", applyReadSet({ views: { release: { exists: true } } }), ["fenced", "lock_released"]],
    ["own stop requested", applyReadSet({ views: { stop: { exists: true } } }), ["fenced", "stop_requested"]],
  ];
  for (const [label, readSet, expected] of cases) assert.deepEqual(result(readSet), expected, label);

  const oldWorker = applyWriter({ generation: 1 });
  assert.deepEqual(result(applyReadSet({ writer: oldWorker, views: { release: { exists: true } } }), oldWorker), ["fenced", "lock_released"]);
  assert.equal(Object.values(paths).includes(runPaths(RUN).stop), true);
  assert.equal(connectionTargetProblem(IDENTITY, CONNECTION), null);
  assert.equal(connectionTargetProblem(IDENTITY, { ...CONNECTION, extra: 1 }), "connection_target_unknown");
  assert.equal(
    checkTransactionalEvidence({ writer: applyWriter(), kind: "apply", readSet: applyReadSet(), paths, identity: IDENTITY }).status,
    "ok",
  );
});

// ── locks ──────────────────────────────────────────────────────────────────

test("B3 locks: create-only acquisition bound to kind, run claim and plan digest; no time inputs", () => {
  const handle = opened();
  const acquire = (overrides = {}) =>
    decideLockAcquisition({
      writer: applyWriter({ generation: 1 }),
      identity: IDENTITY,
      validatedPlan: handle,
      current: { exists: false },
      previousRelease: null,
      runClaim: { exists: false },
      ...overrides,
    });
  const ok = acquire();
  assert.equal(ok.acquire, true);
  assert.equal(ok.lockPath, lockPaths(1).lock);
  assert.equal(ok.runPath, runPaths(RUN).run);
  assert.deepEqual(ok.lockData, lockDataFor(applyWriter({ generation: 1 })));
  assert.deepEqual(ok.runData, {
    runId: RUN,
    kind: "apply",
    generation: 1,
    planDigest: DIGEST,
    targetRunId: null,
    projectId: IDENTITY.projectId,
    databaseId: IDENTITY.databaseId,
    schemaVersion: RECORD_SCHEMA_VERSION,
  });
  const reason = (overrides) => acquire(overrides).reason;
  assert.equal(reason({ current: { exists: true } }), "generation_taken");
  assert.equal(reason({ current: undefined }), "lock_state_unknown");
  assert.equal(reason({ writer: applyWriter({ generation: 2 }), previousRelease: { exists: false } }), "previous_generation_not_released");
  assert.equal(acquire({ writer: applyWriter({ generation: 2 }), previousRelease: { exists: true } }).acquire, true);
  assert.equal(reason({ runClaim: { exists: true } }), "run_id_reused");
  assert.equal(reason({ runClaim: undefined }), "run_state_unknown");
  assert.equal(reason({ validatedPlan: plan() }), "plan_not_validated");
  assert.equal(reason({ writer: applyWriter({ generation: 1, planDigest: hex("f") }) }), "plan_digest_mismatch");
  assert.equal(reason({ identity: { ...IDENTITY, projectId: "demo-rafiq-other" } }), "identity_mismatch");
  assert.equal(reason({ identity: { projectId: "x" } }), "identity_invalid");
  assert.equal(reason({ writer: applyWriter({ kind: "migrate" }) }), "writer_kind_invalid");
  assert.equal(reason({ writer: applyWriter({ runId: "Bad Id" }) }), "writer_run_id_invalid");
  assert.equal(reason({ writer: applyWriter({ targetRunId: RB }) }), "writer_target_invalid");
  assert.equal(
    reason({ writer: applyWriter({ generation: 2 }), previousRelease: { exists: false }, acquiredAt: T(1), now: Date.now(), heartbeatAgeMs: 1e12 }),
    "previous_generation_not_released",
    "age never releases a lock",
  );

  const targetRun = { exists: true, data: { ...ok.runData } };
  const rb = (overrides = {}) =>
    decideLockAcquisition({
      writer: rollbackWriter({ generation: 2 }),
      identity: IDENTITY,
      current: { exists: false },
      previousRelease: { exists: true },
      runClaim: { exists: false },
      targetRun,
      ...overrides,
    });
  assert.equal(rb().acquire, true);
  assert.equal(rb().lockData.kind, "rollback");
  assert.equal(rb().lockData.targetRunId, RUN);
  assert.equal(rb({ targetRun: { exists: false } }).reason, "rollback_target_missing");
  assert.equal(rb({ targetRun: { exists: true, data: { ...ok.runData, kind: "rollback" } } }).reason, "rollback_target_invalid");
  assert.equal(rb({ targetRun: { exists: true, data: { ...ok.runData, planDigest: hex("f") } } }).reason, "rollback_target_invalid");
  assert.equal(rb({ targetRun: { exists: true, data: { ...ok.runData, projectId: "demo-rafiq-other" } } }).reason, "rollback_target_invalid");
  assert.equal(rb({ writer: rollbackWriter({ targetRunId: RB }) }).reason, "writer_target_invalid");

  assert.deepEqual(nextGenerationToTry([]), { ok: true, generation: 1 });
  assert.deepEqual(nextGenerationToTry([{ generation: 1, released: true }, { generation: 2, released: false }]), {
    ok: false,
    reason: "lock_held",
    generation: 2,
  });
  assert.deepEqual(nextGenerationToTry([{ generation: 1, released: true }]), { ok: true, generation: 2 });
  assert.deepEqual(lockPaths(3), { lock: "migrationLocks/meeting-links-000003", release: "migrationLocks/meeting-links-000003/release/final" });
  assert.equal(runPaths(RUN).stop, `migrationRuns/${RUN}/control/stop`);
  assert.equal(runPaths(RUN).outcome("hValid"), `migrationRuns/${RUN}/outcomes/hValid`);
});

test("locks: only the owner releases; abandonment needs human confirmation and the exact token", () => {
  const lock = { exists: true, data: lockDataFor(applyWriter({ generation: 1 })) };
  const rel = (request, release = { exists: false }) => decideLockRelease({ lock, release, request });
  assert.equal(rel({ reason: "completed", runId: RUN }).release, true);
  assert.equal(rel({ reason: "completed", runId: "run-other-0001" }).reason, "not_lock_owner");
  assert.equal(rel({ reason: "completed", runId: RUN }, { exists: true }).reason, "already_released");
  assert.equal(rel({ reason: "expired", runId: RUN }).reason, "release_reason_invalid");
  assert.equal(rel({ reason: "operator_abandoned" }).reason, "human_confirmation_required");
  assert.equal(rel({ reason: "operator_abandoned", humanConfirmed: true, confirmation: "yes" }).reason, "human_confirmation_required");
  assert.equal(
    rel({ reason: "operator_abandoned", humanConfirmed: false, confirmation: abandonConfirmationToken(1, RUN) }).reason,
    "human_confirmation_required",
  );
  const abandoned = rel({ reason: "operator_abandoned", humanConfirmed: true, confirmation: abandonConfirmationToken(1, RUN) });
  assert.deepEqual(abandoned, { release: true, data: { generation: 1, lockRunId: RUN, reason: "operator_abandoned", schemaVersion: RECORD_SCHEMA_VERSION } });
  assert.equal(decideLockRelease({ lock: { exists: false }, release: { exists: false }, request: { reason: "completed", runId: RUN } }).reason, "lock_missing");
});

// ── ambiguous commits ──────────────────────────────────────────────────────

const ENTRY_TIME = T(500, 123456789);
const entryData = (overrides = {}) => ({
  ...manifestEntryFields({ runId: RUN, halaqaId: "hValid", planDigest: DIGEST, lockGeneration: 2, legacyTrimmed: false }),
  createdAt: T(500, 123000000),
  ...overrides,
});
const entryView = (overrides = {}) => ({ exists: true, data: entryData(), createTime: ENTRY_TIME, updateTime: ENTRY_TIME, ...overrides });
const canonicalDoc = (overrides = {}) => ({
  exists: true,
  createTime: ENTRY_TIME,
  updateTime: ENTRY_TIME,
  data: { meetingLink: LINK_A, updatedAt: T(500, 123000000) },
  ...overrides,
});

test("B5 ambiguous commit: verified, not proven, or contradictory — none authorizes a write or delete", () => {
  const r = (entry, canonical, writer = applyWriter()) => resolveUncertainCommit({ writer, halaqaId: "hValid", entry, canonical });
  const committed = r(entryView(), canonicalDoc());
  assert.deepEqual(committed, {
    outcome: "committedAfterAmbiguity",
    evidence: "committedVerified",
    reason: null,
    authorizesWrite: false,
    authorizesDelete: false,
    canonicalState: "presentUnmodified",
  });
  assert.equal(r(entryView(), { exists: false }).canonicalState, "absentAfterCommit");
  assert.equal(r(entryView(), canonicalDoc({ updateTime: T(600) })).canonicalState, "presentModified");
  assert.equal(r(entryView(), canonicalDoc({ data: { meetingLink: LINK_B, updatedAt: T(700) } })).canonicalState, "presentReplaced");

  const cases = [
    ["entry deleted, canonical present", { exists: false }, canonicalDoc(), "unresolved", "notProvenCommitted", "manifest_absent_canonical_present"],
    ["entry deleted, canonical absent", { exists: false }, { exists: false }, "unresolved", "notProvenCommitted", "manifest_absent_canonical_absent"],
    ["evidence missing", undefined, canonicalDoc(), "unresolved", "notProvenCommitted", "evidence_unavailable"],
    ["other run", entryView({ data: entryData({ runId: "run-other-0001" }) }), canonicalDoc(), "contradictory", "contradictory", "manifest_identity_mismatch"],
    ["other plan", entryView({ data: entryData({ planDigest: hex("f") }) }), canonicalDoc(), "contradictory", "contradictory", "manifest_plan_mismatch"],
    ["no plan digest", entryView({ data: (({ planDigest, ...rest }) => (assert.ok(planDigest), rest))(entryData()) }), canonicalDoc(), "contradictory", "contradictory", "manifest_schema_invalid"],
    ["other generation", entryView({ data: entryData({ lockGeneration: 1 }) }), canonicalDoc(), "contradictory", "contradictory", "manifest_generation_mismatch"],
    ["canonical older than entry", entryView(), canonicalDoc({ createTime: T(400), updateTime: T(400) }), "contradictory", "contradictory", "canonical_predates_manifest"],
  ];
  for (const [label, entry, canonical, outcome, evidence, reason] of cases) {
    const result = r(entry, canonical);
    assert.deepEqual([result.outcome, result.evidence, result.reason], [outcome, evidence, reason], label);
    assert.equal(result.authorizesWrite, false, label);
    assert.equal(result.authorizesDelete, false, label);
    assert.ok(Object.hasOwn(CANDIDATE_OUTCOMES, result.outcome), label);
    assertNoLinks(result, label);
  }
  assert.equal(r({ exists: false }, { exists: false }).action, "replan");
});

test("error codes: authorization is fatal, unknown outcomes are ambiguous", () => {
  assert.equal(classifyErrorCode("permission-denied"), "fatalAuthorization");
  assert.equal(classifyErrorCode("unauthenticated"), "fatalAuthorization");
  assert.equal(classifyErrorCode("aborted"), "transient");
  assert.equal(classifyErrorCode("failed-precondition"), "precondition");
  for (const code of ["deadline-exceeded", "unavailable", "internal", "unknown", "already-exists", undefined]) {
    assert.equal(classifyErrorCode(code), "ambiguous", String(code));
  }
});

// ── rollback ───────────────────────────────────────────────────────────────

const observedData = () => observedRecordFields({ runId: RUN, halaqaId: "hValid", canonical: canonicalDoc() });
const observedView = (overrides = {}) => ({ exists: true, data: observedData(), createTime: T(510), updateTime: T(510), ...overrides });
const evidenceViews = (overrides = {}) => ({
  entry: entryView(),
  observed: observedView(),
  canonical: canonicalDoc(),
  rollbackRecord: { exists: false },
  ...overrides,
});
const evidence = (overrides = {}, options = {}) =>
  rollbackEvidence({ targetRunId: RUN, planDigest: DIGEST, halaqaId: "hValid", ...evidenceViews(overrides), ...options });

function rollbackReadSet({ writer = rollbackWriter(), views = {}, options } = {}) {
  const base = {
    ...evidenceViews(),
    lock: { exists: true, data: lockDataFor(writer) },
    release: { exists: false },
    stop: { exists: false },
  };
  return readSetFor(rollbackEvidencePaths({ writer, halaqaId: "hValid" }), { ...base, ...views }, options);
}

test("A1/B4 rollback evidence: metadata, incarnation and a timely observation are all required", () => {
  assert.deepEqual(evidence(), { complete: true, reason: null });
  assert.deepEqual(Object.keys(observedData()).sort(), ["canonicalCreateTime", "canonicalUpdateTime", "halaqaId", "runId", "schemaVersion"]);
  assertNoLinks(observedData(), "observed record");
  assertNoLinks(entryData(), "manifest entry");
  assert.equal(observedRecordFields({ runId: RUN, halaqaId: "hValid", canonical: { exists: false } }), null);
  assert.equal(observedRecordFields({ runId: RUN, halaqaId: "hValid", canonical: canonicalDoc({ createTime: null }) }), null);

  const cases = {
    evidence_invalid: { rollbackRecord: undefined },
    manifest_missing: { entry: { exists: false } },
    manifest_schema_invalid: { entry: entryView({ data: { ...entryData(), extra: 1 } }) },
    manifest_identity_mismatch: { entry: entryView({ data: entryData({ halaqaId: "hOther" }) }) },
    manifest_plan_mismatch: { entry: entryView({ data: entryData({ planDigest: hex("f") }) }) },
    manifest_prior_state_invalid: { entry: entryView({ data: entryData({ priorCanonical: "present" }) }) },
    observed_missing: { observed: { exists: false } },
    observed_schema_invalid: { observed: observedView({ data: { ...observedData(), canonicalCreateTime: 5 } }) },
    observed_identity_mismatch: { observed: observedView({ data: { ...observedData(), runId: "run-other-0001" } }) },
    already_rolled_back: { rollbackRecord: { exists: true } },
    canonical_missing: { canonical: { exists: false } },
    metadata_unavailable: { canonical: canonicalDoc({ updateTime: undefined }) },
    observed_not_pristine: { observed: observedView({ data: { ...observedData(), canonicalUpdateTime: "501.000000000" } }) },
    modified_since_creation: { canonical: canonicalDoc({ updateTime: T(501) }) },
    create_time_mismatch: { canonical: canonicalDoc({ createTime: T(900), updateTime: T(900) }) },
    observed_incarnation_unproven: { entry: entryView({ createTime: T(400) }) },
    observation_before_commit: { observed: observedView({ createTime: T(500) }) },
    observation_late: { observed: observedView({ createTime: T(561) }) },
    canonical_schema_changed: { canonical: canonicalDoc({ data: { meetingLink: LINK_A, updatedAt: T(500, 123000000), marker: "x" } }) },
    updated_at_mismatch: { canonical: canonicalDoc({ data: { meetingLink: LINK_A, updatedAt: T(500) } }) },
  };
  for (const [reason, overrides] of Object.entries(cases)) assert.deepEqual(evidence(overrides), { complete: false, reason }, reason);

  for (const missing of [{ entry: entryView({ createTime: undefined }) }, { observed: observedView({ createTime: null }) }]) {
    assert.deepEqual(evidence(missing), { complete: false, reason: "metadata_unavailable" }, "missing metadata is never eligible");
  }
  assert.equal(evidence({ observed: observedView({ createTime: T(560) }) }).complete, true, "inside the default window");
  assert.equal(evidence({ observed: observedView({ createTime: T(530) }) }, { maxObservationDelayMs: 10_000 }).reason, "observation_late", "callers may tighten");
  assert.equal(evidence({}, { maxObservationDelayMs: OBSERVATION_MAX_DELAY_MS + 1 }).reason, "observation_window_invalid", "callers may not widen");
  assert.equal(evidence({ canonical: canonicalDoc({ data: { meetingLink: 5, updatedAt: T(500, 123000000) } }) }).reason, "canonical_schema_changed");
});

test("A1 rollback never authorizes a delete: an unchanged admin re-save is indistinguishable from no action", () => {
  assert.deepEqual(APPROVED_INTERVENING_ACTION_PROOFS, []);
  assert.equal(Object.isFrozen(APPROVED_INTERVENING_ACTION_PROOFS), true);
  const decide = (overrides = {}) =>
    decideRollbackDelete({ writer: rollbackWriter(), halaqaId: "hValid", readSet: rollbackReadSet(), identity: IDENTITY, ...overrides });

  // An admin saving the same link returns before any write or audit entry, so
  // the stored state after that save is byte-for-byte this fixture.
  const unchangedSave = decide();
  assert.deepEqual(unchangedSave, {
    delete: false,
    outcome: "skipped",
    reason: "admin_resave_unprovable",
    recommendation: "forward_fix",
    evidenceComplete: true,
  });
  assert.equal(decide({ interveningActionProof: { kind: "auditTrail" } }).reason, "proof_kind_not_approved");
  assert.equal(decide({ interveningActionProof: { kind: "attestedFreeze" } }).reason, "proof_kind_not_approved");

  const cases = [
    ["rollback's own stop", { readSet: rollbackReadSet({ views: { stop: { exists: true } } }) }, "fenced", "stop_requested"],
    ["released", { readSet: rollbackReadSet({ views: { release: { exists: true } } }) }, "fenced", "lock_released"],
    ["apply lock", { readSet: rollbackReadSet({ views: { lock: { exists: true, data: lockDataFor(applyWriter({ generation: 3 })) } } }) }, "fenced", "lock_owner_mismatch"],
    [
      "lock kind",
      { readSet: rollbackReadSet({ views: { lock: { exists: true, data: { ...lockDataFor(rollbackWriter()), kind: "apply" } } } }) },
      "fenced",
      "lock_kind_mismatch",
    ],
    [
      "apply run's stop read instead of own",
      { readSet: rollbackReadSet({ views: { stop: undefined }, options: { extra: { [runPaths(RUN).stop]: { exists: false } } } }) },
      "rejected",
      "unexpected_evidence",
    ],
    ["observed not read", { readSet: rollbackReadSet({ views: { observed: undefined } }) }, "rejected", "missing_transactional_evidence"],
    ["other project", { readSet: rollbackReadSet({ options: { connection: { ...CONNECTION, projectId: "rafiq-academy" } } }) }, "rejected", "connection_target_mismatch"],
    ["apply writer", { writer: applyWriter() }, "rejected", "writer_kind_mismatch"],
    ["observation late", { readSet: rollbackReadSet({ views: { observed: observedView({ createTime: T(600) }) } }) }, "skipped", "observation_late"],
    ["no metadata", { readSet: rollbackReadSet({ views: { entry: entryView({ createTime: undefined }) } }) }, "skipped", "metadata_unavailable"],
  ];
  for (const [label, overrides, outcome, reason] of cases) {
    const result = decide(overrides);
    assert.deepEqual([result.delete, result.outcome, result.reason], [false, outcome, reason], label);
  }
  assert.equal(rollbackEvidencePaths({ writer: rollbackWriter(), halaqaId: "hValid" }).stop, runPaths(RB).stop);
  assert.equal(rollbackEvidencePaths({ writer: rollbackWriter(), halaqaId: "hValid" }).entry, runPaths(RUN).entry("hValid"));
});

// ── outcomes, run states and summary ───────────────────────────────────────

test("A2/A3 outcome vocabulary: every outcome, a missing outcome and unknown outcomes map to one run state", () => {
  assert.deepEqual(new Set(Object.values(CANDIDATE_OUTCOMES)), new Set(OUTCOME_CLASSES.filter((c) => c !== "notAttempted")));
  const S = RUN_STATES;
  const expectedState = {
    created: S.COMPLETED,
    skipped: S.COMPLETED,
    stopped: S.STOPPED_OPERATOR,
    failed: S.STOPPED_TRANSIENT,
    unresolved: S.STOPPED_TRANSIENT,
    contradictory: S.FAILED_FATAL,
    contractViolation: S.FAILED_FATAL,
  };
  const handle = candidateOnlyPlan();
  const verdict = (outcomes) => completionVerdict(summarizeRun({ validatedPlan: handle, outcomes }), 0).state;
  for (const [outcome, cls] of Object.entries(CANDIDATE_OUTCOMES)) {
    const outcomes = new Map([
      ["hValid", { outcome: "migrated", reason: null }],
      ["hPadded", { outcome, reason: outcome === "failed" ? "unavailable" : null }],
    ]);
    assert.equal(verdict(outcomes), expectedState[cls], outcome);
  }
  const migrated = { outcome: "migrated", reason: null };
  const table = [
    ["candidate never attempted", new Map([["hValid", migrated]]), S.STOPPED_TRANSIENT],
    ["old vocabulary 'committed'", new Map([["hValid", migrated], ["hPadded", { outcome: "committed" }]]), S.FAILED_FATAL],
    ["decision token 'write'", new Map([["hValid", migrated], ["hPadded", { outcome: "write" }]]), S.FAILED_FATAL],
    ["bare string outcome", new Map([["hValid", migrated], ["hPadded", "migrated"]]), S.FAILED_FATAL],
    ["outcome for a non-candidate", new Map([["hValid", migrated], ["hPadded", migrated], ["hSame", migrated]]), S.FAILED_FATAL],
    ["all created", new Map([["hValid", migrated], ["hPadded", { outcome: "committedAfterAmbiguity", reason: null }]]), S.COMPLETED],
  ];
  for (const [label, outcomes, state] of table) assert.equal(verdict(outcomes), state, label);

  const withReview = opened();
  const all = new Map([["hValid", migrated], ["hPadded", migrated]]);
  assert.equal(completionVerdict(summarizeRun({ validatedPlan: withReview, outcomes: all }), 0).state, S.COMPLETED_REVIEW_REQUIRED);
  assert.equal(isCleanCompletion(S.COMPLETED_REVIEW_REQUIRED), false);
  assert.equal(summarizeRun({ validatedPlan: plan(), outcomes: all }), null);
});

test("A3 run states fail closed: unknown states, missing or inconsistent verification never complete", () => {
  const S = RUN_STATES;
  const handle = candidateOnlyPlan();
  const clean = summarizeRun({
    validatedPlan: handle,
    outcomes: new Map([
      ["hValid", { outcome: "migrated", reason: null }],
      ["hPadded", { outcome: "canonicalAppeared", reason: null }],
    ]),
  });
  const verified = (summary, invariantViolations = 0) => transitionRun(S.VERIFYING, { type: "verified", summary, invariantViolations });
  assert.deepEqual(verified(clean), { ok: true, state: S.COMPLETED, writeEvent: true, reason: null });

  const cases = [
    ["no summary", verified(undefined), S.FAILED_FATAL, "summary_invalid"],
    ["invariant violation", verified(clean, 1), S.FAILED_FATAL, "verification_failed"],
    ["invariants not reported", transitionRun(S.VERIFYING, { type: "verified", summary: clean }), S.FAILED_FATAL, "verification_failed"],
    ["counts do not add up", verified({ ...clean, byClass: { ...clean.byClass, notAttempted: 0, created: 0 } }), S.FAILED_FATAL, "summary_inconsistent"],
    ["hidden violation", verified({ ...clean, unexpectedOutcomes: 1 }), S.FAILED_FATAL, "summary_inconsistent"],
    ["extra field", verified({ ...clean, completed: true }), S.FAILED_FATAL, "summary_invalid"],
    ["negative count", verified({ ...clean, byClass: { ...clean.byClass, created: -1, skipped: 3 } }), S.FAILED_FATAL, "summary_invalid"],
    ["old caller-chosen fields", transitionRun(S.VERIFYING, { type: "verified", reviewFindings: 0 }), S.FAILED_FATAL, "verification_failed"],
  ];
  for (const [label, result, state, reason] of cases) assert.deepEqual([result.state, result.reason], [state, reason], label);

  for (const state of ["COMPLETE", "", undefined, "completed", null]) {
    assert.deepEqual(transitionRun(state, { type: "start" }), { ok: false, state, writeEvent: false, reason: "unknown_state" }, String(state));
  }
  assert.equal(transitionRun(S.NOT_STARTED, { type: "start" }).state, S.RUNNING);
  assert.equal(transitionRun(S.RUNNING, { type: "heartbeat" }).state, S.RUNNING);
  assert.equal(transitionRun(S.RUNNING, { type: "candidatesFinal" }).state, S.VERIFYING);
  assert.equal(transitionRun(S.RUNNING, { type: "transientLimit" }).state, S.STOPPED_TRANSIENT);
  assert.equal(transitionRun(S.VERIFYING, { type: "stopObserved" }).state, S.STOPPED_OPERATOR);
  assert.equal(transitionRun(S.RUNNING, { type: "operatorAbandoned" }).state, S.ABANDONED);
  for (const reason of ["identity_mismatch", "permission_denied", "unauthenticated", "egress_blocked"]) {
    assert.deepEqual(transitionRun(S.RUNNING, { type: "fatal", reason }), { ok: true, state: S.FAILED_FATAL, writeEvent: false, reason });
  }
  assert.equal(transitionRun(S.RUNNING, { type: "fatal", reason: "manifest_invariant" }).writeEvent, true);
  for (const state of TERMINAL_STATES) {
    assert.deepEqual(transitionRun(state, { type: "start" }), { ok: false, state, writeEvent: false, reason: "terminal_state" });
  }
  assert.equal(transitionRun(S.NOT_STARTED, { type: "verified" }).reason, "invalid_transition");
  assert.equal(transitionRun(S.VERIFYING, { type: "transientLimit" }).reason, "invalid_transition");
  assert.equal(isCleanCompletion(S.COMPLETED), true);
});

test("B9 run summary and per-record outcome documents are count-only and value-free", () => {
  const records = [
    ...fixtureRecords(),
    ...["hC1", "hC2", "hC3", "hC4", "hC5", "hC6"].map((id) => scan(id, { meetingLink: LINK_A }, null)),
  ];
  const raw = plan({ records });
  const handle = opened(raw);
  const outcomes = new Map([
    ["hValid", { outcome: "migrated", reason: null }],
    ["hPadded", { outcome: "committedAfterAmbiguity", reason: null }],
    ["hC1", { outcome: "changedSinceReview", reason: null }],
    ["hC2", { outcome: "fenced", reason: "stop_requested" }],
    ["hC3", { outcome: "failed", reason: "unavailable" }],
    ["hC4", { outcome: "unresolved", reason: "manifest_absent_canonical_absent" }],
    ["hC6", { outcome: "failed", reason: LINK_A }],
  ]);
  const summary = summarizeRun({ validatedPlan: handle, outcomes, createdByEarlierRuns: ["hSame"] });
  assert.equal(summary.candidates, 8);
  assert.deepEqual(summary.byClass, { created: 2, skipped: 1, stopped: 1, failed: 2, unresolved: 1, contradictory: 0, contractViolation: 0, notAttempted: 1 });
  assert.deepEqual(summary.reasons, {
    "fenced:stop_requested": 1,
    "failed:unavailable": 1,
    "failed:unknown": 1,
    "unresolved:manifest_absent_canonical_absent": 1,
  });
  assert.deepEqual(summary.preExisting, { createdByEarlierMigrationRun: 1, notFromMigration: 4 });
  assert.equal(summary.noLink, 2);
  assert.deepEqual(summary.needsReview, {
    invalidLegacy: 1,
    malformedLegacy: 1,
    conflict: 1,
    canonicalMalformed: 1,
    canonicalWithoutValidLegacy: 1,
    orphanCanonical: 1,
  });
  assertNoLinks(summary, "summary");
  assert.equal(JSON.stringify(summary).includes("hValid"), false, "summaries are count-only");

  const doc = outcomeRecordFields({ runId: RUN, halaqaId: "hC3", planDigest: DIGEST, outcome: "failed", reason: "unavailable" });
  assert.deepEqual(doc, { halaqaId: "hC3", runId: RUN, planDigest: DIGEST, outcome: "failed", reason: "unavailable", schemaVersion: RECORD_SCHEMA_VERSION });
  const expect = { runId: RUN, halaqaId: "hC3", planDigest: DIGEST };
  assert.equal(validateOutcomeRecord(doc, expect), null);
  assert.equal(validateOutcomeRecord({ ...doc, outcome: "committed" }, expect), "outcome_unknown");
  assert.equal(validateOutcomeRecord({ ...doc, planDigest: hex("f") }, expect), "outcome_identity_mismatch");
  assert.equal(validateOutcomeRecord({ ...doc, extra: 1 }, expect), "outcome_schema_invalid");
  assert.equal(outcomeRecordFields({ runId: RUN, halaqaId: "hC6", planDigest: DIGEST, outcome: "failed", reason: LINK_A }).reason, "unknown");
});

test("release gate: recorded state must match the recomputed verdict; review, verification and deployment block", () => {
  const deployment = { rulesVerified: true, functionsRevisionVerified: true, productionBackendFlagVerified: true };
  const verification = { invariantViolations: 0 };
  const migrated = { outcome: "migrated", reason: null };
  const both = new Map([["hValid", migrated], ["hPadded", migrated]]);
  const cleanSummary = summarizeRun({ validatedPlan: candidateOnlyPlan(), outcomes: both });
  const reviewSummary = summarizeRun({ validatedPlan: opened(), outcomes: both });
  const findings = REVIEW_CATEGORIES.map((category, i) => ({ halaqaId: `hR${i}`, category }));
  const allDispositions = Object.fromEntries(findings.map((f) => [f.halaqaId, "accepted_no_link"]));
  const gate = (overrides) =>
    releaseGateDecision({ runState: RUN_STATES.COMPLETED, summary: cleanSummary, reviewFindings: [], dispositions: {}, verification, deployment, ...overrides });

  assert.deepEqual(gate({}), { allowCanonicalOnlyRelease: true, blockers: [] });
  const review = { runState: RUN_STATES.COMPLETED_REVIEW_REQUIRED, summary: reviewSummary, reviewFindings: findings };
  assert.deepEqual(gate({ ...review, dispositions: allDispositions }), { allowCanonicalOnlyRelease: true, blockers: [] });
  assert.ok(gate(review).blockers.includes("unresolved_review:conflict"));
  assert.ok(gate({ ...review, dispositions: { ...allDispositions, hR2: "ignored" } }).blockers.includes("unresolved_review:conflict"));
  assert.ok(gate({ ...review, reviewFindings: findings.slice(1), dispositions: allDispositions }).blockers.includes("findings_count_mismatch"));
  assert.ok(gate({ runState: RUN_STATES.COMPLETED, summary: reviewSummary }).blockers.includes("state_summary_mismatch"));

  const partial = summarizeRun({ validatedPlan: candidateOnlyPlan(), outcomes: new Map([["hValid", migrated]]) });
  assert.ok(gate({ summary: partial }).blockers.includes("state_summary_mismatch"), "COMPLETED with a not-attempted candidate is rejected");
  const fenced = summarizeRun({ validatedPlan: candidateOnlyPlan(), outcomes: new Map([["hValid", migrated], ["hPadded", { outcome: "fenced", reason: "lock_released" }]]) });
  assert.ok(gate({ summary: fenced }).blockers.includes("state_summary_mismatch"), "COMPLETED with a fenced candidate is rejected");
  assert.ok(gate({ summary: undefined }).blockers.includes("state_summary_mismatch"));

  for (const state of [RUN_STATES.STOPPED_TRANSIENT, RUN_STATES.FAILED_FATAL, RUN_STATES.ABANDONED, RUN_STATES.RUNNING, "COMPLETE"]) {
    assert.ok(gate({ runState: state }).blockers.includes("run_not_completed"), String(state));
  }
  assert.deepEqual(gate({ verification: { invariantViolations: 1 } }).blockers, ["state_summary_mismatch", "verification_failed"]);
  assert.deepEqual(gate({ verification: undefined }).blockers, ["state_summary_mismatch", "verification_failed"]);
  assert.deepEqual(gate({ deployment: {} }).blockers, [
    "deployment_unverified:functionsRevisionVerified",
    "deployment_unverified:productionBackendFlagVerified",
    "deployment_unverified:rulesVerified",
  ]);
});

// ── module boundaries ──────────────────────────────────────────────────────

const stripComments = (source) => source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*\/\/.*$/gm, "");

test("the core is pure: no SDK, network, process, filesystem or console use; no write calls; never imports the script", () => {
  const source = stripComments(readFileSync(join(here, "..", "scripts", "meeting-link-migration-core.mjs"), "utf8"));
  const imports = [...source.matchAll(/^import .* from "([^"]+)";\r?$/gm)].map((m) => m[1]);
  assert.deepEqual(imports, ["node:crypto"]);
  for (const forbidden of [
    /firebase-admin/,
    /\bprocess\./,
    /\bconsole\./,
    /\bfetch\(/,
    /node:(fs|net|http|https|dns|child_process)/,
    /\btx\./,
    /\.(collection|doc|runTransaction|batch|getAll)\(/,
    /migrate-meeting-links/,
    /\bimport\(/,
  ]) {
    assert.doesNotMatch(source, forbidden, String(forbidden));
  }
});

test("A7 static guard: the unfenced canonicalWriter stays inside the emulator-only entry point", () => {
  const root = join(here, "..");
  const files = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        if (!["node_modules", "lib", ".git"].includes(entry.name)) walk(join(dir, entry.name));
      } else if (/\.(m?js|ts)$/.test(entry.name)) {
        files.push(join(dir, entry.name));
      }
    }
  };
  for (const dir of ["scripts", "src", "test"]) walk(join(root, dir));
  const self = fileURLToPath(import.meta.url);
  const users = files
    .filter((file) => file !== self && /\bcanonicalWriter\b/.test(stripComments(readFileSync(file, "utf8"))))
    .map((file) => relative(root, file).replaceAll("\\", "/"))
    .sort();
  assert.deepEqual(users, ["scripts/migrate-meeting-links.mjs", "test/migrate_meeting_links.emulator.test.mjs"]);

  const script = readFileSync(join(root, "scripts", "migrate-meeting-links.mjs"), "utf8");
  assert.match(script, /export const EMULATOR_PROJECT = "demo-[a-z0-9-]+";/);
  assert.equal(script.match(/tx\.create\(/g)?.length, 1, "one write call in the entry point");
  assert.doesNotMatch(script, /tx\.(set|update|delete)\(/);
  const main = script.slice(script.indexOf("async function main()"));
  const call = main.indexOf("canonicalWriter(db");
  assert.ok(call > 0, "the writer is only constructed in main");
  for (const guard of ["checkInvocation(", "startEgressGuard(", "verifyHub(", "initializeApp({ projectId: EMULATOR_PROJECT }", "refuse(\"firebase-admin resolved a different project.\")"]) {
    const at = main.indexOf(guard);
    assert.ok(at >= 0 && at < call, `${guard} precedes canonicalWriter`);
  }
  assert.equal(script.match(/canonicalWriter\(db/g)?.length, 2, "one definition and one construction");

  assert.match(script, /from "\.\/meeting-link-migration-core\.mjs"/);
  assert.doesNotMatch(script, /export function (classifyLegacy|classifyCanonical|decide|isValidDocumentId)\b/);
  assert.doesNotMatch(script, /\b(decideCandidateWrite|decideRollbackDelete|decideLockAcquisition|openPlan)\b/, "no production writer is wired to the core");
});
