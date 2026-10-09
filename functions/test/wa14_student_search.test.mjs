/**
 * WA-14 / C13 studentSearch projection unit tests (no Firebase emulator).
 *
 * Run: cd functions && npm run build && npm run test:wa14
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

const norm = require("../lib/search/arabicNormalization.js");
const contract = require("../lib/search/studentSearchContract.js");
const projection = require("../lib/search/studentSearchProjection.js");
const gate = require("../lib/search/projectionGate.js");

function withEnv(overrides, run) {
  const keys = [
    "PRODUCTION_BACKEND_ENABLED",
    "FUNCTIONS_EMULATOR",
    "GCLOUD_PROJECT",
    "GOOGLE_CLOUD_PROJECT",
    "FIREBASE_CONFIG",
  ];
  const previous = {};
  for (const key of keys) previous[key] = process.env[key];
  for (const key of keys) delete process.env[key];
  for (const [key, value] of Object.entries(overrides)) {
    process.env[key] = value;
  }
  try {
    run();
  } finally {
    for (const key of keys) {
      if (previous[key] === undefined) delete process.env[key];
      else process.env[key] = previous[key];
    }
  }
}

function halaqa(id, extra = {}) {
  return {
    halaqaId: id,
    name: `حلقة ${id}`,
    teacherId: `teacher_${id}`,
    supervisorId: `supervisor_${id}`,
    ...extra,
  };
}

function sources(overrides = {}) {
  return {
    studentId: "stu1",
    user: { name: "أحمد", role: "student" },
    profile: { name: "أحمد الملف", halaqaId: "h1" },
    memberships: [halaqa("h1")],
    ...overrides,
  };
}

// ── B. Arabic normalization ────────────────────────────────────────────────

test("WA-14 normalization matches every frozen vector", () => {
  assert.ok(norm.ARABIC_NORMALIZATION_VECTORS.length >= 16);
  for (const vector of norm.ARABIC_NORMALIZATION_VECTORS) {
    assert.equal(
      norm.normalizeArabicSearchText(vector.input),
      vector.expected,
      `vector "${vector.label}" diverged`,
    );
  }
});

test("WA-14 normalization keeps waw/yeh hamza unfolded", () => {
  assert.equal(norm.normalizeArabicSearchText("مؤمن"), "مؤمن");
  assert.equal(norm.normalizeArabicSearchText("رئيس"), "رئيس");
});

test("WA-14 normalization is idempotent and total", () => {
  for (const vector of norm.ARABIC_NORMALIZATION_VECTORS) {
    const once = norm.normalizeArabicSearchText(vector.input);
    assert.equal(norm.normalizeArabicSearchText(once), once);
  }
  // Malformed input must never throw inside a background trigger.
  assert.equal(norm.normalizeArabicSearchText(undefined), "");
  assert.equal(norm.normalizeArabicSearchText(null), "");
  assert.equal(norm.normalizeArabicSearchText(42), "");
  assert.equal(norm.normalizeArabicSearchText({}), "");
});

/** Renders a runtime string the way it appears inside a Dart single-quoted literal. */
function dartLiteral(value) {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/'/g, "\\'")
    .replace(/\$/g, "\\$")
    .replace(/\t/g, "\\t")
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r");
}

test("WA-14 Dart mirror declares the identical vector table", () => {
  const dart = readFileSync(
    join(repoRoot, "lib", "shared", "domain", "arabic_search_normalizer.dart"),
    "utf8",
  );
  for (const vector of norm.ARABIC_NORMALIZATION_VECTORS) {
    assert.ok(
      dart.includes(`input: '${dartLiteral(vector.input)}'`),
      `Dart vectors are missing input for "${vector.label}"`,
    );
    assert.ok(
      dart.includes(`expected: '${dartLiteral(vector.expected)}'`),
      `Dart vectors are missing expected for "${vector.label}"`,
    );
  }
  assert.ok(
    dart.includes(
      `static const int version = ${norm.ARABIC_NORMALIZATION_VERSION};`,
    ),
    "Dart normalization version must match the TypeScript writer",
  );
});

// ── A + I. Projection allowlist / leakage ──────────────────────────────────

test("WA-14 persisted document key set is exactly the frozen allowlist", () => {
  const built = projection.buildStudentSearchProjection(sources());
  const doc = projection.buildStudentSearchDocument(built, "SERVER_TS");
  assert.deepEqual(
    Object.keys(doc).sort(),
    projection.STUDENT_SEARCH_PERSISTED_KEYS,
  );
  assert.equal(Object.keys(doc).length, 9);
});

