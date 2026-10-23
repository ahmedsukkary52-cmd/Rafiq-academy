// B14 — pure decision core for the meeting-link migration: record
// classification, reviewed plans and their digest, drift, per-candidate write
// decisions, ambiguous-commit resolution, rollback evidence, create-only run
// locks with write fencing, run states and the canonical-only release gate.
//
// No firebase-admin, no network, no credentials, no process state. Callers
// pass plain data: documents as { exists, data, createTime, updateTime },
// Firestore metadata as Timestamp-like { seconds, nanoseconds } values.
// Outputs carry ids, reason codes, counts and metadata only — never a link
// value or anything derived from one.
//
// What this module enforces vs. what a future adapter must provide:
// - Enforced here: plan digest binding to an explicitly approved digest,
//   expiry before every write decision, candidate lookup inside a validated
//   plan, lock kind/owner/generation/release/stop/plan-digest fencing, exact
//   read-set paths, connection identity comparison, one outcome vocabulary,
//   fail-closed run states, rollback that never authorizes a delete.
// - Not provable here: that a read set really came from the same Firestore
//   transaction as the write, that `connection` was filled from the SDK's
//   actual target, and that version hashes describe the code actually loaded.
//   Those are adapter/runner obligations; this module only rejects evidence
//   that is missing, unexpected or inconsistent.
//
// Nothing here is a production capability. The emulator-only entry point is
// migrate-meeting-links.mjs; Firestore behaviour that these decisions rely on
// is exercised in meeting_link_migration_core.emulator.test.mjs.
import { createHash } from "node:crypto";

export const MIGRATION_ID = "meeting-link-migration";
export const PLAN_KIND = "meeting-link-migration-plan";
export const PLAN_SCHEMA_VERSION = 2;
export const CANONICAL_SCHEMA_VERSION = 1;
export const RECORD_SCHEMA_VERSION = 2;
export const PLAN_TTL_MS = 24 * 60 * 60 * 1000;
export const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
export const PLAN_MODES = Object.freeze(["apply"]);

const hasOwn = (data, key) => Object.prototype.hasOwnProperty.call(data, key);
const isPlainObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const sameKeys = (data, keys) => {
  const actual = Object.keys(data).sort();
  const wanted = [...keys].sort();
  return actual.length === wanted.length && actual.every((key, i) => key === wanted[i]);
};

// ── legacy and canonical classification ────────────────────────────────────

export const LINK_ISSUES = Object.freeze([
  "empty",
  "too_long",
  "whitespace",
  "unsupported_characters",
  "not_https",
  "credentials",
  "invalid_host",
  "malformed",
  "contact_info",
]);
export const MALFORMED_REASONS = Object.freeze([
  "missing_meeting_link",
  "extra_keys",
  "non_string",
  "untrimmed",
  "invalid_link",
  "bad_updated_at",
]);

function safeIssue(issue) {
  return LINK_ISSUES.includes(issue) ? issue : "other";
}

/** One legacy category per halaqa; the canonical target is `raw.trim()`. */
export function classifyLegacy(data, issueOf) {
  if (!hasOwn(data ?? {}, "meetingLink")) return { category: "missing" };
  const raw = data.meetingLink;
  if (typeof raw !== "string") return { category: "nonString" };
  const value = raw.trim();
  if (value === "") return { category: "empty" };
  const issue = issueOf(raw);
  if (issue) return { category: "invalid", reason: safeIssue(issue) };
  return { category: "valid", value, trimRequired: value !== raw };
}
const LEGACY_CATEGORIES = Object.freeze(["missing", "nonString", "empty", "invalid", "valid"]);

/** Canonical schema is exactly { meetingLink, updatedAt: Timestamp }, with a valid trimmed link. */
export function classifyCanonical(data, issueOf, isTimestamp) {
  const doc = data ?? {};
  if (!hasOwn(doc, "meetingLink")) return { malformed: true, reason: "missing_meeting_link" };
  if (Object.keys(doc).some((key) => key !== "meetingLink" && key !== "updatedAt")) {
    return { malformed: true, reason: "extra_keys" };
  }
  const link = doc.meetingLink;
  if (typeof link !== "string") return { malformed: true, reason: "non_string" };
  if (link !== link.trim()) return { malformed: true, reason: "untrimmed" };
  if (issueOf(link)) return { malformed: true, reason: "invalid_link" };
  if (!isTimestamp(doc.updatedAt)) return { malformed: true, reason: "bad_updated_at" };
  return { malformed: false, value: link };
}

/** "candidate" | "noAction" | "alreadyMigrated" | "conflict" | "malformed" | "withoutValidLegacy". */
export function decide(legacy, canonical) {
  if (canonical === null) return legacy.category === "valid" ? "candidate" : "noAction";
  if (canonical.malformed) return "malformed";
  if (legacy.category !== "valid") return "withoutValidLegacy";
  return canonical.value === legacy.value ? "alreadyMigrated" : "conflict";
}

// ── plan record categories ─────────────────────────────────────────────────

/**
 * Every halaqa (and every canonical doc without a halaqa) gets exactly one
 * category. Review categories are never migrated and block the canonical-only
 * client release until each record has a recorded disposition.
 */
export const RECORD_CATEGORIES = Object.freeze([
  "candidate",
  "alreadyMigrated",
  "noLink",
  "invalidLegacy",
  "malformedLegacy",
  "conflict",
  "canonicalMalformed",
  "canonicalWithoutValidLegacy",
  "orphanCanonical",
]);
export const REVIEW_CATEGORIES = Object.freeze([
  "invalidLegacy",
  "malformedLegacy",
  "conflict",
  "canonicalMalformed",
  "canonicalWithoutValidLegacy",
  "orphanCanonical",
]);
const CANONICAL_PRESENT = new Set([
  "alreadyMigrated",
  "conflict",
  "canonicalMalformed",
  "canonicalWithoutValidLegacy",
  "orphanCanonical",
]);
const NO_LINK_REASONS = Object.freeze(["missing", "empty"]);

function reasonsFor(category) {
  if (category === "invalidLegacy") return [...LINK_ISSUES, "other"];
  if (category === "canonicalMalformed") return MALFORMED_REASONS;
  if (category === "noLink") return NO_LINK_REASONS;
  return null;
}

/** Value-free category for one halaqa from classifyLegacy / classifyCanonical results. */
export function classifyRecord(legacy, canonical) {
  switch (decide(legacy, canonical)) {
    case "candidate":
      return { category: "candidate", reason: null, trimRequired: legacy.trimRequired === true };
    case "alreadyMigrated":
      return { category: "alreadyMigrated", reason: null, trimRequired: legacy.trimRequired === true };
    case "conflict":
      return { category: "conflict", reason: null, trimRequired: false };
    case "malformed":
      return { category: "canonicalMalformed", reason: canonical.reason, trimRequired: false };
    case "withoutValidLegacy":
      return { category: "canonicalWithoutValidLegacy", reason: null, trimRequired: false };
    default:
      if (legacy.category === "invalid") return { category: "invalidLegacy", reason: legacy.reason, trimRequired: false };
      if (legacy.category === "nonString") return { category: "malformedLegacy", reason: null, trimRequired: false };
      return { category: "noLink", reason: legacy.category, trimRequired: false };
  }
}

// ── metadata and ids ───────────────────────────────────────────────────────

/** "seconds.nanoseconds" for a Timestamp-like value; null when absent or not a valid timestamp. */
export function timeKey(value) {
  if (!value || typeof value !== "object") return null;
  const { seconds, nanoseconds } = value;
  if (!Number.isSafeInteger(seconds) || !Number.isInteger(nanoseconds) || nanoseconds < 0 || nanoseconds > 999_999_999) {
    return null;
  }
  return `${seconds}.${String(nanoseconds).padStart(9, "0")}`;
}
const TIME_KEY = /^-?\d+\.\d{9}$/;
const isTimeKey = (value) => typeof value === "string" && TIME_KEY.test(value);

