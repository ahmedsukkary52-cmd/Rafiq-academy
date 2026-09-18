/**
 * WA-15 / C14 student lifecycle unit tests (no Firebase emulator).
 *
 * Run: cd functions && npm run build && npm run test:wa15
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const srcDir = join(repoRoot, "functions", "src");

const contract = require("../lib/lifecycle/studentLifecycleContract.js");
const transition = require("../lib/lifecycle/studentLifecycleTransition.js");

const lifecycleSource = readFileSync(
  join(srcDir, "lifecycle", "studentLifecycleFunctions.ts"),
  "utf8",
);

/** Executable code only — the file's contract documentation names the very
 *  fields the callable is forbidden to write. */
function stripComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, "$1");
}

const lifecycleCode = stripComments(lifecycleSource);

function subject({ role = "student", lifecycle = undefined, profile } = {}) {
  return {
    user: role === null ? null : { role },
    profile: profile === null ? null : { lifecycle },
  };
}

// ── Contract ───────────────────────────────────────────────────────────────

test("WA-15 lifecycle has exactly two frozen values", () => {
  assert.deepEqual(contract.LIFECYCLE_VALUES, ["active", "archived"]);
  assert.equal(contract.LIFECYCLE_ACTIVE, "active");
  assert.equal(contract.LIFECYCLE_ARCHIVED, "archived");
  assert.deepEqual(contract.LIFECYCLE_ACTIONS, ["archive", "unarchive"]);
});

test("WA-15 missing or malformed lifecycle reads as active (no migration)", () => {
  for (const raw of [undefined, null, "", "   ", 42, {}, [], "ACTIVE", "deleted"]) {
    assert.equal(contract.normalizeLifecycle(raw), "active");
  }
  assert.equal(contract.normalizeLifecycle("archived"), "archived");
  assert.equal(contract.normalizeLifecycle(" archived "), "archived");
});

test("WA-15 only archive/unarchive are accepted actions", () => {
  assert.equal(contract.parseLifecycleAction("archive"), "archive");
  assert.equal(contract.parseLifecycleAction("unarchive"), "unarchive");
  for (const raw of ["delete", "suspend", "", null, undefined, 1, "Archive"]) {
    assert.equal(contract.parseLifecycleAction(raw), null);
  }
});

// ── Transition decisions ───────────────────────────────────────────────────

test("WA-15 archive moves active → archived", () => {
  const decision = transition.decideLifecycleTransition({
    action: "archive",
    subject: subject({ lifecycle: "active" }),
  });
  assert.deepEqual(decision, {
    outcome: "transition",
    from: "active",
    to: "archived",
  });
});

test("WA-15 unarchive moves archived → active", () => {
  const decision = transition.decideLifecycleTransition({
    action: "unarchive",
    subject: subject({ lifecycle: "archived" }),
  });
  assert.deepEqual(decision, {
    outcome: "transition",
    from: "archived",
    to: "active",
  });
});

test("WA-15 archiving a student with no stored lifecycle still transitions", () => {
  const decision = transition.decideLifecycleTransition({
    action: "archive",
    subject: subject({ lifecycle: undefined }),
  });
  assert.equal(decision.outcome, "transition");
  assert.equal(decision.from, "active");
});

test("WA-15 repeated calls are idempotent no-ops, not errors", () => {
  const archiveAgain = transition.decideLifecycleTransition({
    action: "archive",
    subject: subject({ lifecycle: "archived" }),
  });
  assert.deepEqual(archiveAgain, { outcome: "noop", current: "archived" });

  const unarchiveAgain = transition.decideLifecycleTransition({
    action: "unarchive",
    subject: subject({ lifecycle: "active" }),
  });
  assert.deepEqual(unarchiveAgain, { outcome: "noop", current: "active" });
});

test("WA-15 archive → unarchive → archive round-trips deterministically", () => {
  let current = "active";
  for (const [action, expected] of [
    ["archive", "archived"],
    ["unarchive", "active"],
    ["archive", "archived"],
  ]) {
    const decision = transition.decideLifecycleTransition({
      action,
      subject: subject({ lifecycle: current }),
    });
    assert.equal(decision.outcome, "transition");
    assert.equal(decision.to, expected);
    current = decision.to;
  }
  assert.equal(current, "archived");
});