test("WA-14 no forbidden field can appear on a projection", () => {
  const built = projection.buildStudentSearchProjection(sources());
  const doc = projection.buildStudentSearchDocument(built, "SERVER_TS");
  for (const forbidden of contract.STUDENT_SEARCH_FORBIDDEN_FIELDS) {
    assert.ok(
      !Object.prototype.hasOwnProperty.call(doc, forbidden),
      `forbidden field "${forbidden}" leaked into studentSearch`,
    );
  }
});

test("WA-14 a new source field cannot propagate (explicit allowlist)", () => {
  const polluted = sources({
    user: {
      name: "أحمد",
      role: "student",
      phone: "01000000000",
      email: "a@test.com",
      nationalId: "29001010101010",
      someBrandNewField: "future",
    },
    profile: {
      name: "أحمد الملف",
      halaqaId: "h1",
      phone: "01111111111",
      paymentStatus: "suspended",
      notes: "private note",
    },
    memberships: [halaqa("h1", { phone: "0100", secretField: "x" })],
  });

  const built = projection.buildStudentSearchProjection(polluted);
  const doc = projection.buildStudentSearchDocument(built, "SERVER_TS");

  assert.deepEqual(
    Object.keys(doc).sort(),
    projection.STUDENT_SEARCH_PERSISTED_KEYS,
  );
  const serialized = JSON.stringify(doc);
  for (const secret of [
    "01000000000",
    "01111111111",
    "a@test.com",
    "29001010101010",
    "future",
    "private note",
    "suspended",
    "0100",
  ]) {
    assert.ok(
      !serialized.includes(secret),
      `sensitive value "${secret}" leaked into studentSearch`,
    );
  }
});

test("WA-14 the writer never reads userPrivate", () => {
  for (const file of [
    "studentSearchFunctions.ts",
    "studentSearchProjection.ts",
    "studentSearchContract.ts",
  ]) {
    const source = readFileSync(join(srcDir, "search", file), "utf8");
    assert.ok(
      !source.includes("userPrivate"),
      `${file} must never reference the phone vault`,
    );
  }
});

// ── A. Identity + name source ──────────────────────────────────────────────

test("WA-14 studentId equals the projection document id", () => {
  const built = projection.buildStudentSearchProjection(
    sources({ studentId: "  stu1  " }),
  );
  assert.equal(built.studentId, "stu1");
});

test("WA-14 name source is users.name then studentProfiles.name then empty", () => {
  assert.equal(
    projection.resolveStudentFullName({
      user: { name: "من users" },
      profile: { name: "من الملف" },
    }),
    "من users",
  );
  assert.equal(
    projection.resolveStudentFullName({
      user: { name: "   " },
      profile: { name: "من الملف" },
    }),
    "من الملف",
  );
  assert.equal(
    projection.resolveStudentFullName({ user: null, profile: null }),
    "",
  );
});

test("WA-14 an empty name still projects so Admin can repair it", () => {
  const built = projection.buildStudentSearchProjection(
    sources({ user: { name: "", role: "student" }, profile: { name: "" } }),
  );
  assert.equal(built.fullName, "");
  assert.equal(built.fullNameNormalized, "");
});

test("WA-14 only users.role decides directory membership", () => {
  assert.equal(
    projection.buildStudentSearchProjection(
      sources({ user: { name: "معلم", role: "teacher" } }),
    ),
    null,
  );
  assert.equal(
    projection.buildStudentSearchProjection(sources({ user: null })),
    null,
  );
});

// ── C. Membership derivation ───────────────────────────────────────────────

test("WA-14 halaqaIds and visibleTo derive only from halaqat rosters", () => {
  const built = projection.buildStudentSearchProjection(
    sources({ memberships: [halaqa("h2"), halaqa("h1")] }),
  );
  assert.deepEqual(built.halaqaIds, ["h1", "h2"]);
  assert.deepEqual(built.visibleTo, [
    "supervisor_h1",
    "supervisor_h2",
    "teacher_h1",
    "teacher_h2",
  ]);
});

test("WA-14 visibleTo never contains the student or a parent", () => {
  const built = projection.buildStudentSearchProjection(
    sources({ memberships: [halaqa("h1")] }),
  );
  assert.ok(!built.visibleTo.includes("stu1"));
  assert.ok(!built.visibleTo.some((uid) => uid.startsWith("parent")));
});

test("WA-14 visibleTo deduplicates a shared teacher/supervisor", () => {
  const built = projection.buildStudentSearchProjection(
    sources({
      memberships: [
        halaqa("h1", { teacherId: "same", supervisorId: "same" }),
        halaqa("h2", { teacherId: "same", supervisorId: "" }),
      ],
    }),
  );
  assert.deepEqual(built.visibleTo, ["same"]);
});