/** Nanoseconds since the epoch for a time key, as a BigInt. */
function nanosOf(key) {
  const [seconds, nanos] = key.split(".");
  return BigInt(seconds) * 1_000_000_000n + BigInt(nanos);
}

/** Firestore document-id rules. */
export function isValidDocumentId(id) {
  return (
    typeof id === "string" &&
    id !== "" &&
    id !== "." &&
    id !== ".." &&
    !id.includes("/") &&
    !/^__[\s\S]*__$/.test(id) &&
    id.isWellFormed() &&
    Buffer.byteLength(id, "utf8") <= 1500
  );
}

const RUN_ID = /^[a-z0-9][a-z0-9-]{6,62}[a-z0-9]$/;
export const isValidRunId = (id) => typeof id === "string" && RUN_ID.test(id);
const PROJECT_ID = /^[a-z][a-z0-9-]{4,61}[a-z0-9]$/;
const DATABASE_ID = /^(\(default\)|[a-z][a-z0-9-]{2,61}[a-z0-9])$/;
const SHA256_HEX = /^[0-9a-f]{64}$/;
const isSha256Hex = (value) => typeof value === "string" && SHA256_HEX.test(value);
const REASON_CODE = /^[a-z0-9_:-]{1,60}$/;
const safeReason = (value) => (typeof value === "string" && REASON_CODE.test(value) ? value : "unknown");

// ── versions ───────────────────────────────────────────────────────────────

/**
 * Every code component that can influence a write is bound into the plan.
 * The hashes must be computed by the runner from the bytes it actually loaded
 * and compared before any write; a hash supplied by a caller proves nothing
 * about what is executing. That runtime check is a future runner
 * prerequisite — this module only requires that all components are present.
 */
export const VERSION_COMPONENTS = Object.freeze(["adapter", "core", "entryPoint", "validator"]);
const VERSION_KEYS = Object.freeze([...VERSION_COMPONENTS, "canonicalSchema"]);

export function sha256Hex(content) {
  return createHash("sha256").update(content).digest("hex");
}

// ── plans ──────────────────────────────────────────────────────────────────

/**
 * The persisted form of one record. Only whitelisted, value-free fields are
 * kept, whatever else the caller passes (a scan result may carry the link).
 */
function toPlanRecord(input) {
  return {
    halaqaId: input.halaqaId,
    category: input.category,
    reason: input.reason ?? null,
    trimRequired: input.trimRequired === true,
    halaqaUpdateTime: timeKey(input.halaqaUpdateTime) ?? (isTimeKey(input.halaqaUpdateTime) ? input.halaqaUpdateTime : null),
    canonicalUpdateTime:
      timeKey(input.canonicalUpdateTime) ?? (isTimeKey(input.canonicalUpdateTime) ? input.canonicalUpdateTime : null),
  };
}

/** Plan record for a scanned halaqa (classifier results may contain the link; it is dropped). */
export function planRecordFromScan({ halaqaId, legacy, canonical, halaqaUpdateTime, canonicalUpdateTime }) {
  return toPlanRecord({ halaqaId, ...classifyRecord(legacy, canonical), halaqaUpdateTime, canonicalUpdateTime });
}

/** Plan record for a canonical doc whose halaqa does not exist. */
export function orphanPlanRecord({ halaqaId, canonicalUpdateTime }) {
  return toPlanRecord({ halaqaId, category: "orphanCanonical", canonicalUpdateTime });
}

function recordProblem(record) {
  if (!isPlainObject(record)) return "record_invalid";
  if (!sameKeys(record, ["canonicalUpdateTime", "category", "halaqaId", "halaqaUpdateTime", "reason", "trimRequired"])) {
    return "record_invalid";
  }
  if (!isValidDocumentId(record.halaqaId)) return "record_invalid";
  if (!RECORD_CATEGORIES.includes(record.category)) return "category_unknown";
  const reasons = reasonsFor(record.category);
  if (reasons === null ? record.reason !== null : !reasons.includes(record.reason)) return "reason_invalid";
  if (typeof record.trimRequired !== "boolean") return "record_invalid";
  if (record.trimRequired && record.category !== "candidate" && record.category !== "alreadyMigrated") {
    return "record_invalid";
  }
  const orphan = record.category === "orphanCanonical";
  if (orphan ? record.halaqaUpdateTime !== null : !isTimeKey(record.halaqaUpdateTime)) return "metadata_invalid";
  const canonicalPresent = CANONICAL_PRESENT.has(record.category);
  if (canonicalPresent ? !isTimeKey(record.canonicalUpdateTime) : record.canonicalUpdateTime !== null) {
    return "metadata_invalid";
  }
  return null;
}

export function countCategories(records) {
  const counts = Object.fromEntries(RECORD_CATEGORIES.map((category) => [category, 0]));
  for (const record of records) if (hasOwn(counts, record.category)) counts[record.category] += 1;
  return counts;
}