test("WA-15 the target must exist and must be a student", () => {
  assert.equal(
    transition.decideLifecycleTransition({
      action: "archive",
      subject: subject({ role: null }),
    }).reason,
    "student_not_found",
  );
  for (const role of ["teacher", "parent", "supervisor", "admin", "", null]) {
    assert.equal(
      transition.decideLifecycleTransition({
        action: "archive",
        subject: { user: { role }, profile: {} },
      }).reason,
      "not_a_student",
    );
  }
  assert.equal(
    transition.decideLifecycleTransition({
      action: "archive",
      subject: subject({ profile: null }),
    }).reason,
    "profile_not_found",
  );
});

// ── Isolation: archive touches lifecycle and nothing else ──────────────────

test("WA-15 the update payload is the lifecycle key and nothing else", () => {
  const update = transition.buildLifecycleUpdate("archived");
  assert.deepEqual(Object.keys(update), ["lifecycle"]);
  assert.equal(update.lifecycle, "archived");
  assert.equal(transition.isolationHolds(update), true);
});

test("WA-15 isolation guard rejects any co-written dimension", () => {
  for (const contaminated of [
    { lifecycle: "archived", isActive: false },
    { lifecycle: "archived", role: "student" },
    { lifecycle: "archived", halaqaId: null },
    { lifecycle: "archived", studentIds: [] },
    { lifecycle: "archived", paymentAccess: "suspended" },
  ]) {
    assert.equal(transition.isolationHolds(contaminated), false);
  }
});