test("WA-14 a student with no halaqa stays projected with empty scope", () => {
  const built = projection.buildStudentSearchProjection(
    sources({ memberships: [] }),
  );
  assert.deepEqual(built.halaqaIds, []);
  assert.deepEqual(built.visibleTo, []);
  assert.equal(built.halaqaId, null);
  assert.equal(built.halaqaName, "");
});

test("WA-14 membership beyond the cap is flagged and defensively bounded", () => {
  const many = Array.from({ length: 25 }, (_, i) =>
    halaqa(`h${String(i).padStart(2, "0")}`),
  );
  const derived = projection.deriveMembership(many);

  assert.equal(derived.capExceeded, true);
  assert.equal(derived.truncated, true);
  assert.equal(derived.halaqaIds.length, contract.MAX_PROJECTED_HALAQA_IDS);
  assert.equal(derived.visibleTo.length, contract.MAX_PROJECTED_VISIBLE_TO);
});

test("WA-14 the normal cap stays 2 and is not flagged", () => {
  assert.equal(contract.MAX_HALAQA_MEMBERSHIPS, 2);
  const derived = projection.deriveMembership([halaqa("h1"), halaqa("h2")]);
  assert.equal(derived.capExceeded, false);
  assert.equal(derived.truncated, false);
});

// ── 6. Membership drift ────────────────────────────────────────────────────

test("WA-14 a stale primary pointer never grants authorization", () => {
  // Pointer claims h9; the roster only places the student in h1.
  const built = projection.buildStudentSearchProjection(
    sources({
      profile: { name: "أحمد", halaqaId: "h9" },
      memberships: [halaqa("h1")],
    }),
  );

  assert.ok(!built.halaqaIds.includes("h9"));
  assert.ok(!built.visibleTo.includes("teacher_h9"));
  assert.ok(!built.visibleTo.includes("supervisor_h9"));
  // Display falls back deterministically to the real membership.
  assert.equal(built.halaqaId, "h1");
  assert.equal(built.halaqaName, "حلقة h1");
});

test("WA-14 a valid pointer wins; otherwise the lowest-sorted membership", () => {
  assert.equal(
    projection.resolvePrimaryHalaqaId({
      pointer: "h2",
      halaqaIds: ["h1", "h2"],
    }),
    "h2",
  );
  assert.equal(
    projection.resolvePrimaryHalaqaId({
      pointer: "gone",
      halaqaIds: ["h1", "h2"],
    }),
    "h1",
  );
  assert.equal(
    projection.resolvePrimaryHalaqaId({ pointer: null, halaqaIds: ["h2"] }),
    "h2",
  );
  assert.equal(
    projection.resolvePrimaryHalaqaId({ pointer: "h1", halaqaIds: [] }),
    null,
  );
});

test("WA-14 a missing halaqa document keeps the id with an empty name", () => {
  const built = projection.buildStudentSearchProjection(
    sources({ memberships: [{ halaqaId: "h1" }] }),
  );
  assert.equal(built.halaqaId, "h1");
  assert.equal(built.halaqaName, "");
});

test("WA-14 malformed sources never throw", () => {
  assert.doesNotThrow(() => {
    projection.buildStudentSearchProjection({
      studentId: "stu1",
      user: { name: 42, role: "student" },
      profile: { name: [], halaqaId: {} },
      memberships: [
        { halaqaId: "", name: null, teacherId: 7 },
        { halaqaId: "h1", name: undefined, supervisorId: null },
      ],
    });
  });
  assert.equal(
    projection.buildStudentSearchProjection({
      studentId: "",
      user: { role: "student" },
      profile: null,
      memberships: [],
    }),
    null,
  );
});

// ── E. Idempotency / convergence ───────────────────────────────────────────

test("WA-14 an unchanged source event converges to noop (no timestamp churn)", () => {
  const built = projection.buildStudentSearchProjection(sources());
  const stored = projection.buildStudentSearchDocument(built, "OLD_TS");

  const decision = projection.decideStudentSearchWrite({
    sources: sources(),
    existing: stored,
  });
  assert.equal(decision.action, "noop");
});

test("WA-14 first materialization creates, a real change updates", () => {
  const create = projection.decideStudentSearchWrite({
    sources: sources(),
    existing: null,
  });
  assert.equal(create.action, "create");

  const stored = projection.buildStudentSearchDocument(
    create.projection,
    "OLD_TS",
  );
  const update = projection.decideStudentSearchWrite({
    sources: sources({ user: { name: "أحمد الجديد", role: "student" } }),
    existing: stored,
  });
  assert.equal(update.action, "update");
  assert.equal(update.projection.fullName, "أحمد الجديد");
});