/** Deterministic JSON: object keys sorted, undefined dropped, non-finite numbers rejected. */
export function canonicalJson(value) {
  if (value === null || typeof value === "string" || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new TypeError("non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (isPlainObject(value)) {
    const keys = Object.keys(value).filter((key) => value[key] !== undefined).sort();
    return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  }
  throw new TypeError("unsupported value");
}

const PLAN_BODY_KEYS = Object.freeze([
  "counts",
  "expiresAt",
  "identity",
  "issuedAt",
  "kind",
  "mode",
  "records",
  "schemaVersion",
  "versions",
]);

function planBody(plan) {
  return Object.fromEntries(PLAN_BODY_KEYS.map((key) => [key, plan[key]]));
}

/** SHA-256 over every reviewed field except the digest itself. */
export function computePlanDigest(plan) {
  return createHash("sha256").update(canonicalJson(planBody(plan))).digest("hex");
}

function identityProblems(identity) {
  const problems = [];
  if (!isPlainObject(identity) || !sameKeys(identity, ["databaseId", "migrationId", "projectId"])) return ["identity_invalid"];
  if (!PROJECT_ID.test(identity.projectId ?? "")) problems.push("identity_invalid:projectId");
  if (!DATABASE_ID.test(identity.databaseId ?? "")) problems.push("identity_invalid:databaseId");
  if (identity.migrationId !== MIGRATION_ID) problems.push("identity_invalid:migrationId");
  return problems;
}

function versionProblems(versions) {
  const problems = [];
  if (!isPlainObject(versions) || !sameKeys(versions, VERSION_KEYS)) return ["versions_invalid"];
  for (const component of VERSION_COMPONENTS) {
    if (!isSha256Hex(versions[component])) problems.push(`versions_invalid:${component}`);
  }
  if (versions.canonicalSchema !== CANONICAL_SCHEMA_VERSION) problems.push("versions_invalid:canonicalSchema");
  return problems;
}

export class PlanInputError extends Error {
  constructor(problems) {
    super(`plan input rejected: ${problems.join(", ")}`);
    this.code = "plan-input-invalid";
    this.problems = problems;
  }
}

/**
 * Builds the reviewed plan a dry run hands to apply. Records are sorted by
 * halaqa id; the digest binds identity, every version component, mode,
 * validity window, every record (category, reason, source/canonical update
 * times) and counts.
 *
 * A plan is evidence of what was reviewed, not a lock: data can still change
 * after review, so every write keeps its own transactional re-read
 * (decideCandidateWrite) and drift check.
 */
export function buildMigrationPlan({ identity, versions, mode, issuedAt, ttlMs = PLAN_TTL_MS, records }) {
  const problems = [...identityProblems(identity), ...versionProblems(versions)];
  if (!PLAN_MODES.includes(mode)) problems.push("mode_unknown");
  if (!Number.isSafeInteger(issuedAt) || issuedAt <= 0) problems.push("issued_at_invalid");
  if (!Number.isSafeInteger(ttlMs) || ttlMs <= 0 || ttlMs > PLAN_TTL_MS) problems.push("ttl_invalid");
  if (!Array.isArray(records)) problems.push("records_invalid");
  if (problems.length > 0) throw new PlanInputError(problems);

  const planRecords = records.map(toPlanRecord).sort((a, b) => (a.halaqaId < b.halaqaId ? -1 : a.halaqaId > b.halaqaId ? 1 : 0));
  for (let i = 0; i < planRecords.length; i += 1) {
    const problem = recordProblem(planRecords[i]);
    if (problem) throw new PlanInputError([problem]);
    if (i > 0 && planRecords[i - 1].halaqaId === planRecords[i].halaqaId) throw new PlanInputError(["record_duplicate"]);
  }
  const plan = {
    kind: PLAN_KIND,
    schemaVersion: PLAN_SCHEMA_VERSION,
    identity: { projectId: identity.projectId, databaseId: identity.databaseId, migrationId: identity.migrationId },
    versions: Object.fromEntries(VERSION_KEYS.map((key) => [key, versions[key]])),
    mode,
    issuedAt,
    expiresAt: issuedAt + ttlMs,
    records: planRecords,
    counts: countCategories(planRecords),
  };
  return { ...plan, digest: computePlanDigest(plan) };
}

/**
 * Validates a persisted plan against the run's expected identity, versions,
 * mode and the digest a human approved (`expected.approvedDigest`, required)
 * at time `now`. Returns { ok, problems } with reason codes only. Schema
 * problems stop validation early: the rest of the plan is untrusted.
 */
export function validatePlan(plan, { expected, now } = {}) {
  if (!isPlainObject(plan)) return { ok: false, problems: ["plan_not_object"] };
  if (plan.kind !== PLAN_KIND) return { ok: false, problems: ["kind_mismatch"] };
  if (plan.schemaVersion !== PLAN_SCHEMA_VERSION) return { ok: false, problems: ["schema_version_mismatch"] };
  if (!sameKeys(plan, [...PLAN_BODY_KEYS, "digest"])) return { ok: false, problems: ["plan_fields_invalid"] };

  const problems = [];
  let digest = null;
  try {
    digest = computePlanDigest(plan);
  } catch {
    problems.push("plan_unserializable");
  }
  if (digest !== null && plan.digest !== digest) problems.push("digest_mismatch");
  if (!isSha256Hex(expected?.approvedDigest)) problems.push("approved_digest_missing");
  else if (plan.digest !== expected.approvedDigest) problems.push("approved_digest_mismatch");

  problems.push(...identityProblems(plan.identity), ...versionProblems(plan.versions));
  for (const key of ["projectId", "databaseId", "migrationId"]) {
    if (plan.identity?.[key] !== expected?.identity?.[key]) problems.push(`identity_mismatch:${key}`);
  }
  for (const key of VERSION_KEYS) {
    if (plan.versions?.[key] !== expected?.versions?.[key]) problems.push(`version_mismatch:${key}`);
  }
  if (!PLAN_MODES.includes(plan.mode)) problems.push("mode_unknown");
  else if (plan.mode !== expected?.mode) problems.push("mode_mismatch");

  const { issuedAt, expiresAt } = plan;
  if (!Number.isSafeInteger(issuedAt) || !Number.isSafeInteger(expiresAt) || expiresAt <= issuedAt || expiresAt - issuedAt > PLAN_TTL_MS) {
    problems.push("validity_window_invalid");
  } else if (!Number.isSafeInteger(now)) {
    problems.push("now_invalid");
  } else {
    if (now < issuedAt - MAX_CLOCK_SKEW_MS) problems.push("issued_in_future");
    if (now >= expiresAt) problems.push("expired");
  }

  if (!Array.isArray(plan.records)) {
    problems.push("records_invalid");
  } else {
    const recordCodes = new Set();
    plan.records.forEach((record, i) => {
      const problem = recordProblem(record);
      if (problem) recordCodes.add(problem);
      else if (i > 0 && !(plan.records[i - 1].halaqaId < record.halaqaId)) recordCodes.add("records_not_sorted_unique");
    });
    problems.push(...recordCodes);
    if (recordCodes.size === 0 && canonicalJson(plan.counts ?? null) !== canonicalJson(countCategories(plan.records))) {
      problems.push("counts_mismatch");
    }
  }
  return { ok: problems.length === 0, problems: [...new Set(problems)].sort() };
}

// Validated plans are registered here; write decisions accept nothing else,
// so an arbitrary record object can never stand in for a reviewed candidate.
const VALIDATED_PLANS = new WeakMap();

const deepFreeze = (value) => {
  if (isPlainObject(value) || Array.isArray(value)) {
    for (const child of Object.values(value)) deepFreeze(child);
    Object.freeze(value);
  }
  return value;
};

/**
 * Validates a plan and returns an immutable handle for write decisions:
 * { ok: true, plan } or { ok: false, problems }. The handle is the only way
 * decideCandidateWrite and summarizeRun reach plan records.
 */
export function openPlan(plan, options) {
  const result = validatePlan(plan, options);
  if (!result.ok) return result;
  const records = structuredClone(plan.records);
  const handle = deepFreeze({
    digest: plan.digest,
    identity: { ...plan.identity },
    versions: { ...plan.versions },
    mode: plan.mode,
    issuedAt: plan.issuedAt,
    expiresAt: plan.expiresAt,
    counts: { ...plan.counts },
  });
  VALIDATED_PLANS.set(handle, new Map(records.map((record) => [record.halaqaId, deepFreeze(record)])));
  return { ok: true, plan: handle };
}

export const isValidatedPlan = (value) => VALIDATED_PLANS.has(value);

// ── drift between review and apply ─────────────────────────────────────────

/**
 * Compares the reviewed plan with a fresh scan (records in plan form).
 * - A record added or removed, any category or reason change, or different
 *   counts: `replanRequired` — the reviewed plan no longer describes the data.
 * - A candidate whose halaqa update time moved while its category stayed the
 *   same: listed in `changedSinceReview` and never migrated automatically
 *   (the legacy value may have been replaced by another valid one).
 * - Metadata changes on non-candidates do not affect any write and are only
 *   counted.
 * This is a pre-write check; it does not replace the in-transaction re-read.
 */
export function detectPlanDrift(plan, currentRecords) {
  const reviewed = new Map(plan.records.map((record) => [record.halaqaId, record]));
  const current = new Map(currentRecords.map(toPlanRecord).map((record) => [record.halaqaId, record]));
  const reasons = new Set();
  const changedSinceReview = [];
  let metadataChangedNonCandidate = 0;
  for (const [id, before] of reviewed) {
    const now = current.get(id);
    if (!now) {
      reasons.add("record_removed");
      continue;
    }
    if (now.category !== before.category || now.reason !== before.reason) {
      reasons.add("category_changed");
      continue;
    }
    const moved = now.halaqaUpdateTime !== before.halaqaUpdateTime || now.canonicalUpdateTime !== before.canonicalUpdateTime;
    if (before.category === "candidate" && (moved || now.trimRequired !== before.trimRequired)) changedSinceReview.push(id);
    else if (moved) metadataChangedNonCandidate += 1;
  }
  for (const id of current.keys()) if (!reviewed.has(id)) reasons.add("record_added");
  if (canonicalJson(countCategories([...current.values()])) !== canonicalJson(plan.counts)) reasons.add("counts_changed");
  return {
    replanRequired: reasons.size > 0,
    reasons: [...reasons].sort(),
    changedSinceReview: changedSinceReview.sort(),
    metadataChangedNonCandidate,
  };
}

// ── run locks and paths ────────────────────────────────────────────────────

export const LOCK_COLLECTION = "migrationLocks";
export const RUNS_COLLECTION = "migrationRuns";
export const LOCK_KINDS = Object.freeze(["apply", "rollback"]);
export const RELEASE_REASONS = Object.freeze(["completed", "stopped", "failed", "operator_abandoned"]);
const LOCK_KEYS = Object.freeze(["generation", "kind", "planDigest", "runId", "schemaVersion", "targetRunId"]);

export function lockId(generation) {
  return `meeting-links-${String(generation).padStart(6, "0")}`;
}

/** Document paths; one lock sequence is shared by apply and rollback. */
export function lockPaths(generation) {
  const lock = `${LOCK_COLLECTION}/${lockId(generation)}`;
  return { lock, release: `${lock}/release/final` };
}

export function runPaths(runId) {
  const run = `${RUNS_COLLECTION}/${runId}`;
  return {
    run,
    stop: `${run}/control/stop`,
    entry: (halaqaId) => `${run}/created/${halaqaId}`,
    observed: (halaqaId) => `${run}/observed/${halaqaId}`,
    outcome: (halaqaId) => `${run}/outcomes/${halaqaId}`,
    rollbackRecord: (rollbackId, halaqaId) => `${run}/rollbacks/${rollbackId}/deleted/${halaqaId}`,
  };
}

/**
 * Who is writing: { kind, runId, generation, planDigest, targetRunId }.
 * Rollback writers name the apply run they act on; apply writers do not.
 */
function writerProblem(writer, kind) {
  if (!isPlainObject(writer)) return "writer_invalid";
  if (!LOCK_KINDS.includes(writer.kind)) return "writer_kind_invalid";
  if (kind !== undefined && writer.kind !== kind) return "writer_kind_mismatch";
  if (!isValidRunId(writer.runId)) return "writer_run_id_invalid";
  if (!Number.isSafeInteger(writer.generation) || writer.generation < 1) return "writer_generation_invalid";
  if (!isSha256Hex(writer.planDigest)) return "writer_plan_digest_invalid";
  if (writer.kind === "rollback") {
    if (!isValidRunId(writer.targetRunId) || writer.targetRunId === writer.runId) return "writer_target_invalid";
  } else if (writer.targetRunId !== null && writer.targetRunId !== undefined) {
    return "writer_target_invalid";
  }
  return null;
}

/**
 * Generation to try next from a read of existing locks. Advisory only: the
 * acquisition transaction re-checks everything and the lock doc is created
 * with `create`, so two workers picking the same generation cannot both win.
 */
export function nextGenerationToTry(knownLocks) {
  let highest = null;
  for (const lock of knownLocks) if (highest === null || lock.generation > highest.generation) highest = lock;
  if (highest === null) return { ok: true, generation: 1 };
  if (!highest.released) return { ok: false, reason: "lock_held", generation: highest.generation };
  return { ok: true, generation: highest.generation + 1 };
}

/**
 * Acquisition, decided inside a transaction that read the target lock doc,
 * the previous generation's release doc, this run's claim doc and — for a
 * rollback — the target apply run's claim doc. The lock and the run claim are
 * both created with `create`, so a reused run id fails. Apply locks require a
 * validated plan and are bound to its digest; rollback locks are bound to the
 * digest recorded by the apply run they target. Ages, heartbeats and clocks
 * are not inputs: a lock is never considered stale automatically.
 */
export function decideLockAcquisition({ writer, identity, validatedPlan, current, previousRelease, runClaim, targetRun }) {
  const deny = (reason) => ({ acquire: false, reason });
  const problem = writerProblem(writer);
  if (problem) return deny(problem);
  if (identityProblems(identity).length > 0) return deny("identity_invalid");
  if (writer.kind === "apply") {
    if (!isValidatedPlan(validatedPlan)) return deny("plan_not_validated");
    if (validatedPlan.digest !== writer.planDigest) return deny("plan_digest_mismatch");
    if (canonicalJson(validatedPlan.identity) !== canonicalJson(identity)) return deny("identity_mismatch");
  }
  if (current?.exists !== false) return deny(current?.exists === true ? "generation_taken" : "lock_state_unknown");
  if (writer.generation > 1 && previousRelease?.exists !== true) return deny("previous_generation_not_released");
  if (runClaim?.exists !== false) return deny(runClaim?.exists === true ? "run_id_reused" : "run_state_unknown");
  if (writer.kind === "rollback") {
    if (targetRun?.exists !== true || !isPlainObject(targetRun.data)) return deny("rollback_target_missing");
    const target = targetRun.data;
    if (
      target.kind !== "apply" ||
      target.runId !== writer.targetRunId ||
      target.planDigest !== writer.planDigest ||
      target.projectId !== identity.projectId ||
      target.databaseId !== identity.databaseId
    ) {
      return deny("rollback_target_invalid");
    }
  }
  const targetRunId = writer.kind === "rollback" ? writer.targetRunId : null;
  return {
    acquire: true,
    lockPath: lockPaths(writer.generation).lock,
    runPath: runPaths(writer.runId).run,
    lockData: {
      generation: writer.generation,
      runId: writer.runId,
      kind: writer.kind,
      planDigest: writer.planDigest,
      targetRunId,
      schemaVersion: RECORD_SCHEMA_VERSION,
    },
    runData: {
      runId: writer.runId,
      kind: writer.kind,
      generation: writer.generation,
      planDigest: writer.planDigest,
      targetRunId,
      projectId: identity.projectId,
      databaseId: identity.databaseId,
      schemaVersion: RECORD_SCHEMA_VERSION,
    },
  };
}

export function abandonConfirmationToken(generation, runId) {
  return `release-meeting-link-lock:${lockId(generation)}:${runId}`;
}

/**
 * Release, decided inside a transaction that read the lock and its release
 * doc. The owner releases its own lock; anyone else may only release it as
 * `operator_abandoned` with explicit human confirmation and the exact token.
 */
export function decideLockRelease({ lock, release, request }) {
  if (!lock?.exists || !isPlainObject(lock.data)) return { release: false, reason: "lock_missing" };
  if (release?.exists !== false) return { release: false, reason: release?.exists ? "already_released" : "release_state_unknown" };
  const reason = request?.reason;
  if (!RELEASE_REASONS.includes(reason)) return { release: false, reason: "release_reason_invalid" };
  const { generation, runId } = lock.data;
  if (reason === "operator_abandoned") {
    if (request.humanConfirmed !== true || request.confirmation !== abandonConfirmationToken(generation, runId)) {
      return { release: false, reason: "human_confirmation_required" };
    }
  } else if (request.runId !== runId) {
    return { release: false, reason: "not_lock_owner" };
  }
  return { release: true, data: { generation, lockRunId: runId, reason, schemaVersion: RECORD_SCHEMA_VERSION } };
}

// ── transactional evidence and fencing ─────────────────────────────────────

/** Exact read set for one apply write: source, target, the writer's lock, release and own stop doc. */
export function applyEvidencePaths({ writer, halaqaId }) {
  const lock = lockPaths(writer.generation);
  return {
    halaqa: `halaqat/${halaqaId}`,
    canonical: `halaqaMeetingLinks/${halaqaId}`,
    lock: lock.lock,
    release: lock.release,
    stop: runPaths(writer.runId).stop,
  };
}

/**
 * Exact read set for one rollback decision: the target doc, the apply run's
 * manifest entry and observed record, this rollback's own record, and the
 * rollback writer's lock, release and own stop doc (not the apply run's).
 */
export function rollbackEvidencePaths({ writer, halaqaId }) {
  const lock = lockPaths(writer.generation);
  const target = runPaths(writer.targetRunId);
  return {
    canonical: `halaqaMeetingLinks/${halaqaId}`,
    entry: target.entry(halaqaId),
    observed: target.observed(halaqaId),
    rollbackRecord: target.rollbackRecord(writer.runId, halaqaId),
    lock: lock.lock,
    release: lock.release,
    stop: runPaths(writer.runId).stop,
  };
}

/** null when the connection names exactly the plan's project and database. */
export function connectionTargetProblem(identity, connection) {
  if (!isPlainObject(connection) || !sameKeys(connection, ["databaseId", "projectId"])) return "connection_target_unknown";
  if (typeof connection.projectId !== "string" || typeof connection.databaseId !== "string") return "connection_target_unknown";
  if (connection.projectId !== identity?.projectId || connection.databaseId !== identity?.databaseId) {
    return "connection_target_mismatch";
  }
  return null;
}

function fenceReason(writer, { lock, release, stop }) {
  if (!lock.exists) return "lock_missing";
  if (!isPlainObject(lock.data) || !sameKeys(lock.data, LOCK_KEYS)) return "lock_schema_invalid";
  const data = lock.data;
  if (data.runId !== writer.runId) return "lock_owner_mismatch";
  if (data.kind !== writer.kind) return "lock_kind_mismatch";
  if (data.generation !== writer.generation) return "stale_worker";
  if (data.planDigest !== writer.planDigest) return "lock_plan_mismatch";
  if (data.targetRunId !== (writer.kind === "rollback" ? writer.targetRunId : null)) return "lock_target_mismatch";
  if (release.exists) return "lock_released";
  if (stop.exists) return "stop_requested";
  return null;
}

/**
 * Checks a read set `{ transactionId, connection: { projectId, databaseId },
 * docs: { [path]: { exists, data, createTime, updateTime } } }` against the
 * exact expected paths and the writer's fence. Returns
 * { status: "ok", views } | { status: "rejected" | "fenced", reason }.
 *
 * The adapter must build the read set from reads made inside the same
 * transaction as the write and fill `connection` from the SDK's actual
 * target; this function cannot verify either and only rejects evidence that
 * is absent, extra or inconsistent.
 */
export function checkTransactionalEvidence({ writer, kind, readSet, paths, identity }) {
  const rejected = (reason) => ({ status: "rejected", reason });
  const problem = writerProblem(writer, kind);
  if (problem) return rejected(problem);
  if (!isPlainObject(readSet) || !isPlainObject(readSet.docs)) return rejected("missing_transactional_evidence");
  if (typeof readSet.transactionId !== "string" || readSet.transactionId === "") return rejected("missing_transactional_evidence");
  const target = connectionTargetProblem(identity, readSet.connection);
  if (target) return rejected(target);
  const expected = new Set(Object.values(paths));
  for (const path of Object.keys(readSet.docs)) if (!expected.has(path)) return rejected("unexpected_evidence");
  const views = {};
  for (const [role, path] of Object.entries(paths)) {
    const view = hasOwn(readSet.docs, path) ? readSet.docs[path] : undefined;
    if (!isPlainObject(view) || typeof view.exists !== "boolean") return rejected("missing_transactional_evidence");
    views[role] = view;
  }
  const fence = fenceReason(writer, views);
  if (fence) return { status: "fenced", reason: fence };
  return { status: "ok", views };
}

// ── outcomes ───────────────────────────────────────────────────────────────

/**
 * The one outcome vocabulary for candidates. Every outcome maps to exactly one
 * class; anything else is a contract violation, and a candidate without an
 * outcome is `notAttempted`. Only `created` and `skipped` are compatible with
 * a clean completion.
 */
export const CANDIDATE_OUTCOMES = Object.freeze({
  migrated: "created",
  committedAfterAmbiguity: "created",
  halaqaGone: "skipped",
  canonicalAppeared: "skipped",
  changedSinceReview: "skipped",
  legacyNoLongerValid: "skipped",
  metadataUnavailable: "skipped",
  fenced: "stopped",
  planExpired: "stopped",
  failed: "failed",
  unresolved: "unresolved",
  contradictory: "contradictory",
  rejected: "contractViolation",
});
export const OUTCOME_CLASSES = Object.freeze([
  "created",
  "skipped",
  "stopped",
  "failed",
  "unresolved",
  "contradictory",
  "contractViolation",
  "notAttempted",
]);
const OUTCOME_KEYS = Object.freeze(["halaqaId", "outcome", "planDigest", "reason", "runId", "schemaVersion"]);

/** Per-record outcome document, stored create-only at runPaths(runId).outcome(halaqaId). */
export function outcomeRecordFields({ runId, halaqaId, planDigest, outcome, reason }) {
  return { halaqaId, runId, planDigest, outcome, reason: reason == null ? null : safeReason(reason), schemaVersion: RECORD_SCHEMA_VERSION };
}

export function validateOutcomeRecord(data, { runId, halaqaId, planDigest }) {
  if (!isPlainObject(data) || !sameKeys(data, OUTCOME_KEYS)) return "outcome_schema_invalid";
  if (data.schemaVersion !== RECORD_SCHEMA_VERSION) return "outcome_schema_invalid";
  if (data.runId !== runId || data.halaqaId !== halaqaId || data.planDigest !== planDigest) return "outcome_identity_mismatch";
  if (!hasOwn(CANDIDATE_OUTCOMES, data.outcome)) return "outcome_unknown";
  if (data.reason !== null && !REASON_CODE.test(data.reason)) return "outcome_schema_invalid";
  return null;
}

// ── per-candidate write decision (inside the transaction) ──────────────────

/**
 * Decides one write from the transactional read set. The only write it can
 * allow is creating a canonical doc that is still absent, for a candidate of
 * the validated plan whose halaqa update time still equals the reviewed one
 * and whose legacy value is still valid, before the plan expires, while the
 * writer's lock (bound to the same plan digest) is valid and its own stop doc
 * is absent. Returns { write: true, outcomeIfCommitted, manifestEntry } or
 * { write: false, outcome, reason } using CANDIDATE_OUTCOMES.
 */
export function decideCandidateWrite({ validatedPlan, halaqaId, now, writer, readSet, legacyCategory }) {
  const no = (outcome, reason) => ({ write: false, outcome, reason });
  const records = VALIDATED_PLANS.get(validatedPlan);
  if (!records) return no("rejected", "plan_not_validated");
  const problem = writerProblem(writer, "apply");
  if (problem) return no("rejected", problem);
  if (writer.planDigest !== validatedPlan.digest) return no("rejected", "plan_digest_mismatch");
  if (!isValidDocumentId(halaqaId)) return no("rejected", "halaqa_id_invalid");
  const record = records.get(halaqaId);
  if (!record) return no("rejected", "candidate_not_in_plan");
  if (record.category !== "candidate") return no("rejected", "not_a_candidate");
  if (!Number.isSafeInteger(now)) return no("rejected", "now_invalid");
  if (now >= validatedPlan.expiresAt) return no("planExpired", "expired");
  if (now < validatedPlan.issuedAt - MAX_CLOCK_SKEW_MS) return no("planExpired", "issued_in_future");

  const evidence = checkTransactionalEvidence({
    writer,
    kind: "apply",
    readSet,
    paths: applyEvidencePaths({ writer, halaqaId }),
    identity: validatedPlan.identity,
  });
  if (evidence.status === "rejected") return no("rejected", evidence.reason);
  if (evidence.status === "fenced") return no("fenced", evidence.reason);
  const { halaqa, canonical } = evidence.views;

  if (!halaqa.exists) return no("halaqaGone", null);
  if (canonical.exists) return no("canonicalAppeared", null);
  const updateTime = timeKey(halaqa.updateTime);
  if (updateTime === null) return no("metadataUnavailable", null);
  if (updateTime !== record.halaqaUpdateTime) return no("changedSinceReview", null);
  if (!LEGACY_CATEGORIES.includes(legacyCategory)) return no("rejected", "legacy_category_invalid");
  if (legacyCategory !== "valid") return no("legacyNoLongerValid", legacyCategory);
  return {
    write: true,
    outcomeIfCommitted: "migrated",
    manifestEntry: manifestEntryFields({
      runId: writer.runId,
      halaqaId,
      planDigest: writer.planDigest,
      lockGeneration: writer.generation,
      legacyTrimmed: record.trimRequired,
    }),
  };
}

// ── manifest and observed-metadata records ─────────────────────────────────

const MANIFEST_KEYS = Object.freeze([
  "createdAt",
  "halaqaId",
  "legacyTrimmed",
  "lockGeneration",
  "planDigest",
  "priorCanonical",
  "runId",
  "schemaVersion",
]);
const OBSERVED_KEYS = Object.freeze(["canonicalCreateTime", "canonicalUpdateTime", "halaqaId", "runId", "schemaVersion"]);

/**
 * Manifest entry fields, created in the same transaction as the canonical
 * doc; the adapter adds `createdAt` as the same server timestamp the
 * canonical `updatedAt` uses. Never contains the link.
 */
export function manifestEntryFields({ runId, halaqaId, planDigest, lockGeneration, legacyTrimmed }) {
  return {
    halaqaId,
    runId,
    planDigest,
    lockGeneration,
    priorCanonical: "absent",
    legacyTrimmed: legacyTrimmed === true,
    schemaVersion: RECORD_SCHEMA_VERSION,
  };
}

export function validateManifestEntry(data, { runId, halaqaId, planDigest, lockGeneration }) {
  if (!isPlainObject(data) || !sameKeys(data, MANIFEST_KEYS)) return "manifest_schema_invalid";
  if (data.schemaVersion !== RECORD_SCHEMA_VERSION) return "manifest_schema_invalid";
  if (data.runId !== runId || data.halaqaId !== halaqaId) return "manifest_identity_mismatch";
  if (!isSha256Hex(data.planDigest)) return "manifest_schema_invalid";
  if (data.planDigest !== planDigest) return "manifest_plan_mismatch";
  if (!Number.isSafeInteger(data.lockGeneration) || data.lockGeneration < 1) return "manifest_schema_invalid";
  if (lockGeneration !== undefined && data.lockGeneration !== lockGeneration) return "manifest_generation_mismatch";
  if (typeof data.legacyTrimmed !== "boolean") return "manifest_schema_invalid";
  if (data.priorCanonical !== "absent") return "manifest_prior_state_invalid";
  if (timeKey(data.createdAt) === null) return "manifest_schema_invalid";
  return null;
}

/**
 * Observed metadata, captured by a read after the commit and stored
 * create-only. Returns null when the canonical doc or its metadata is
 * missing. An observed record alone never makes a doc rollback-eligible.
 */
export function observedRecordFields({ runId, halaqaId, canonical }) {
  const createTime = timeKey(canonical?.createTime);
  const updateTime = timeKey(canonical?.updateTime);
  if (!canonical?.exists || createTime === null || updateTime === null) return null;
  return { halaqaId, runId, canonicalCreateTime: createTime, canonicalUpdateTime: updateTime, schemaVersion: RECORD_SCHEMA_VERSION };
}

function observedProblem(data, { runId, halaqaId }) {
  if (!isPlainObject(data) || !sameKeys(data, OBSERVED_KEYS)) return "observed_schema_invalid";
  if (data.schemaVersion !== RECORD_SCHEMA_VERSION) return "observed_schema_invalid";
  if (data.runId !== runId || data.halaqaId !== halaqaId) return "observed_identity_mismatch";
  if (!isTimeKey(data.canonicalCreateTime) || !isTimeKey(data.canonicalUpdateTime)) return "observed_schema_invalid";
  return null;
}

function canonicalSchemaProblem(data) {
  if (!isPlainObject(data) || !sameKeys(data, ["meetingLink", "updatedAt"])) return "canonical_schema_changed";
  if (typeof data.meetingLink !== "string" || timeKey(data.updatedAt) === null) return "canonical_schema_changed";
  return null;
}

// ── ambiguous commits ──────────────────────────────────────────────────────

/**
 * Error code → handling. Anything not known to be a clean pre-commit failure
 * is treated as ambiguous: the commit may have happened, so the manifest
 * entry decides.
 */
export function classifyErrorCode(code) {
  if (code === "permission-denied" || code === "unauthenticated") return "fatalAuthorization";
  if (code === "aborted" || code === "resource-exhausted") return "transient";
  if (code === "failed-precondition") return "precondition";
  return "ambiguous";
}

/**
 * Canonical state as seen after a commit, compared with the manifest entry's
 * server timestamp. Reports what is there now; it never claims the doc still
 * holds what the migration wrote.
 */
function canonicalStateAfterCommit(canonical, entryCreatedAt) {
  if (!canonical?.exists) return "absentAfterCommit";
  const createTime = timeKey(canonical.createTime);
  const updateTime = timeKey(canonical.updateTime);
  if (createTime === null || updateTime === null) return "metadataUnavailable";
  if (createTime !== updateTime) return "presentModified";
  if (timeKey(canonical.data?.updatedAt) !== timeKey(entryCreatedAt)) return "presentReplaced";
  return "presentUnmodified";
}

/**
 * Resolves a write whose transaction outcome is unknown. Three evidence
 * levels, none of which authorizes a write or a delete:
 * - `committedVerified` (outcome committedAfterAmbiguity): a valid manifest
 *   entry for this run, plan digest and generation exists, and the canonical
 *   doc does not predate it;
 * - `notProvenCommitted` (outcome unresolved): no entry. That does not prove
 *   nothing was written — an entry can be missing because it was deleted —
 *   so the record is never retried blindly; it needs a re-plan;
 * - `contradictory`: an entry exists but does not match this writer, or the
 *   canonical doc's createTime is earlier than the entry's.
 */
export function resolveUncertainCommit({ writer, halaqaId, entry, canonical }) {
  const result = (outcome, evidence, reason, extra = {}) => ({
    outcome,
    evidence,
    reason,
    authorizesWrite: false,
    authorizesDelete: false,
    ...extra,
  });
  const problem = writerProblem(writer, "apply");
  if (problem) return result("contradictory", "contradictory", problem);
  if (typeof entry?.exists !== "boolean" || typeof canonical?.exists !== "boolean") {
    return result("unresolved", "notProvenCommitted", "evidence_unavailable", { action: "replan" });
  }
  if (!entry.exists) {
    const reason = canonical.exists ? "manifest_absent_canonical_present" : "manifest_absent_canonical_absent";
    return result("unresolved", "notProvenCommitted", reason, { action: "replan" });
  }
  const entryProblem = validateManifestEntry(entry.data, {
    runId: writer.runId,
    halaqaId,
    planDigest: writer.planDigest,
    lockGeneration: writer.generation,
  });
  if (entryProblem) return result("contradictory", "contradictory", entryProblem);
  const entryCreate = timeKey(entry.createTime);
  const canonicalCreate = timeKey(canonical.createTime);
  if (canonical.exists && entryCreate !== null && canonicalCreate !== null && nanosOf(canonicalCreate) < nanosOf(entryCreate)) {
    return result("contradictory", "contradictory", "canonical_predates_manifest");
  }
  return result("committedAfterAmbiguity", "committedVerified", null, {
    canonicalState: canonicalStateAfterCommit(canonical, entry.data.createdAt),
  });
}

// ── rollback ───────────────────────────────────────────────────────────────

/**
 * Upper bound between the manifest entry's createTime and the observed
 * record's createTime. A later observation could have been taken after an
 * admin replaced the doc, so it proves nothing about this run's doc.
 */
export const OBSERVATION_MAX_DELAY_MS = 60_000;

/**
 * Proof kinds that would show no admin re-saved the same link between the
 * migration and the rollback. None exists: an unchanged save through
 * setHalaqaMeetingLinkCore returns before any write or audit entry, so it is
 * indistinguishable from no action. Adding a kind here requires an approved
 * backend audit change or an attested write freeze — not a code edit alone.
 */
export const APPROVED_INTERVENING_ACTION_PROOFS = Object.freeze([]);

/**
 * Whether the stored evidence is complete and consistent for one doc. All of:
 * manifest entry (run, plan digest) and observed record exist with metadata;
 * observed record was taken within the delay bound of the entry and shows the
 * same incarnation (createTime equal to the entry's); the canonical doc is
 * that incarnation, never updated, with exactly the canonical schema and
 * `updatedAt` equal to the entry's `createdAt`; no rollback record yet.
 * Complete evidence still cannot see an unchanged admin save.
 */
export function rollbackEvidence({
  targetRunId,
  planDigest,
  halaqaId,
  entry,
  observed,
  canonical,
  rollbackRecord,
  maxObservationDelayMs = OBSERVATION_MAX_DELAY_MS,
}) {
  const gap = (reason) => ({ complete: false, reason });
  if (!Number.isSafeInteger(maxObservationDelayMs) || maxObservationDelayMs < 0 || maxObservationDelayMs > OBSERVATION_MAX_DELAY_MS) {
    return gap("observation_window_invalid");
  }
  for (const view of [entry, observed, canonical, rollbackRecord]) {
    if (typeof view?.exists !== "boolean") return gap("evidence_invalid");
  }
  if (!entry.exists) return gap("manifest_missing");
  const entryProblem = validateManifestEntry(entry.data, { runId: targetRunId, halaqaId, planDigest });
  if (entryProblem) return gap(entryProblem);
  if (!observed.exists) return gap("observed_missing");
  const observedIssue = observedProblem(observed.data, { runId: targetRunId, halaqaId });
  if (observedIssue) return gap(observedIssue);
  if (rollbackRecord.exists) return gap("already_rolled_back");
  if (!canonical.exists) return gap("canonical_missing");

  const createTime = timeKey(canonical.createTime);
  const updateTime = timeKey(canonical.updateTime);
  const entryCreate = timeKey(entry.createTime);
  const observedCreate = timeKey(observed.createTime);
  if (createTime === null || updateTime === null || entryCreate === null || observedCreate === null) {
    return gap("metadata_unavailable");
  }
  if (observed.data.canonicalCreateTime !== observed.data.canonicalUpdateTime) return gap("observed_not_pristine");
  if (createTime !== updateTime) return gap("modified_since_creation");
  if (createTime !== observed.data.canonicalCreateTime) return gap("create_time_mismatch");
  if (observed.data.canonicalCreateTime !== entryCreate) return gap("observed_incarnation_unproven");
  const delay = nanosOf(observedCreate) - nanosOf(entryCreate);
  if (delay < 0n) return gap("observation_before_commit");
  if (delay > BigInt(maxObservationDelayMs) * 1_000_000n) return gap("observation_late");
  const schema = canonicalSchemaProblem(canonical.data);
  if (schema) return gap(schema);
  if (timeKey(canonical.data.updatedAt) !== timeKey(entry.data.createdAt)) return gap("updated_at_mismatch");
  return { complete: true, reason: null };
}

/**
 * Rollback decision for one doc. It checks the fence and read set, then the
 * evidence, then an intervening-action proof. Because no proof kind is
 * approved, it always returns { delete: false, outcome: "skipped" } (or
 * fenced/rejected) with a forward-fix recommendation; `evidenceComplete`
 * tells an operator which docs a future, approved proof could unlock.
 */
export function decideRollbackDelete({ writer, halaqaId, readSet, identity, interveningActionProof, maxObservationDelayMs }) {
  const no = (outcome, reason, extra = {}) => ({ delete: false, outcome, reason, recommendation: "forward_fix", ...extra });
  const problem = writerProblem(writer, "rollback");
  if (problem) return no("rejected", problem);
  if (!isValidDocumentId(halaqaId)) return no("rejected", "halaqa_id_invalid");
  if (identityProblems(identity).length > 0) return no("rejected", "identity_invalid");
  const paths = rollbackEvidencePaths({ writer, halaqaId });
  const checked = checkTransactionalEvidence({ writer, kind: "rollback", readSet, paths, identity });
  if (checked.status === "rejected") return no("rejected", checked.reason);
  if (checked.status === "fenced") return no("fenced", checked.reason);
  const evidence = rollbackEvidence({
    targetRunId: writer.targetRunId,
    planDigest: writer.planDigest,
    halaqaId,
    ...checked.views,
    maxObservationDelayMs,
  });
  if (!evidence.complete) return no("skipped", evidence.reason, { evidenceComplete: false });
  if (interveningActionProof === undefined || interveningActionProof === null) {
    return no("skipped", "admin_resave_unprovable", { evidenceComplete: true });
  }
  if (!APPROVED_INTERVENING_ACTION_PROOFS.includes(interveningActionProof?.kind)) {
    return no("skipped", "proof_kind_not_approved", { evidenceComplete: true });
  }
  return no("skipped", "proof_verification_unimplemented", { evidenceComplete: true });
}

// ── run summary ────────────────────────────────────────────────────────────

const PRE_EXISTING = new Set(["alreadyMigrated", "conflict", "canonicalMalformed", "canonicalWithoutValidLegacy", "orphanCanonical"]);
const SUMMARY_KEYS = Object.freeze([
  "byClass",
  "byOutcome",
  "candidates",
  "contractViolations",
  "needsReview",
  "noLink",
  "preExisting",
  "reasons",
  "unexpectedOutcomes",
]);

/**
 * Count-only report for one run over a validated plan. `outcomes` maps halaqa
 * ids to { outcome, reason }. Candidates without an outcome are
 * `notAttempted`; unknown outcomes, malformed entries and outcomes for ids
 * that are not candidates are contract violations. No ids, no values.
 */
export function summarizeRun({ validatedPlan, outcomes, createdByEarlierRuns }) {
  const records = VALIDATED_PLANS.get(validatedPlan);
  if (!records) return null;
  const earlier = new Set(createdByEarlierRuns ?? []);
  const lookup = outcomes instanceof Map ? outcomes : new Map(Object.entries(isPlainObject(outcomes) ? outcomes : {}));
  const summary = {
    candidates: 0,
    byClass: Object.fromEntries(OUTCOME_CLASSES.map((key) => [key, 0])),
    byOutcome: Object.fromEntries(Object.keys(CANDIDATE_OUTCOMES).map((key) => [key, 0])),
    reasons: {},
    preExisting: { createdByEarlierMigrationRun: 0, notFromMigration: 0 },
    noLink: 0,
    needsReview: Object.fromEntries(REVIEW_CATEGORIES.map((key) => [key, 0])),
    unexpectedOutcomes: 0,
    contractViolations: 0,
  };
  for (const record of records.values()) {
    if (PRE_EXISTING.has(record.category)) {
      if (earlier.has(record.halaqaId)) summary.preExisting.createdByEarlierMigrationRun += 1;
      else summary.preExisting.notFromMigration += 1;
    }
    if (REVIEW_CATEGORIES.includes(record.category)) summary.needsReview[record.category] += 1;
    if (record.category === "noLink") summary.noLink += 1;
    if (record.category !== "candidate") continue;
    summary.candidates += 1;
    if (!lookup.has(record.halaqaId)) {
      summary.byClass.notAttempted += 1;
      continue;
    }
    const entry = lookup.get(record.halaqaId);
    const outcome = isPlainObject(entry) ? entry.outcome : undefined;
    if (typeof outcome !== "string" || !hasOwn(CANDIDATE_OUTCOMES, outcome)) {
      summary.byClass.contractViolation += 1;
      continue;
    }
    summary.byClass[CANDIDATE_OUTCOMES[outcome]] += 1;
    summary.byOutcome[outcome] += 1;
    if (entry.reason != null) {
      const key = `${outcome}:${safeReason(entry.reason)}`;
      summary.reasons[key] = (summary.reasons[key] ?? 0) + 1;
    }
  }
  for (const id of lookup.keys()) {
    if (records.get(id)?.category !== "candidate") summary.unexpectedOutcomes += 1;
  }
  summary.contractViolations = summary.byClass.contractViolation + summary.unexpectedOutcomes;
  return summary;
}

const isCount = (value) => Number.isSafeInteger(value) && value >= 0;

function summaryProblem(summary) {
  if (!isPlainObject(summary) || !sameKeys(summary, SUMMARY_KEYS)) return "summary_invalid";
  if (!isPlainObject(summary.byClass) || !sameKeys(summary.byClass, OUTCOME_CLASSES)) return "summary_invalid";
  if (!isPlainObject(summary.needsReview) || !sameKeys(summary.needsReview, REVIEW_CATEGORIES)) return "summary_invalid";
  const counts = [
    summary.candidates,
    summary.contractViolations,
    summary.unexpectedOutcomes,
    ...Object.values(summary.byClass),
    ...Object.values(summary.needsReview),
  ];
  if (!counts.every(isCount)) return "summary_invalid";
  const classTotal = Object.values(summary.byClass).reduce((sum, n) => sum + n, 0);
  if (classTotal !== summary.candidates) return "summary_inconsistent";
  if (summary.contractViolations !== summary.byClass.contractViolation + summary.unexpectedOutcomes) return "summary_inconsistent";
  return null;
}

const reviewTotal = (summary) => Object.values(summary.needsReview).reduce((sum, n) => sum + n, 0);

/**
 * Terminal state implied by a verification result. Fails closed: a missing,
 * malformed or inconsistent summary, any contract violation, contradictory
 * evidence or invariant violation is FAILED_FATAL; any stopped write is
 * STOPPED_OPERATOR; failed, unresolved or not-attempted candidates are
 * STOPPED_TRANSIENT. Only then COMPLETED or COMPLETED_REVIEW_REQUIRED.
 */
export function completionVerdict(summary, invariantViolations) {
  if (invariantViolations !== 0) return { state: S.FAILED_FATAL, reason: "verification_failed" };
  const problem = summaryProblem(summary);
  if (problem) return { state: S.FAILED_FATAL, reason: problem };
  if (summary.contractViolations > 0) return { state: S.FAILED_FATAL, reason: "contract_violation" };
  if (summary.byClass.contradictory > 0) return { state: S.FAILED_FATAL, reason: "contradictory_evidence" };
  if (summary.byClass.stopped > 0) return { state: S.STOPPED_OPERATOR, reason: "writes_stopped" };
  if (summary.byClass.failed > 0 || summary.byClass.unresolved > 0 || summary.byClass.notAttempted > 0) {
    return { state: S.STOPPED_TRANSIENT, reason: "incomplete_candidates" };
  }
  if (reviewTotal(summary) > 0) return { state: S.COMPLETED_REVIEW_REQUIRED, reason: "review_required" };
  return { state: S.COMPLETED, reason: null };
}

// ── run states ─────────────────────────────────────────────────────────────

export const RUN_STATES = Object.freeze({
  NOT_STARTED: "NOT_STARTED",
  RUNNING: "RUNNING",
  VERIFYING: "VERIFYING",
  COMPLETED: "COMPLETED",
  COMPLETED_REVIEW_REQUIRED: "COMPLETED_REVIEW_REQUIRED",
  STOPPED_TRANSIENT: "STOPPED_TRANSIENT",
  STOPPED_OPERATOR: "STOPPED_OPERATOR",
  FAILED_FATAL: "FAILED_FATAL",
  ABANDONED: "ABANDONED",
});
const S = RUN_STATES;
const ALL_STATES = Object.freeze(Object.values(S));
export const TERMINAL_STATES = Object.freeze([
  S.COMPLETED,
  S.COMPLETED_REVIEW_REQUIRED,
  S.STOPPED_TRANSIENT,
  S.STOPPED_OPERATOR,
  S.FAILED_FATAL,
  S.ABANDONED,
]);
/** Fatal reasons after which nothing may be written: the target or the credential is in doubt. */
export const NO_WRITE_FATAL_REASONS = Object.freeze(["identity_mismatch", "permission_denied", "unauthenticated", "egress_blocked"]);
const ACTIVE = new Set([S.RUNNING, S.VERIFYING]);

/**
 * Run-state transition. Returns { ok, state, writeEvent, reason }.
 * `writeEvent` false means the transition must not be recorded in Firestore.
 * `verified` carries { summary, invariantViolations } and lands on the state
 * completionVerdict derives; callers cannot choose it.
 */
export function transitionRun(state, event) {
  const to = (next, reason = null, writeEvent = true) => ({ ok: true, state: next, writeEvent, reason });
  if (!ALL_STATES.includes(state)) return { ok: false, state, writeEvent: false, reason: "unknown_state" };
  if (TERMINAL_STATES.includes(state)) return { ok: false, state, writeEvent: false, reason: "terminal_state" };
  const type = event?.type;
  if (state === S.NOT_STARTED && type === "start") return to(S.RUNNING);
  if (state === S.RUNNING && type === "heartbeat") return to(S.RUNNING);
  if (state === S.RUNNING && type === "candidatesFinal") return to(S.VERIFYING);
  if (state === S.RUNNING && type === "transientLimit") return to(S.STOPPED_TRANSIENT, "transient_limit");
  if (state === S.VERIFYING && type === "verified") {
    const verdict = completionVerdict(event.summary, event.invariantViolations);
    return to(verdict.state, verdict.reason);
  }
  if (ACTIVE.has(state) && type === "stopObserved") return to(S.STOPPED_OPERATOR, "stop_requested");
  if (ACTIVE.has(state) && type === "fatal") {
    const reason = typeof event.reason === "string" ? event.reason : "unknown";
    return to(S.FAILED_FATAL, reason, !NO_WRITE_FATAL_REASONS.includes(reason));
  }
  if (ACTIVE.has(state) && type === "operatorAbandoned") return to(S.ABANDONED, "operator_abandoned");
  return { ok: false, state, writeEvent: false, reason: "invalid_transition" };
}

export const isCleanCompletion = (state) => state === S.COMPLETED;

// ── release gate ───────────────────────────────────────────────────────────

export const DISPOSITIONS = Object.freeze(["fixed_via_callable", "accepted_no_link", "owner_accepted_divergence"]);
const DEPLOYMENT_CHECKS = Object.freeze(["rulesVerified", "functionsRevisionVerified", "productionBackendFlagVerified"]);

/**
 * Whether the canonical-only client may ship. Requires a completed run whose
 * recorded state matches the verdict recomputed from its summary, a recorded
 * disposition for every review finding, and externally recorded deployment
 * checks (deployed rules, Functions revision, PRODUCTION_BACKEND_ENABLED) —
 * this function does not and cannot verify those itself.
 * COMPLETED_REVIEW_REQUIRED is never a clean completion.
 */
export function releaseGateDecision({ runState, summary, reviewFindings, dispositions, verification, deployment }) {
  const blockers = new Set();
  const findings = Array.isArray(reviewFindings) ? reviewFindings : [];
  if (runState !== S.COMPLETED && runState !== S.COMPLETED_REVIEW_REQUIRED) blockers.add("run_not_completed");
  if (!(verification?.invariantViolations === 0)) blockers.add("verification_failed");
  const verdict = completionVerdict(summary, verification?.invariantViolations);
  if (verdict.state !== runState) blockers.add("state_summary_mismatch");
  if (summaryProblem(summary) === null && reviewTotal(summary) !== findings.length) blockers.add("findings_count_mismatch");
  for (const finding of findings) {
    if (!REVIEW_CATEGORIES.includes(finding?.category)) blockers.add("finding_category_unknown");
    else if (!DISPOSITIONS.includes(dispositions?.[finding.halaqaId])) blockers.add(`unresolved_review:${finding.category}`);
  }
  for (const check of DEPLOYMENT_CHECKS) if (deployment?.[check] !== true) blockers.add(`deployment_unverified:${check}`);
  const list = [...blockers].sort();
  return { allowCanonicalOnlyRelease: list.length === 0, blockers: list };
}