test("WA-15 the callable never writes another dimension or deletes anything", () => {
  for (const forbidden of [
    "isActive",
    "paymentAccess",
    "studentIds",
    "arrayRemove",
    "arrayUnion",
    "recursiveDelete",
    "bulkWriter",
  ]) {
    assert.ok(
      !lifecycleCode.includes(forbidden),
      `adminSetStudentLifecycle must not reference ${forbidden}`,
    );
  }

  // Every Firestore mutation in the lifecycle callable body: profile updates
  // only. Audit appends go through the shared writeAuditLog helper.
  const mutations = [...lifecycleCode.matchAll(/\.(set|update|delete|create|add)\(/g)]
    .map((match) => match[1])
    .sort();
  assert.deepEqual(mutations, ["update", "update"]);

  assert.ok(
    lifecycleCode.includes("tx.update(profileRef, buildLifecycleUpdate("),
  );
  assert.ok(
    lifecycleCode.includes("profileRef.update(buildLifecycleUpdate(LIFECYCLE_ACTIVE))"),
  );
  assert.ok(lifecycleCode.includes("writeAuditLog("));
});

test("WA-15 does not cascade into halaqat (deferred D21 integration)", () => {
  assert.ok(!lifecycleCode.includes("halaqat"));
  assert.ok(!lifecycleCode.includes("halaqaId"));
  assert.ok(!lifecycleCode.includes("studentSearch"));
  assert.ok(
    lifecycleSource.includes("DEFERRED INTEGRATION"),
    "the deferred roster cascade must stay documented in the source",
  );
});

// ── Audit logging (WA-16 shared envelope) ──────────────────────────────────

const auditWrite = require("../lib/audit/auditLogWrite.js");
const auditContract = require("../lib/audit/auditLogContract.js");

test("WA-15 a real transition produces a C16 audit entry", () => {
  const entry = auditWrite.buildAuditLogEntry(
    {
      actor: auditWrite.adminActor("admin1"),
      action: contract.LIFECYCLE_AUDIT_ACTION.archive,
      targetType: auditContract.AUDIT_TARGET_TYPE.studentProfile,
      targetId: "stu1",
      metadata: {
        previousLifecycle: "active",
        newLifecycle: "archived",
      },
      source: "adminSetStudentLifecycle",
    },
    "SERVER_TS",
  );

  assert.equal(entry.action, "user_archive");
  assert.equal(entry.actorId, "admin1");
  assert.equal(entry.actorRole, "admin");
  assert.equal(entry.targetId, "stu1");
  assert.equal(entry.targetType, "studentProfile");
  assert.equal(entry.metadata.previousLifecycle, "active");
  assert.equal(entry.metadata.newLifecycle, "archived");
  assert.equal(entry.timestamp, "SERVER_TS");
  assert.equal(entry.source, "adminSetStudentLifecycle");
  assert.ok(!Object.prototype.hasOwnProperty.call(entry, "actorUid"));
  assert.ok(!Object.prototype.hasOwnProperty.call(entry, "createdAt"));
});

test("WA-15 archive and unarchive use distinct audit actions", () => {
  assert.notEqual(
    contract.LIFECYCLE_AUDIT_ACTION.archive,
    contract.LIFECYCLE_AUDIT_ACTION.unarchive,
  );
  assert.equal(contract.LIFECYCLE_AUDIT_ACTION.archive, "user_archive");
  assert.equal(contract.LIFECYCLE_AUDIT_ACTION.unarchive, "user_unarchive");
});

test("WA-15 no-ops are not audited", () => {
  // The callable only audits when the transaction reported a real change.
  assert.ok(
    lifecycleSource.includes("if (result.changed && result.from !== null)"),
    "audit must be conditional on an actual transition",
  );
});

// ── Authorization + gating + wiring ────────────────────────────────────────

test("WA-15 both callables are Admin-gated and production-gated", () => {
  assert.equal(
    [...lifecycleSource.matchAll(/assertCallerIsAdmin\(/g)].length,
    2,
  );
  assert.equal(
    [...lifecycleSource.matchAll(/assertBackendAllowed\(/g)].length,
    2,
  );
  assert.equal([...lifecycleSource.matchAll(/region: REGION/g)].length, 2);
  assert.ok(lifecycleSource.includes('const REGION = "europe-west1"'));
});

test("WA-15 callables are exported and the backfill is never auto-invoked", () => {
  const index = readFileSync(join(srcDir, "index.ts"), "utf8");
  assert.ok(index.includes("adminSetStudentLifecycle"));
  assert.ok(index.includes("adminBackfillStudentLifecycle"));

  // No trigger or scheduler anywhere calls the backfill.
  for (const file of ["index.ts"]) {
    const source = readFileSync(join(srcDir, file), "utf8");
    assert.ok(!source.includes("adminBackfillStudentLifecycle("));
  }
});

test("WA-15 the backfill never downgrades an archived student", () => {
  assert.ok(
    lifecycleSource.includes("buildLifecycleUpdate(LIFECYCLE_ACTIVE)"),
    "backfill stamps the default only",
  );
  assert.ok(
    lifecycleSource.includes("if (typeof raw === \"string\" && normalizeLifecycle(raw) === raw)"),
    "an already-valid stored value must be skipped",
  );
});

// ── Rules + WA-14 regression ───────────────────────────────────────────────

test("WA-15 Rules deny every client lifecycle write on studentProfiles", () => {
  const rules = readFileSync(join(repoRoot, "firestore.rules"), "utf8");
  const block = rules
    .split("match /studentProfiles/{studentId} {")[1]
    .split("    }")[0];

  assert.ok(block.includes("hasAny(['phone', 'lifecycle'])"));
  assert.ok(block.includes("allow create: if false;"));
  assert.ok(block.includes("allow delete: if false;"));
  // Phone privacy (D16) is preserved, not traded away.
  assert.ok(block.includes("hasExposedPhone"));
});

test("WA-15 lifecycle remains forbidden from the WA-14 studentSearch projection", () => {
  const searchContract = readFileSync(
    join(srcDir, "search", "studentSearchContract.ts"),
    "utf8",
  );
  const search = require("../lib/search/studentSearchContract.js");

  assert.ok(search.STUDENT_SEARCH_FORBIDDEN_FIELDS.includes("lifecycle"));
  assert.ok(!search.STUDENT_SEARCH_FIELDS.includes("lifecycle"));
  assert.ok(searchContract.includes('"lifecycle"'));

  // The projection writer must not learn about lifecycle either.
  const projectionSource = readFileSync(
    join(srcDir, "search", "studentSearchProjection.ts"),
    "utf8",
  );
  assert.ok(!projectionSource.includes("lifecycle"));

  const projection = require("../lib/search/studentSearchProjection.js");
  const built = projection.buildStudentSearchProjection({
    studentId: "stu1",
    user: { name: "أحمد", role: "student" },
    // A lifecycle value on the source must not propagate.
    profile: { name: "أحمد", halaqaId: "h1", lifecycle: "archived" },
    memberships: [{ halaqaId: "h1", name: "ح1", teacherId: "t1" }],
  });
  const doc = projection.buildStudentSearchDocument(built, "SERVER_TS");
  assert.ok(!Object.prototype.hasOwnProperty.call(doc, "lifecycle"));
  assert.ok(!JSON.stringify(doc).includes("archived"));
});