test("WA-14 losing a halaqa updates scope but never deletes the row", () => {
  const withHalaqa = projection.buildStudentSearchProjection(sources());
  const stored = projection.buildStudentSearchDocument(withHalaqa, "OLD_TS");

  const decision = projection.decideStudentSearchWrite({
    sources: sources({ memberships: [] }),
    existing: stored,
  });
  assert.equal(decision.action, "update");
  assert.deepEqual(decision.projection.halaqaIds, []);
  assert.deepEqual(decision.projection.visibleTo, []);
});

test("WA-14 the projection is deleted only when the subject stops being a student", () => {
  const stored = projection.buildStudentSearchDocument(
    projection.buildStudentSearchProjection(sources()),
    "OLD_TS",
  );

  assert.equal(
    projection.decideStudentSearchWrite({
      sources: sources({ user: { name: "أحمد", role: "parent" } }),
      existing: stored,
    }).action,
    "delete",
  );
  assert.equal(
    projection.decideStudentSearchWrite({
      sources: sources({ user: null }),
      existing: stored,
    }).reason,
    "no_user",
  );
  // Nothing stored and nothing to store — still a noop, never a stray delete.
  assert.equal(
    projection.decideStudentSearchWrite({
      sources: sources({ user: null }),
      existing: null,
    }).action,
    "noop",
  );
});

test("WA-14 a normalization version bump forces a rewrite", () => {
  const stored = projection.buildStudentSearchDocument(
    projection.buildStudentSearchProjection(sources()),
    "OLD_TS",
  );
  stored.normalizationVersion = 0;

  assert.equal(
    projection.decideStudentSearchWrite({ sources: sources(), existing: stored })
      .action,
    "update",
  );
});

// ── D. Change-signature guards / fan-out classification ────────────────────

test("WA-14 irrelevant user and profile edits do not fan out", () => {
  assert.equal(
    projection.userProjectionFieldsChanged(
      { name: "أحمد", role: "student", isActive: true },
      { name: "أحمد", role: "student", isActive: false },
    ),
    false,
  );
  assert.equal(
    projection.userProjectionFieldsChanged(
      { name: "أحمد", role: "student" },
      { name: "أحمد الجديد", role: "student" },
    ),
    true,
  );
  assert.equal(
    projection.studentProfileProjectionFieldsChanged(
      { name: "أحمد", halaqaId: "h1", points: 10 },
      { name: "أحمد", halaqaId: "h1", points: 99 },
    ),
    false,
  );
  assert.equal(
    projection.studentProfileProjectionFieldsChanged(
      { name: "أحمد", halaqaId: "h1" },
      { name: "أحمد", halaqaId: "h2" },
    ),
    true,
  );
});

test("WA-14 halaqa writes are classified rename_only / recompute / none", () => {
  const base = {
    name: "حلقة الفجر",
    teacherId: "t1",
    supervisorId: "s1",
    studentIds: ["stu1"],
  };

  assert.equal(
    projection.classifyHalaqaChange({
      before: base,
      after: { ...base, meetingLink: "https://x" },
    }),
    "none",
  );
  assert.equal(
    projection.classifyHalaqaChange({
      before: base,
      after: { ...base, name: "حلقة الضحى" },
    }),
    "rename_only",
  );
  assert.equal(
    projection.classifyHalaqaChange({
      before: base,
      after: { ...base, teacherId: "t2" },
    }),
    "recompute",
  );
  assert.equal(
    projection.classifyHalaqaChange({
      before: base,
      after: { ...base, studentIds: ["stu1", "stu2"] },
    }),
    "recompute",
  );
  // A rename that also moves the roster is never the cheap path.
  assert.equal(
    projection.classifyHalaqaChange({
      before: base,
      after: { ...base, name: "جديدة", studentIds: [] },
    }),
    "recompute",
  );
  // Deletion still recomputes the former roster.
  assert.equal(
    projection.classifyHalaqaChange({ before: base, after: undefined }),
    "recompute",
  );
  assert.equal(
    projection.classifyHalaqaChange({ before: undefined, after: undefined }),
    "none",
  );
});

test("WA-14 roster changes affect the union of both rosters", () => {
  assert.deepEqual(
    projection.affectedStudentIds({
      before: { studentIds: ["a", "b"] },
      after: { studentIds: ["b", "c"] },
    }),
    ["a", "b", "c"],
  );
  assert.deepEqual(
    projection.affectedStudentIds({
      before: { studentIds: ["a"] },
      after: undefined,
    }),
    ["a"],
  );
});

