/**
 * Triggers contract for the emulator seeder. Seeding writes Auth users and
 * the documents of buildDemoDataset() while `npm run serve` also runs the
 * Functions emulator, so every trigger that can react to that data is pinned
 * here and changes fail until reviewed. Changes no Function.
 *
 * Three layers:
 *  1. Manifest (authority): the compiled exports' deploy endpoints
 *     (`__endpoint`, what deploy and the Functions emulator read). Catches
 *     every exported trigger whatever the source form (alias, wrapper,
 *     define-then-export, re-export). The test compiles src/ itself with the
 *     project's tsc into a private directory and fails unless tsc exits 0;
 *     lib/ and file timestamps are never used as evidence of a build. (lib/
 *     is what `npm run serve` loads, and it rebuilds and stops on a failed
 *     build first.)
 *  2. Source: firebase-functions is imported only by name from reviewed
 *     modules, and every onDocument* / onSchedule use is a direct
 *     `export const NAME = factory({ literal options })` definition.
 *  3. Cross-check: the source definitions exported from index.ts equal the
 *     manifest's event and schedule endpoints (event type, document,
 *     database), so a stale build cannot hide a change.
 *
 * Limits (text scanning, not a TypeScript parser): code built at run time
 * (eval, computed property names, factories reached through other
 * libraries) is invisible to layer 2; layer 1 still sees anything it
 * exports. A trigger that is not exported from index.ts is never deployed or
 * loaded, so it cannot react to seeded data.
 */
import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

import { buildDemoDataset, SEED_META } from "../scripts/seed-emulator-dataset.mjs";
import {
  classifyEndpoints,
  compareToPinned,
  compileIntoTempDir,
  compileWithTsc,
  crossCheck,
  findStaleOutputs,
  parseIndexExports,
  scanTriggerSources,
} from "./fixtures/seed_emulator_trigger_scan.mjs";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const srcDir = join(functionsDir, "src");

const WRITTEN = "google.cloud.firestore.document.v1.written";
const CREATED = "google.cloud.firestore.document.v1.created";
const UPDATED = "google.cloud.firestore.document.v1.updated";
const firestoreEvent = (eventType, document) => ({ eventType, document, database: "(default)", namespace: "(default)" });

/** Every reviewed Firestore trigger: export name -> event. */
const PINNED = {
  events: {
    notifyOnAbsenceRequestCreated: firestoreEvent(CREATED, "absenceRequests/{requestId}"),
    notifyOnAbsenceRequestReviewed: firestoreEvent(UPDATED, "absenceRequests/{requestId}"),
    notifyOnAssignmentCreated: firestoreEvent(CREATED, "assignments/{assignmentId}"),
    notifyOnPaymentUpdated: firestoreEvent(UPDATED, "payments/{paymentId}"),
    notifyParentsOnEvaluation: firestoreEvent(WRITTEN, "recitationRecords/{recordId}"),
    projectStudentSearchOnHalaqaWrite: firestoreEvent(WRITTEN, "halaqat/{halaqaId}"),
    projectStudentSearchOnProfileWrite: firestoreEvent(WRITTEN, "studentProfiles/{studentId}"),
    projectStudentSearchOnUserWrite: firestoreEvent(WRITTEN, "users/{uid}"),
    reconcileFcmTokenOwnership: firestoreEvent(WRITTEN, "fcmTokens/{uid}/devices/{deviceId}"),
    syncAdminGroupOnUserWrite: firestoreEvent(WRITTEN, "users/{uid}"),
    syncHalaqaGroupOnWrite: firestoreEvent(WRITTEN, "halaqat/{halaqaId}"),
  },
  /** Time-based only; never fired by a write. */
  schedules: ["processPaymentOverdueGrace"],
};

/**
 * Reviewed: they run on seeded users / studentProfiles and only upsert or
 * delete studentSearch/{id}, a derived projection the seeder neither writes
 * nor checks after writing. syncAdminGroupOnUserWrite only updates an
 * already existing conversations/admin_internal_group (never creates it), so
 * a seed run into a fresh emulator writes nothing.
 */
const TRIGGERS_ON_SEEDED_DATA = [
  "projectStudentSearchOnProfileWrite",
  "projectStudentSearchOnUserWrite",
  "syncAdminGroupOnUserWrite",
];
const DERIVED_COLLECTIONS = ["studentSearch"];

function tsFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return tsFiles(path);
    return entry.name.endsWith(".ts") ? [path] : [];
  });
}

const sources = tsFiles(srcDir).map((path) => ({
  file: relative(srcDir, path).replaceAll("\\", "/"),
  text: readFileSync(path, "utf8"),
}));

