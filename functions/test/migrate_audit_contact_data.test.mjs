/**
 * Read-only contact-data audit: gate, read-only store, analyzer, report
 * safety and CLI refusals. In-memory fakes and synthetic data only; no
 * Firebase connection, no emulator. CLI runs are preloaded with hooks that
 * fail on any firebase-admin load or non-allowed connection.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
  AUDIT_EMULATOR_PROJECTS,
  CATEGORY,
  ReadOnlyViolation,
  analyzeDocument,
  buildPlan,
  checkAuditInvocation,
  readOnlyStore,
  runContactDataAudit,
  safeKey,
} from "../scripts/migrate-audit-contact-data.mjs";
import { CONTACT_FIELD_KEYS } from "../scripts/migrate-contact-fields.mjs";
import { DOCUMENT_ID, FakeDb } from "./migration_fakes.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const scriptPath = join(functionsDir, "scripts", "migrate-audit-contact-data.mjs");
const require = createRequire(import.meta.url);
const { detectContactInfo: detect } = require("../lib/privacy/contactInfoPolicy.js");

// ── synthetic values ───────────────────────────────────────────────────────
const P1 = "01011112222";
const P2 = "+966500000001";
const P3 = "0599990000";
const BIZ = "01012345678";
const N = ["Syn Name Alpha 4711", "Syn Name Beta 4712", "Syn Name Gamma 4713"];
const BIO = "Synthetic bio marker Z9Q";
const E1 = "synthetic.one@example.test";
const UID_A = "uA1b2C3d4E5f6G7h8J";
const IDS = [UID_A, "docMarkerPlainQ1", "convMarkerQ2", "msgMarkerQ3", "postMarkerQ4", "cmtMarkerQ5", "paymentMarkerQ6", "halaqaMarkerQ7", "spMarkerQ8"];
const SECRETS = [P1, P2, P3, BIZ, ...N, BIO, E1, "@example.test", "@", ...IDS, "1011112222"];

const seed = () => ({
  [`users/${UID_A}`]: { name: N[0], role: "parent", phone: P1, email: E1, notes: `call me ${P2}` },
  "users/docMarkerPlainQ1": { name: N[1], role: "student" },
  [`userPrivate/${UID_A}`]: { email: E1, whatsapp: P2 },
  "studentProfiles/spMarkerQ8": {
    guardian: { name: N[2], phone: P2 },
    contacts: [{ mobile: P1 }],
    emergencyPhone: P3,
    bio: `${BIO} https://wa.me/966500000001`,
    contactNo: 1011112222,
    readBy: { [UID_A]: true },
    byNumber: { "0501234567": true },
  },
  "conversations/convMarkerQ2": { lastMessage: "رقمي 0501234567" },
  "conversations/convMarkerQ2/messages/msgMarkerQ3": { text: `tel:${P1}`, senderId: UID_A, phone: P1 },
  "halaqat/halaqaMarkerQ7": { meetingLink: "https://wa.me/966500000001", phone: P1 },
  "academySettings/paymentPublic": { vodafoneCashDestination: BIZ, updatedBy: UID_A },
  "academySettings/billing": { supportPhone: P1, note: `contact ${P2}` },
  "payments/paymentMarkerQ6": { vodafoneCashDestination: BIZ, proofFileName: `receipt_${P1}.jpg` },
  "posts/postMarkerQ4": { content: "plain text" },
  "posts/postMarkerQ4/comments/cmtMarkerQ5": { text: `email me ${E1}` },
});

const scan = (db, opts = {}) => runContactDataAudit({ store: readOnlyStore(db, DOCUMENT_ID), detect, ...opts });
const find = (report, collection, fieldPath, category) =>
  report.findings.find((f) => f.collection === collection && f.fieldPath === fieldPath && f.category === category);
const assertNoLeak = (text, label) => {
  for (const s of SECRETS) assert.ok(!text.includes(s), `${label} leaked a synthetic value or id`);
};

// ── gate ───────────────────────────────────────────────────────────────────
const OK_ENV = {
  CONTACT_AUDIT_EMULATOR_OPT_IN: "1",
  CONTACT_AUDIT_PINNED_PORTS: "38080,34400",
  FIRESTORE_EMULATOR_HOST: "127.0.0.1:38080",
  FIREBASE_EMULATOR_HUB: "127.0.0.1:34400",
};
const OK_ARGV = ["--project", "demo-rafiq-rules", "--scan", "--confirm", "contact-data-audit:demo-rafiq-rules"];
const gate = (argv, env = OK_ENV) => checkAuditInvocation({ argv, env });

test("default is plan-only; the plan never claims a connection", () => {
  const r = gate([], {});
  assert.deepEqual([r.problems, r.mode], [[], "plan"]);
  const plan = buildPlan(r.config);
  assert.equal(plan.connects, false);
  assert.match(plan.scope.auth, /disabled/);
  assert.match(plan.scope.storage, /disabled/);
  assert.equal(gate(["--project", "rafiq-academy-prod"], {}).mode, "plan", "a project alone never scans");
  assert.equal(buildPlan(gate(["--project", "rafiq-academy-prod"], {}).config).project, null);
  assert.deepEqual(gate(OK_ARGV), { problems: [], mode: "scan", config: gate(OK_ARGV).config });
  assert.deepEqual(AUDIT_EMULATOR_PROJECTS, ["demo-rafiq-rules"]);
});

test("live projects are refused even when allowlisted by the shared guard", () => {
  for (const project of ["rafiq-academy", "rafiq-academy-staging", "rafiq-academy-prod"]) {
    for (const env of [OK_ENV, {}]) {
      const r = gate(["--project", project, "--scan", "--confirm", `contact-data-audit:${project}`], env);
      assert.equal(r.mode, null);
      assert.match(r.problems.join(" "), /Live Firebase projects are refused/);
    }
  }
  assert.match(gate(["--project", "demo-other", "--scan", "--confirm", "contact-data-audit:demo-other"]).problems.join(),
    /not an approved isolated emulator project/);
});

test("missing or wrong confirmation is refused", () => {
  for (const argv of [
    ["--project", "demo-rafiq-rules", "--scan"],
    ["--project", "demo-rafiq-rules", "--scan", "--confirm", "contact-data-audit:rafiq-academy"],
    ["--project", "demo-rafiq-rules", "--scan", "--confirm", "email-backfill:demo-rafiq-rules"],
    ["--project", "demo-rafiq-rules", "--scan", "--confirm", "yes"],
  ]) {
    assert.match(gate(argv).problems.join(), /--confirm contact-data-audit:demo-rafiq-rules/);
  }
  assert.match(gate(["--confirm", "x"], {}).problems.join(), /only accepted together with --scan/);
  assert.match(gate(["--scan"]).problems.join(), /--scan needs --project/);
});

test("write, Auth and Storage options do not exist in this phase", () => {
  assert.match(gate([...OK_ARGV, "--apply"]).problems.join(), /read-only/);
  assert.match(gate([...OK_ARGV, "--auth"]).problems.join(), /not approved/);
  assert.match(gate([...OK_ARGV, "--storage"]).problems.join(), /not approved/);
  const odd = gate([...OK_ARGV, E1, `--x=${P1}`]).problems.join(" ");
  assert.doesNotMatch(odd, /@|01011112222/);
});

test("opt-in, pinned ports and exact loopback endpoints are required", () => {
  const without = (key) => Object.fromEntries(Object.entries(OK_ENV).filter(([k]) => k !== key));
  assert.match(gate(OK_ARGV, without("CONTACT_AUDIT_EMULATOR_OPT_IN")).problems.join(), /OPT_IN=1/);
  assert.match(gate(OK_ARGV, without("CONTACT_AUDIT_PINNED_PORTS")).problems.join(), /PINNED_PORTS/);
  assert.match(gate(OK_ARGV, { ...OK_ENV, CONTACT_AUDIT_PINNED_PORTS: "8080,4400",
    FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080", FIREBASE_EMULATOR_HUB: "127.0.0.1:4400" }).problems.join(), /default emulator ports/);
  assert.match(gate(OK_ARGV, { ...OK_ENV, FIRESTORE_EMULATOR_HOST: "127.0.0.1:38081" }).problems.join(), /FIRESTORE_EMULATOR_HOST does not match/);
  assert.match(gate(OK_ARGV, { ...OK_ENV, FIRESTORE_EMULATOR_HOST: "localhost:38080" }).problems.join(), /FIRESTORE_EMULATOR_HOST does not match/);
  assert.match(gate(OK_ARGV, { ...OK_ENV, FIREBASE_EMULATOR_HUB: "127.0.0.1:34401" }).problems.join(), /FIREBASE_EMULATOR_HUB does not match/);
  assert.match(gate(OK_ARGV, { ...OK_ENV, CONTACT_AUDIT_PINNED_PORTS: "38080,38080",
    FIREBASE_EMULATOR_HUB: "127.0.0.1:38080" }).problems.join(), /distinct/);
  assert.match(gate(OK_ARGV, { ...OK_ENV, GOOGLE_APPLICATION_CREDENTIALS: "/x.json" }).problems.join(), /must be unset/);
});

test("project mismatch through the shared guard is refused", () => {
  for (const key of ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT"]) {
    assert.match(gate(OK_ARGV, { ...OK_ENV, [key]: "rafiq-academy-prod" }).problems.join(), new RegExp(key));
  }
  assert.match(gate(OK_ARGV, { ...OK_ENV, FIREBASE_CONFIG: '{"projectId":"rafiq-academy"}' }).problems.join(), /FIREBASE_CONFIG/);
  const noEmulator = Object.fromEntries(Object.entries(OK_ENV).filter(([k]) => k !== "FIRESTORE_EMULATOR_HOST"));
  assert.match(gate(OK_ARGV, noEmulator).problems.join(), /emulator-only/);
});

// ── read-only store ────────────────────────────────────────────────────────
test("the read-only store exposes no write path", async () => {
  const db = new FakeDb(seed());
  const store = readOnlyStore(db, DOCUMENT_ID);
  for (const prop of ["batch", "runTransaction", "bulkWriter", "collection", "doc", "collectionGroup",
    "recursiveDelete", "set", "update", "delete", "create", "db", "firestore"]) {
    assert.throws(() => store[prop], ReadOnlyViolation, prop);
  }
  assert.throws(() => { store.page = null; }, ReadOnlyViolation);
  assert.throws(() => { delete store.page; }, ReadOnlyViolation);
  assert.throws(() => Object.defineProperty(store, "set", { value: 1 }), ReadOnlyViolation);

  const page = await store.page("users", null, 10);
  const doc = page.docs[0];
  for (const prop of ["ref", "set", "update", "delete", "create", "updateTime", "exists"]) {
    assert.throws(() => doc[prop], ReadOnlyViolation, `document.${prop}`);
  }
  assert.throws(() => page.cursorSnapshot, ReadOnlyViolation);
});

test("a full scan performs zero writes and leaves data unchanged", async () => {
  const db = new FakeDb(seed());
  const before = db.dump();
  await scan(db, { pageSize: 2 });
  assert.equal(db.writes.length, 0);
  assert.equal(db.deletes, 0);
  assert.deepEqual(db.dump(), before);
});

test("source has no write, Auth, Storage or file-output path", () => {
  const source = readFileSync(scriptPath, "utf8");
  // The only `.set(` is the in-memory WeakMap that keeps page cursors.
  assert.equal(source.match(/cursors\.set\(/g)?.length, 1);
  const withoutCursorMap = source.replace("cursors.set(", "");
  assert.doesNotMatch(withoutCursorMap, /\.(set|update|create|delete)\(|batch\(|runTransaction|bulkWriter|recursiveDelete/);
  assert.doesNotMatch(source, /firebase-admin\/(auth|storage)|getStorage|getAuth/);
  assert.doesNotMatch(source, /writeFile|appendFile|createWriteStream|node:fs/);
  // firebase-admin is only ever imported dynamically, after the gate.
  assert.doesNotMatch(source, /^import .*firebase-admin/m);
  assert.match(source, /lib", "privacy", "contactInfoPolicy\.js"/, "uses the policy's own detector");
});

// ── analyzer and report ────────────────────────────────────────────────────
test("classifies approved, nested, array, alternative, text, numeric and email findings", async () => {
  const report = await scan(new FakeDb(seed()), { pageSize: 2 });
  const C = CATEGORY;
  assert.ok(find(report, "users", "phone", C.approvedKeyInCleanupScope));
  assert.ok(find(report, "userPrivate", "whatsapp", C.approvedKeyInCleanupScope));
  assert.ok(find(report, "halaqat", "phone", C.approvedKeyOutsideCleanupScope));
  assert.ok(find(report, "conversations/{}/messages", "phone", C.approvedKeyOutsideCleanupScope));
  assert.ok(find(report, "studentProfiles", "guardian.phone", C.approvedKeyNested));
  assert.ok(find(report, "studentProfiles", "contacts[].mobile", C.approvedKeyInArray));
  assert.ok(find(report, "studentProfiles", "emergencyPhone", C.alternativeKeyName));
  assert.ok(find(report, "studentProfiles", "bio", C.textWhatsappLink));
  assert.ok(find(report, "studentProfiles", "contactNo", C.numericPhoneShaped));
  assert.ok(find(report, "users", "notes", C.textPhoneNumber));
  assert.ok(find(report, "conversations", "lastMessage", C.textPhoneNumber));
  assert.ok(find(report, "conversations/{}/messages", "text", C.textPhoneLink));
  assert.ok(find(report, "halaqat", "meetingLink", C.textWhatsappLink));
  assert.ok(find(report, "payments", "proofFileName", C.textPhoneNumber));
  assert.ok(find(report, "users", "email", C.emailField));
  assert.ok(find(report, "posts/{}/comments", "text", C.emailShapedText));
  assert.equal(report.totals.documentsScanned, 12);
  assert.equal(report.collections["conversations/{}/messages"].documentsScanned, 1);
});

test("Vodafone Cash business destination is allowed and counted separately", async () => {
  const report = await scan(new FakeDb(seed()));
  assert.equal(report.allowedBusinessDestination.count, 1);
  assert.equal(report.findings.filter((f) => f.collection === "academySettings" && f.fieldPath === "vodafoneCashDestination").length, 0);
  // Same field name elsewhere is not exempt.
  assert.ok(find(report, "payments", "vodafoneCashDestination", CATEGORY.textPhoneNumber));
  // Other academySettings findings are business-config review, never personal categories.
  const settings = report.findings.filter((f) => f.collection === "academySettings");
  assert.ok(settings.length >= 2);
  assert.ok(settings.every((f) => f.category === CATEGORY.businessConfigReview));

  const ctx = { detect, knownIds: new Set() };
  const empty = analyzeDocument({ data: { vodafoneCashDestination: " " }, topCollection: "academySettings", isTopLevel: true, docId: "paymentPublic", ...ctx });
  assert.equal(empty.businessDestinations, 0);
  const nested = analyzeDocument({ data: { vodafoneCashDestination: BIZ }, topCollection: "academySettings", isTopLevel: false, docId: "paymentPublic", ...ctx });
  assert.equal(nested.businessDestinations, 0, "only the top-level paymentPublic doc is exempt");
  const users = analyzeDocument({ data: { vodafoneCashDestination: BIZ }, topCollection: "users", isTopLevel: true, docId: "paymentPublic", ...ctx });
  assert.equal(users.findings[0].category, CATEGORY.textPhoneNumber);
});

test("report carries counts, safe names and normalized paths only", async () => {
  const report = await scan(new FakeDb(seed()));
  const text = JSON.stringify(report);
  assertNoLeak(text, "audit report");
  assert.ok(report.findings.every((f) => !f.fieldPath.includes(UID_A)));
  assert.equal(safeKey(UID_A, { knownIds: new Set([UID_A]), detect }), "{key}");
  assert.equal(safeKey("0501234567", { knownIds: new Set(), detect }), "{key}");
  assert.equal(safeKey("a@b.co", { knownIds: new Set(), detect }), "{key}");
  assert.equal(safeKey("kD8sJ2mQ9xLp4RtV", { knownIds: new Set(), detect }), "{key}");
  assert.equal(safeKey("emergencyPhone", { knownIds: new Set(), detect }), "emergencyPhone");
  assert.equal(JSON.stringify(buildPlan(gate([], {}).config)).includes("@"), false);
});

test("odd collection names are not printed", async () => {
  const db = new FakeDb({ "weird name!/d1": { phone: P1 } });
  const report = await scan(db);
  assert.ok(report.collections["<unprintable>"]);
  assert.ok(!JSON.stringify(report).includes("weird name"));
});

// ── detector parity ────────────────────────────────────────────────────────
test("detector parity: the audit uses the compiled policy, identical to the TypeScript source", () => {
  const ts = readFileSync(join(functionsDir, "src", "privacy", "contactInfoPolicy.ts"), "utf8");
  const js = readFileSync(join(functionsDir, "lib", "privacy", "contactInfoPolicy.js"), "utf8");
  for (const name of ["PHONE_LINK", "WHATSAPP_LINK", "DIGIT_RUN", "MAX_PHONE_DIGITS"]) {
    const pick = (src) => src.match(new RegExp(`const ${name}\\s*=\\s*([^;]+);`))?.[1].trim();
    assert.ok(pick(ts), `${name} in src`);
    assert.equal(pick(js), pick(ts), `${name} differs between src and lib`);
  }
  const body = (src) => src.match(/function isPhoneDigits\([^)]*\)[^{]*\{([\s\S]*?)\n\}/)[1].replace(/\s+/g, "");
  assert.equal(body(js), body(ts));
  const { CONTACT_FIELD_KEYS: libKeys } = require("../lib/privacy/contactInfoPolicy.js");
  assert.deepEqual([...libKeys], [...CONTACT_FIELD_KEYS]);

  const corpus = [
    ["call 0501234567", "phone_number"],
    ["٠١٠١١١١٢٢٢٢ رقمي", "phone_number"],
    ["tel:+201011112222", "phone_link"],
    ["https://wa.me/966500000001", "whatsapp_link"],
    ["surah 2 ayah 255", null],
    ["page 604", null],
  ];
  for (const [text, expected] of corpus) assert.equal(detect(text), expected, text);
});

// ── CLI (no SDK, no network) ───────────────────────────────────────────────
const preloads = ["migrate-no-admin-preload.mjs", "migrate-egress-preload.mjs"]
  .flatMap((f) => ["--import", pathToFileURL(join(here, f)).href]);

function runCli(argv, env, { egressPreload = true, allowedPorts = [] } = {}) {
  const imports = egressPreload ? preloads : preloads.slice(0, 2);
  const base = {};
  for (const key of ["PATH", "Path", "SystemRoot", "TEMP", "TMP"]) if (process.env[key] !== undefined) base[key] = process.env[key];
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [...imports, scriptPath, ...argv], {
      env: { ...base, MIGRATE_IT_ALLOWED_PORTS: allowedPorts.join(","), ...env },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    const timer = setTimeout(() => child.kill(), 30000);
    child.on("error", reject);
    child.on("close", (status) => {
      clearTimeout(timer);
      resolve({ status, stdout, stderr });
    });
  });
}

test("CLI default prints the plan without loading firebase-admin or connecting", async () => {
  const r = await runCli([], {});
  assert.equal(r.status, 0, r.stderr);
  const plan = JSON.parse(r.stdout);
  assert.equal(plan.mode, "plan");
  assert.equal(plan.connects, false);
  assert.doesNotMatch(r.stderr, /firebase-admin load attempted|egress blocked/);
});

test("CLI refusals exit 2 before loading firebase-admin or connecting", async () => {
  const cases = [
    ["live allowlisted project", ["--project", "rafiq-academy-prod", "--scan", "--confirm", "contact-data-audit:rafiq-academy-prod"], OK_ENV],
    ["missing confirmation", ["--project", "demo-rafiq-rules", "--scan"], OK_ENV],
    ["wrong confirmation", ["--project", "demo-rafiq-rules", "--scan", "--confirm", "contact-data-audit:rafiq-academy"], OK_ENV],
    ["default ports", OK_ARGV, { ...OK_ENV, CONTACT_AUDIT_PINNED_PORTS: "8080,4400", FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080", FIREBASE_EMULATOR_HUB: "127.0.0.1:4400" }],
    ["no opt-in", OK_ARGV, { ...OK_ENV, CONTACT_AUDIT_EMULATOR_OPT_IN: "0" }],
    ["project env mismatch", OK_ARGV, { ...OK_ENV, GOOGLE_CLOUD_PROJECT: "rafiq-academy" }],
    ["storage requested", [...OK_ARGV, "--storage"], OK_ENV],
  ];
  for (const [label, argv, env] of cases) {
    const r = await runCli(argv, env);
    assert.equal(r.status, 2, `${label}: ${r.stderr}`);
    assert.match(r.stderr, /refused:/, label);
    assert.equal(r.stdout, "", label);
    assert.doesNotMatch(r.stderr, /firebase-admin load attempted|egress blocked/, label);
  }
});

test("CLI refuses when the hub reports Firestore on another port (emulator mismatch)", async () => {
  // Loopback stand-in hub that claims Firestore lives elsewhere.
  const server = http.createServer((req, res) => {
    const port = server.address().port;
    res.setHeader("content-type", "application/json");
    res.end(JSON.stringify({ hub: { host: "127.0.0.1", port }, firestore: { host: "127.0.0.1", port: 38099 } }));
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const hub = server.address().port;
  try {
    const env = {
      CONTACT_AUDIT_EMULATOR_OPT_IN: "1",
      CONTACT_AUDIT_PINNED_PORTS: `38098,${hub}`,
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:38098",
      FIREBASE_EMULATOR_HUB: `127.0.0.1:${hub}`,
    };
    // The script installs its own egress guard here, so only the SDK-load hook is preloaded.
    const r = await runCli(OK_ARGV, env, { egressPreload: false });
    assert.equal(r.status, 2, r.stderr);
    assert.match(r.stderr, /does not report Firestore on the pinned loopback port/);
    assert.doesNotMatch(r.stderr, /firebase-admin load attempted/);
    assert.equal(r.stdout, "");
  } finally {
    await new Promise((r) => server.close(r));
  }
});