// ── D. Gate + wiring ───────────────────────────────────────────────────────

test("WA-14 materialization stays blocked until B-BILLING is verified", () => {
  withEnv({}, () => {
    assert.equal(gate.resolveProjectionRunMode(), "blocked");
    assert.equal(gate.isProjectionRunAllowed("blocked"), false);
  });
  withEnv({ FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: "demo-rafiq-rules" }, () => {
    assert.equal(gate.resolveProjectionRunMode(), "emulator");
  });
  // The emulator against a real (or unresolved) project must stay blocked.
  withEnv({ FUNCTIONS_EMULATOR: "true", GCLOUD_PROJECT: "rafiq-academy" }, () => {
    assert.equal(gate.resolveProjectionRunMode(), "blocked");
  });
  withEnv({ FUNCTIONS_EMULATOR: "true" }, () => {
    assert.equal(gate.resolveProjectionRunMode(), "blocked");
  });
  withEnv({ PRODUCTION_BACKEND_ENABLED: "true" }, () => {
    assert.equal(gate.resolveProjectionRunMode(), "production");
  });
  // ALLOW_EMULATOR_BACKEND must never open the gate (WA-0).
  withEnv({ ALLOW_EMULATOR_BACKEND: "true" }, () => {
    assert.equal(gate.resolveProjectionRunMode(), "blocked");
  });
});

test("WA-14 background triggers never throw on a closed gate", () => {
  const source = readFileSync(
    join(srcDir, "search", "studentSearchFunctions.ts"),
    "utf8",
  );
  const triggerRegion = /onDocumentWritten\(\s*\{\s*region: REGION/g;
  assert.equal([...source.matchAll(triggerRegion)].length, 3);

  // assertBackendAllowed throws HttpsError — only the callable may invoke it.
  const [triggerBody, callableTail] = source.split(
    "adminBackfillStudentSearch = onCall",
  );
  assert.equal([...source.matchAll(/assertBackendAllowed\(/g)].length, 1);
  assert.ok(callableTail.includes("assertBackendAllowed("));
  assert.ok(!triggerBody.includes("assertBackendAllowed("));
  assert.equal(
    [...triggerBody.matchAll(/resolveProjectionRunMode\(\) === "blocked"/g)]
      .length,
    3,
  );
});

test("WA-14 no trigger writes back to a source collection", () => {
  const source = readFileSync(
    join(srcDir, "search", "studentSearchFunctions.ts"),
    "utf8",
  );
  for (const forbidden of [
    "collection(USERS_COLLECTION).doc(id).set",
    "collection(HALAQAT_COLLECTION).doc",
    "collection(STUDENT_PROFILES_COLLECTION).doc(id).set",
  ]) {
    assert.ok(!source.includes(forbidden), `unexpected source write: ${forbidden}`);
  }
});

test("WA-14 triggers and the backfill callable are exported", () => {
  const index = readFileSync(join(srcDir, "index.ts"), "utf8");
  for (const name of [
    "projectStudentSearchOnUserWrite",
    "projectStudentSearchOnProfileWrite",
    "projectStudentSearchOnHalaqaWrite",
    "adminBackfillStudentSearch",
  ]) {
    assert.ok(index.includes(name), `${name} is not exported`);
  }
});

test("WA-14 Rules scope reads by visibleTo, never by the pointer", () => {
  const rules = readFileSync(join(repoRoot, "firestore.rules"), "utf8");
  const block = rules
    .split("match /studentSearch/{studentId} {")[1]
    .split("    }")[0];

  assert.ok(block.includes("isAdmin()"));
  assert.ok(block.includes("uid() in resource.data.get('visibleTo', [])"));
  assert.ok(block.includes("allow write: if false;"));
  assert.ok(!block.includes("studentProfiles"));
  assert.ok(!block.includes("allow read: if signedIn();"));
});

test("WA-14 declares exactly the two required composite indexes", () => {
  const indexes = JSON.parse(
    readFileSync(join(repoRoot, "firestore.indexes.json"), "utf8"),
  );
  const mine = indexes.indexes.filter(
    (i) => i.collectionGroup === "studentSearch",
  );
  assert.equal(mine.length, 2);
  assert.deepEqual(
    mine.map((i) => i.fields.map((f) => f.fieldPath).join("+")).sort(),
    [
      "halaqaIds+fullNameNormalized",
      "visibleTo+fullNameNormalized",
    ],
  );
  for (const index of mine) {
    assert.equal(index.fields[0].arrayConfig, "CONTAINS");
    assert.equal(index.fields[1].order, "ASCENDING");
  }
});