// Inside functions/node_modules so the compiled code resolves the installed
// packages; ignored by git and never uploaded on deploy. A failed compile
// removes its directory itself; `after` removes a successful one.
let buildDir;
before(() => {
  buildDir = compileIntoTempDir({
    functionsDir,
    parentDir: join(functionsDir, "node_modules", ".cache"),
    prefix: "seed-trigger-contract-",
  });
});
after(() => {
  if (buildDir) rmSync(buildDir, { recursive: true, force: true });
});

let manifest;
function compiledManifest() {
  if (manifest) return manifest;
  process.env.GCLOUD_PROJECT ??= "demo-rafiq-rules";
  manifest = classifyEndpoints(require(join(buildDir, "index.js")));
  return manifest;
}

// ── Real code ───────────────────────────────────────────────────────────────

test("layer 1: compiled endpoints are only reviewed kinds and match the pinned triggers", () => {
  const { problems, events, schedules, callables } = compiledManifest();
  assert.deepEqual(problems, []);
  assert.deepEqual(compareToPinned({ events, schedules }, PINNED), []);
  assert.ok(callables.length > 0, "expected callables in the manifest");
});

test("layer 2: firebase-functions imports and trigger definitions use only the reviewed forms", () => {
  const { problems, definitions } = scanTriggerSources(sources);
  assert.deepEqual(problems, []);
  assert.deepEqual(Object.keys(definitions).sort(), [...Object.keys(PINNED.events), ...PINNED.schedules].sort());
});

test("layer 3: source definitions exported from index.ts equal the compiled endpoints", () => {
  const index = parseIndexExports(sources.find((s) => s.file === "index.ts").text);
  assert.deepEqual(index.problems, []);
  const { definitions } = scanTriggerSources(sources);
  const { events, schedules } = compiledManifest();
  assert.deepEqual(crossCheck({ definitions, indexNames: index.names, events, schedules }), []);
});

test("only the reviewed triggers fire on seeded or derived collections", () => {
  const seeded = [...new Set([...buildDemoDataset().documents.map((d) => d.collection), SEED_META.collection])].sort();
  assert.deepEqual(seeded, ["_seedMeta", "parentProfiles", "studentProfiles", "teacherProfiles", "userPrivate", "users"]);
  const watched = new Set([...seeded, ...DERIVED_COLLECTIONS]);
  const firing = Object.entries(compiledManifest().events)
    .filter(([, { document }]) => {
      const first = document.split("/")[0];
      return first.startsWith("{") || watched.has(first);
    })
    .map(([name]) => name)
    .sort();
  assert.deepEqual(firing, TRIGGERS_ON_SEEDED_DATA);
});

test("the reviewed seeded-data triggers write only the derived projection", () => {
  const file = sources.find((s) => s.file === "search/studentSearchFunctions.ts").text;
  assert.match(sources.map((s) => s.text).join("\n"), /\bconst STUDENT_SEARCH_COLLECTION = "studentSearch";/);
  const targets = [...file.matchAll(/\.(set|update|delete|create)\(\s*([A-Za-z_][\w.]*)/g)].map((m) => m[2]);
  assert.deepEqual([...new Set(targets)].sort(), ["doc.ref", "ref"]);
  assert.match(file, /const ref = db\.collection\(STUDENT_SEARCH_COLLECTION\)\.doc\(id\);/);
  assert.match(file, /\.collection\(STUDENT_SEARCH_COLLECTION\)[\s\S]{0,200}const batch = db\.batch\(\);/);
  assert.doesNotMatch(file, /\.collection\([^)]*\)\.add\(|\b(recursiveDelete|bulkWriter)\(/);
});

test("the admin group trigger writes only the existing admin group conversation", () => {
  const file = sources.find((s) => s.file === "chat/adminGroupFunctions.ts").text;
  const targets = [...file.matchAll(/\.(set|update|delete|create)\(\s*([A-Za-z_][\w.]*)/g)].map((m) => m[2]);
  assert.deepEqual([...new Set(targets)].sort(), ["conversationRef"]);
  assert.match(file, /const conversationRef = db\.collection\("conversations"\)\.doc\(ADMIN_GROUP_CONVERSATION_ID\);/);
  assert.match(file, /syncAdminGroupConversation\(\{ db, createdBy: "system", allowCreate: false \}\)/);
  assert.doesNotMatch(file, /\.add\(|\b(recursiveDelete|bulkWriter|batch)\(/);
});

// ── Layer 2 detects every evasion form (synthetic sources) ──────────────────

const IMPORT_FIRESTORE = 'import { onDocumentWritten } from "firebase-functions/v2/firestore";\n';
const HANDLER = "async () => {}";
const scan = (text) => scanTriggerSources([{ file: "x.ts", text }]);

test("layer 2 accepts the reviewed form (baseline for the evasion cases)", () => {
  const { problems, definitions } = scan(
    `${IMPORT_FIRESTORE}const USERS = "users";\n` +
      `export const t = onDocumentWritten({ region: "europe-west1", document: \`\${USERS}/{uid}\` }, ${HANDLER});`,
  );
  assert.deepEqual(problems, []);
  assert.deepEqual(definitions.t, {
    file: "x.ts",
    factory: "onDocumentWritten",
    eventType: WRITTEN,
    document: "users/{uid}",
    database: "(default)",
  });
});

test("layer 2 flags define-then-export, aliases, namespaces, require, v1, wrappers and indirect calls", () => {
  const cases = {
    defineThenExport: [`${IMPORT_FIRESTORE}const t = onDocumentWritten({ document: "users/{uid}" }, ${HANDLER});\nexport { t };`, /not "export const NAME = factory/],
    aliasImport: ['import { onDocumentWritten as w } from "firebase-functions/v2/firestore";\nexport const t = w({ document: "users/{uid}" }, h);', /aliased import/],
    namespaceImport: ['import * as fs from "firebase-functions/v2/firestore";\nexport const t = fs.onDocumentWritten({ document: "users/{uid}" }, h);', /named imports only/],
    defaultImport: ['import functions from "firebase-functions/v2/firestore";', /named imports only/],
    v2Root: ['import { firestore } from "firebase-functions/v2";\nexport const t = firestore.onDocumentWritten({ document: "users/{uid}" }, h);', /not a reviewed firebase-functions module/],
    v1Root: ['import * as functions from "firebase-functions";\nexport const t = functions.firestore.document("users/{uid}").onWrite(h);', /not a reviewed firebase-functions module/],
    v1Path: ['import { firestore } from "firebase-functions/v1";', /not a reviewed firebase-functions module/],
    identity: ['import { beforeUserCreated } from "firebase-functions/v2/identity";', /not a reviewed firebase-functions module/],
    storage: ['import { onObjectFinalized } from "firebase-functions/v2/storage";', /not a reviewed firebase-functions module/],
    pubsub: ['import { onMessagePublished } from "firebase-functions/v2/pubsub";', /not a reviewed firebase-functions module/],
    requireCall: ['const { onDocumentWritten } = require("firebase-functions/v2/firestore");\nexport const t = onDocumentWritten({ document: "users/{uid}" }, h);', /require\(\) or import\(\)/],
    dynamicImport: ['const m = await import("firebase-functions/v2/firestore");', /require\(\) or import\(\)/],
    reExport: ['export { onDocumentWritten } from "firebase-functions/v2/firestore";', /re-exports firebase-functions/],
    wrapper: [`${IMPORT_FIRESTORE}function make(path) { return onDocumentWritten({ document: path }, ${HANDLER}); }\nexport const t = make("users/{uid}");`, /not "export const NAME = factory/],
    indirectCall: [`${IMPORT_FIRESTORE}const f = onDocumentWritten;\nexport const t = f({ document: "users/{uid}" }, ${HANDLER});`, /not "export const NAME = factory/],
    localLookalike: ['function onDocumentWritten(o, h) { return h; }\nexport const t = onDocumentWritten({ document: "users/{uid}" }, h);', /not "export const NAME = factory|without a named import/],
    withAuthContext: ['import { onDocumentWrittenWithAuthContext } from "firebase-functions/v2/firestore";\nexport const t = onDocumentWrittenWithAuthContext({ document: "users/{uid}" }, h);', /not a reviewed trigger factory/],
    optionsVariable: [`${IMPORT_FIRESTORE}const opts = { document: "users/{uid}" };\nexport const t = onDocumentWritten(opts, ${HANDLER});`, /inline options object/],
    computedDocument: [`${IMPORT_FIRESTORE}export const t = onDocumentWritten({ document: pathFor("users") }, ${HANDLER});`, /no literal document path/],
    unresolvedConstant: [`${IMPORT_FIRESTORE}export const t = onDocumentWritten({ document: \`\${UNKNOWN}/{id}\` }, ${HANDLER});`, /unresolved constant/],
    computedDatabase: [`${IMPORT_FIRESTORE}export const t = onDocumentWritten({ document: "users/{uid}", database: DB }, ${HANDLER});`, /database is not a literal/],
  };
  for (const [label, [text, expected]] of Object.entries(cases)) {
    const { problems } = scan(text);
    assert.ok(problems.some((p) => expected.test(p)), `${label}: ${JSON.stringify(problems)}`);
  }
});

test("layer 2 reports a non-default database so the cross-check can compare it", () => {
  const { problems, definitions } = scan(`${IMPORT_FIRESTORE}export const t = onDocumentWritten({ document: "users/{uid}", database: "other" }, ${HANDLER});`);
  assert.deepEqual(problems, []);
  assert.equal(definitions.t.database, "other");
});

test("index.ts aliases and export * are flagged", () => {
  assert.ok(parseIndexExports('export { a as b } from "./x";').problems.length > 0);
  assert.ok(parseIndexExports('export * from "./x";').problems.length > 0);
  assert.deepEqual([...parseIndexExports('export {\n  a,\n  b,\n} from "./x";').names], ["a", "b"]);
});

// ── Layer 1 rejects unreviewed endpoints (synthetic manifests) ──────────────

const endpoint = (body) => Object.assign(() => {}, { __endpoint: { platform: "gcfv2", ...body } });
const event = (eventType, document, filters = {}) =>
  endpoint({
    eventTrigger: {
      eventType,
      eventFilters: { database: "(default)", namespace: "(default)", ...filters },
      eventFilterPathPatterns: { document },
      retry: false,
    },
  });
const pinnedExports = () => ({
  ...Object.fromEntries(Object.entries(PINNED.events).map(([name, e]) => [name, event(e.eventType, e.document)])),
  processPaymentOverdueGrace: endpoint({ scheduleTrigger: { schedule: "every day 01:15" } }),
  someCallable: endpoint({ callableTrigger: {} }),
});
const manifestProblems = (exportsMap) => {
  const classified = classifyEndpoints(exportsMap);
  return [...classified.problems, ...compareToPinned(classified, PINNED)];
};

test("layer 1 baseline: the pinned shape passes", () => {
  assert.deepEqual(manifestProblems(pinnedExports()), []);
});

test("layer 1 flags new, changed or unknown triggers", () => {
  const cases = {
    newTriggerOnUsers: (m) => (m.extra = event(WRITTEN, "users/{uid}")),
    newTriggerOnSeedMeta: (m) => (m.extra = event(CREATED, "_seedMeta/{id}")),
    newTriggerOnUserPrivate: (m) => (m.extra = event(WRITTEN, "userPrivate/{uid}")),
    changedDocument: (m) => (m.projectStudentSearchOnUserWrite = event(WRITTEN, "users/{uid}/private/{doc}")),
    changedEventType: (m) => (m.notifyOnAssignmentCreated = event(WRITTEN, "assignments/{assignmentId}")),
    changedDatabase: (m) => (m.projectStudentSearchOnUserWrite = event(WRITTEN, "users/{uid}", { database: "other" })),
    removedTrigger: (m) => delete m.syncHalaqaGroupOnWrite,
    newSchedule: (m) => (m.nightly = endpoint({ scheduleTrigger: { schedule: "every day 02:00" } })),
    blockingAuth: (m) => (m.block = endpoint({ blockingTrigger: { eventType: "providers/cloud.auth/eventTypes/user.beforeCreate" } })),
    taskQueue: (m) => (m.queue = endpoint({ taskQueueTrigger: {} })),
    unknownKind: (m) => (m.odd = endpoint({ fooTrigger: {} })),
    twoKinds: (m) => (m.both = endpoint({ callableTrigger: {}, scheduleTrigger: {} })),
    storageEvent: (m) => (m.upload = event("google.cloud.storage.object.v1.finalized", undefined)),
    authEvent: (m) => (m.signup = event("google.firebase.auth.user.v1.created", undefined)),
    pubsubEvent: (m) => (m.topic = event("google.cloud.pubsub.topic.v1.messagePublished", undefined)),
    v1Platform: (m) => (m.legacy = Object.assign(() => {}, { __endpoint: { platform: "gcfv1", callableTrigger: {} } })),
    noEndpoint: (m) => (m.helper = () => {}),
    nonFunctionExport: (m) => (m.CONSTANT = "x"),
  };
  for (const [label, mutate] of Object.entries(cases)) {
    const exportsMap = pinnedExports();
    mutate(exportsMap);
    assert.ok(manifestProblems(exportsMap).length > 0, label);
  }
});

// ── Layer 3 catches a stale build ───────────────────────────────────────────

test("layer 3 flags src and lib disagreeing on names, paths, event types or schedules", () => {
  const definitions = {
    a: { factory: "onDocumentWritten", eventType: WRITTEN, document: "users/{uid}", database: "(default)" },
    s: { factory: "onSchedule" },
  };
  const indexNames = new Set(["a", "s"]);
  const events = { a: firestoreEvent(WRITTEN, "users/{uid}") };
  assert.deepEqual(crossCheck({ definitions, indexNames, events, schedules: ["s"] }), []);
  const cases = {
    pathChangedInSrc: { definitions: { ...definitions, a: { ...definitions.a, document: "people/{uid}" } } },
    typeChangedInSrc: { definitions: { ...definitions, a: { ...definitions.a, eventType: CREATED } } },
    databaseChangedInSrc: { definitions: { ...definitions, a: { ...definitions.a, database: "other" } } },
    addedInSrcOnly: { definitions: { ...definitions, b: definitions.a }, indexNames: new Set(["a", "b", "s"]) },
    inLibOnly: { events: { ...events, ghost: firestoreEvent(WRITTEN, "users/{uid}") } },
    scheduleMismatch: { schedules: [] },
  };
  for (const [label, override] of Object.entries(cases)) {
    const problems = crossCheck({ definitions, indexNames, events, schedules: ["s"], ...override });
    assert.ok(problems.length > 0, label);
  }
});

test("freshness helper flags src files with a missing or older lib/ output (timestamps only, not build evidence)", () => {
  const root = mkdtempSync(join(tmpdir(), "trigger-freshness-"));
  try {
    const src = join(root, "src");
    const lib = join(root, "lib");
    mkdirSync(join(src, "a"), { recursive: true });
    mkdirSync(join(lib, "a"), { recursive: true });
    for (const [rel, out] of [["index.ts", "index.js"], ["a/b.ts", "a/b.js"], ["a/c.ts", null]]) {
      writeFileSync(join(src, rel), "export {};");
      if (out) writeFileSync(join(lib, out), "");
    }
    const old = new Date(Date.now() - 60000);
    utimesSync(join(lib, "a", "b.js"), old, old);
    assert.deepEqual(findStaleOutputs(src, lib), ["a/b.ts (newer than its lib/ output)", "a/c.ts (no a/c.js)"]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a failed tsc build is rejected even though it emitted newer lib/ files", () => {
  const root = mkdtempSync(join(tmpdir(), "trigger-build-"));
  try {
    const src = join(root, "src");
    const lib = join(root, "lib");
    mkdirSync(src);
    writeFileSync(
      join(root, "tsconfig.json"),
      JSON.stringify({ compilerOptions: { outDir: "lib", rootDir: "src", strict: true, types: [] }, include: ["src"] }),
    );
    writeFileSync(join(src, "index.ts"), "export const ok: number = 1;\n");
    compileWithTsc({ functionsDir, projectDir: root, outDir: lib });

    writeFileSync(join(src, "index.ts"), 'export const broken: number = "not a number";\n');
    const old = new Date(Date.now() - 60000);
    utimesSync(join(src, "index.ts"), old, old);
    assert.throws(() => compileWithTsc({ functionsDir, projectDir: root, outDir: lib }), /tsc failed \(exit 2\)/);
    assert.ok(existsSync(join(lib, "index.js")));
    assert.match(readFileSync(join(lib, "index.js"), "utf8"), /not a number/);
    assert.deepEqual(findStaleOutputs(src, lib), [], "timestamps alone would have accepted the failed build");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the build directory used by before() is removed when tsc fails, and kept only when it succeeds", () => {
  const root = mkdtempSync(join(tmpdir(), "trigger-build-cleanup-"));
  try {
    const src = join(root, "src");
    const parentDir = join(root, "builds");
    mkdirSync(src);
    writeFileSync(
      join(root, "tsconfig.json"),
      JSON.stringify({ compilerOptions: { rootDir: "src", strict: true, types: [] }, include: ["src"] }),
    );
    const compile = () => compileIntoTempDir({ functionsDir, projectDir: root, parentDir, prefix: "build-" });

    writeFileSync(join(src, "index.ts"), 'export const broken: number = "not a number";\n');
    assert.throws(compile, /tsc failed \(exit 2\)/);
    assert.deepEqual(readdirSync(parentDir), [], "failed build directory left behind");

    writeFileSync(join(src, "index.ts"), "export const ok: number = 1;\n");
    const outDir = compile();
    assert.ok(existsSync(join(outDir, "index.js")));
    assert.deepEqual(readdirSync(parentDir), [relative(parentDir, outDir)]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
