/**
 * Read-only contact-data audit against the real Firebase Admin SDK and an
 * isolated Firestore emulator. Synthetic data only.
 *
 * Refuses to start unless AUDIT_EMULATOR_IT=1, AUDIT_IT_PORTS lists the
 * non-default firestore,hub ports, and the emulator env vars point at exactly
 * those loopback ports for project demo-rafiq-rules. A process-wide egress
 * guard refuses any connection that is not loopback to those ports.
 *
 *   firebase emulators:exec --config <isolated firebase.json> \
 *     --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 <repo>/functions/test/migrate_audit_contact_data.emulator.test.mjs"
 */
import test from "node:test";
import assert from "node:assert/strict";
import net from "node:net";
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";

const PROJECT = "demo-rafiq-rules";
const PORTS = (process.env.AUDIT_IT_PORTS ?? "").split(",").map(Number);
const [FS_PORT, HUB_PORT] = PORTS;
const EXPECTED_ENV = {
  FIRESTORE_EMULATOR_HOST: `127.0.0.1:${FS_PORT}`,
  FIREBASE_EMULATOR_HUB: `127.0.0.1:${HUB_PORT}`,
};
{
  const problems = [];
  if (process.env.AUDIT_EMULATOR_IT !== "1") problems.push("AUDIT_EMULATOR_IT must be 1");
  if (PORTS.length !== 2 || PORTS.some((p) => !Number.isInteger(p) || p < 1024 || p > 65535)) {
    problems.push("AUDIT_IT_PORTS must be firestore,hub");
  }
  if (PORTS.some((p) => [4000, 4400, 4500, 5000, 5001, 8080, 8085, 9000, 9099, 9150, 9199, 9299, 9499].includes(p))) {
    problems.push("default (possibly shared) emulator ports are refused");
  }
  for (const [key, value] of Object.entries(EXPECTED_ENV)) {
    if (process.env[key] !== value) problems.push(`${key} is not ${value}`);
  }
  for (const key of ["GCLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT"]) {
    if (process.env[key] && process.env[key] !== PROJECT) problems.push(`${key} is not ${PROJECT}`);
  }
  for (const key of ["GOOGLE_APPLICATION_CREDENTIALS", "FIREBASE_AUTH_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST"]) {
    if (process.env[key]) problems.push(`${key} must be unset`);
  }
  if (problems.length > 0) throw new Error(`isolation check failed: ${problems.join("; ")}`);
}
process.env.METADATA_SERVER_DETECTION = "none";

const guard = installEgressGuard({ allowedPorts: PORTS });
assert.equal(await guard.selfTest(), true, "egress guard self-test");

const hubListing = await (await fetch(`http://127.0.0.1:${HUB_PORT}/emulators`)).json();
assert.deepEqual(Object.keys(hubListing).filter((k) => !["hub", "logging"].includes(k)), ["firestore"],
  "only the Firestore emulator may be running");
assert.equal(hubListing.firestore.port, FS_PORT);
assert.equal(hubListing.firestore.host, "127.0.0.1");
assert.equal(hubListing.hub.port, HUB_PORT);

const { initializeApp } = await import("firebase-admin/app");
const { getFirestore, FieldPath } = await import("firebase-admin/firestore");
const { CATEGORY, ReadOnlyViolation, readOnlyStore, runContactDataAudit } =
  await import("../scripts/migrate-audit-contact-data.mjs");

const here = dirname(fileURLToPath(import.meta.url));
const scriptPath = join(here, "..", "scripts", "migrate-audit-contact-data.mjs");
const require = createRequire(import.meta.url);
const { detectContactInfo: detect } = require("../lib/privacy/contactInfoPolicy.js");

const app = initializeApp({ projectId: PROJECT }, "audit-emulator-it");
const db = getFirestore(app);

// ── synthetic values (every one must stay out of reports) ──────────────────
const P1 = "01011112222";
const P2 = "+966500000001";
const P3 = "0599990000";
const BIZ = "01012345678";
const N = ["Syn Name Alpha 4711", "Syn Name Beta 4712", "Syn Name Gamma 4713"];
const BIO = "Synthetic bio marker Z9Q";
const MSG = "Synthetic message marker M5";
const E1 = "synthetic.one@example.test";
const UID_A = "uA1b2C3d4E5f6G7h8J";
const IDS = [UID_A, "docMarkerPlainQ1", "convMarkerQ2", "msgMarkerQ3", "postMarkerQ4", "cmtMarkerQ5",
  "paymentMarkerQ6", "halaqaMarkerQ7", "spMarkerQ8", "deepMarkerQ9"];
const SECRETS = [P1, P2, P3, BIZ, ...N, BIO, MSG, E1, "@example.test", "@", ...IDS, "1011112222"];

const assertNoLeak = (text, label) => {
  for (const s of SECRETS) assert.ok(!text.includes(s), `${label} leaked a synthetic value or id`);
};

const DOCS = {
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
  "conversations/convMarkerQ2/messages/msgMarkerQ3": { text: `${MSG} tel:${P1}`, senderId: UID_A, phone: P1 },
  "conversations/convMarkerQ2/messages/msgMarkerQ3/reactions/deepMarkerQ9": { phone: P1 },
  "halaqat/halaqaMarkerQ7": { meetingLink: "https://wa.me/966500000001", phone: P1 },
  "academySettings/paymentPublic": { vodafoneCashDestination: BIZ, updatedBy: UID_A },
  "academySettings/billing": { supportPhone: P1, note: `contact ${P2}` },
  "payments/paymentMarkerQ6": { vodafoneCashDestination: BIZ, proofFileName: `receipt_${P1}.jpg` },
  "posts/postMarkerQ4": { content: "plain text" },
  "posts/postMarkerQ4/comments/cmtMarkerQ5": { text: `email me ${E1}` },
};

async function clearAll() {
  const res = await fetch(
    `http://${EXPECTED_ENV.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "firestore clear");
}

async function seed() {
  await clearAll();
  const batch = db.batch();
  for (const [path, data] of Object.entries(DOCS)) batch.set(db.doc(path), data);
  await batch.commit();
}

/** path -> { data, updateTime } for every seeded doc, plus the full collection tree. */
async function dump() {
  const out = {};
  const walk = async (refs) => {
    for (const col of refs) {
      for (const snap of (await col.get()).docs) {
        out[snap.ref.path] = { data: snap.data(), updateTime: `${snap.updateTime.seconds}.${snap.updateTime.nanoseconds}` };
        await walk(await snap.ref.listCollections());
      }
    }
  };
  await walk(await db.listCollections());
  return out;
}

function runCli(argv, env, { preloads = [] } = {}) {
  const base = {};
  for (const key of ["PATH", "Path", "SystemRoot", "TEMP", "TMP"]) if (process.env[key] !== undefined) base[key] = process.env[key];
  const imports = preloads.flatMap((f) => ["--import", pathToFileURL(join(here, f)).href]);
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [...imports, scriptPath, ...argv], {
      env: { ...base, ...env },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    const timer = setTimeout(() => child.kill(), 60000);
    child.on("error", reject);
    child.on("close", (status) => {
      clearTimeout(timer);
      resolve({ status, stdout, stderr });
    });
  });
}

const SCAN_ARGV = ["--project", PROJECT, "--scan", "--confirm", `contact-data-audit:${PROJECT}`];
const SCAN_ENV = {
  CONTACT_AUDIT_EMULATOR_OPT_IN: "1",
  CONTACT_AUDIT_PINNED_PORTS: `${FS_PORT},${HUB_PORT}`,
  ...EXPECTED_ENV,
};
const find = (report, collection, fieldPath, category) =>
  report.findings.find((f) => f.collection === collection && f.fieldPath === fieldPath && f.category === category);

async function freePort() {
  const server = net.createServer();
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const { port } = server.address();
  await new Promise((r) => server.close(r));
  return port;
}

test("CLI scan on the real emulator: categories, business destination, counts only, no writes", async () => {
  await seed();
  const before = await dump();
  assert.equal(Object.keys(before).length, Object.keys(DOCS).length);

  const r = await runCli(SCAN_ARGV, SCAN_ENV);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stderr, "");
  assertNoLeak(r.stdout, "CLI report");
  const report = JSON.parse(r.stdout);
  assert.equal(report.project, PROJECT);
  assert.equal(report.mode, "scan");
  assert.match(report.scope.auth, /disabled/);
  assert.match(report.scope.storage, /disabled/);

  const C = CATEGORY;
  assert.ok(find(report, "users", "phone", C.approvedKeyInCleanupScope));
  assert.ok(find(report, "userPrivate", "whatsapp", C.approvedKeyInCleanupScope));
  assert.ok(find(report, "halaqat", "phone", C.approvedKeyOutsideCleanupScope));
  assert.ok(find(report, "conversations/{}/messages", "phone", C.approvedKeyOutsideCleanupScope));
  assert.ok(find(report, "conversations/{}/messages/{}/reactions", "phone", C.approvedKeyOutsideCleanupScope));
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
  assert.equal(report.totals.documentsScanned, Object.keys(DOCS).length);

  assert.equal(report.allowedBusinessDestination.count, 1);
  assert.equal(report.findings.filter((f) => f.collection === "academySettings" && f.fieldPath === "vodafoneCashDestination").length, 0);
  assert.ok(find(report, "payments", "vodafoneCashDestination", C.textPhoneNumber), "same field elsewhere is not exempt");
  const settings = report.findings.filter((f) => f.collection === "academySettings");
  assert.ok(settings.length >= 2);
  assert.ok(settings.every((f) => f.category === C.businessConfigReview));

  for (const f of report.findings) {
    assert.deepEqual(Object.keys(f).sort(), ["category", "collection", "count", "fieldPath", "method"]);
    assert.equal(typeof f.count, "number");
  }

  assert.deepEqual(await dump(), before, "data and updateTimes unchanged");
});

test("max depth limits subcollection listing and is reported", async () => {
  await seed();
  const r = await runCli([...SCAN_ARGV, "--max-depth", "2"], SCAN_ENV);
  assert.equal(r.status, 0, r.stderr);
  const report = JSON.parse(r.stdout);
  assert.equal(report.collections["conversations/{}/messages/{}/reactions"], undefined);
  assert.ok(report.totals.documentsAtMaxDepthNotListed >= 1);
  assertNoLeak(r.stdout, "depth-limited report");
});

test("in-process scan on the real SDK matches the CLI and the store refuses every write path", async () => {
  await seed();
  const before = await dump();
  const store = readOnlyStore(db, FieldPath.documentId());
  for (const prop of ["batch", "runTransaction", "bulkWriter", "collection", "doc", "collectionGroup",
    "recursiveDelete", "set", "update", "delete", "create", "db", "firestore", "settings", "terminate"]) {
    assert.throws(() => store[prop], ReadOnlyViolation, prop);
  }
  assert.throws(() => { store.page = null; }, ReadOnlyViolation);
  assert.throws(() => { delete store.page; }, ReadOnlyViolation);
  assert.throws(() => Object.setPrototypeOf(store, {}), ReadOnlyViolation);

  const page = await store.page("users", null, 1);
  assert.equal(page.docs.length, 1);
  const doc = page.docs[0];
  for (const prop of ["ref", "set", "update", "delete", "create", "updateTime", "exists", "get"]) {
    assert.throws(() => doc[prop], ReadOnlyViolation, `document.${prop}`);
  }
  assert.ok(Object.isFrozen(page.next));
  assert.deepEqual(Reflect.ownKeys(page.next), [], "cursor exposes nothing");
  const page2 = await store.page("users", page.next, 1);
  assert.equal(page2.docs.length, 1);
  assert.notEqual(page2.docs[0].id, doc.id);

  const report = await runContactDataAudit({ store, detect, pageSize: 2 });
  const cli = JSON.parse((await runCli(SCAN_ARGV, SCAN_ENV)).stdout);
  const { project: _p, ...cliReport } = cli;
  assert.deepEqual(report, cliReport, "paged in-process scan equals CLI scan");
  assert.deepEqual(await dump(), before, "data and updateTimes unchanged");
});

test("CLI refusals against the running isolated emulator exit 2 before any SDK load", async () => {
  await seed();
  const before = await dump();
  const preloads = ["migrate-no-admin-preload.mjs", "migrate-egress-preload.mjs"];
  const gateCases = [
    ["live allowlisted project", ["--project", "rafiq-academy", "--scan", "--confirm", "contact-data-audit:rafiq-academy"], SCAN_ENV],
    ["live prod project", ["--project", "rafiq-academy-prod", "--scan", "--confirm", "contact-data-audit:rafiq-academy-prod"], SCAN_ENV],
    ["missing confirmation", ["--project", PROJECT, "--scan"], SCAN_ENV],
    ["wrong confirmation", ["--project", PROJECT, "--scan", "--confirm", "contact-data-audit:rafiq-academy"], SCAN_ENV],
    ["no opt-in", SCAN_ARGV, { ...SCAN_ENV, CONTACT_AUDIT_EMULATOR_OPT_IN: "" }],
    ["project env mismatch", SCAN_ARGV, { ...SCAN_ENV, GCLOUD_PROJECT: "rafiq-academy-prod" }],
    ["pinned ports do not match endpoints", SCAN_ARGV, { ...SCAN_ENV, CONTACT_AUDIT_PINNED_PORTS: `${FS_PORT + 1},${HUB_PORT}` }],
    ["default ports", SCAN_ARGV, { ...SCAN_ENV, CONTACT_AUDIT_PINNED_PORTS: "8080,4400",
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080", FIREBASE_EMULATOR_HUB: "127.0.0.1:4400" }],
    ["credentials set", SCAN_ARGV, { ...SCAN_ENV, GOOGLE_APPLICATION_CREDENTIALS: "C:\\nonexistent.json" }],
    ["write option", [...SCAN_ARGV, "--apply"], SCAN_ENV],
    ["auth option", [...SCAN_ARGV, "--auth"], SCAN_ENV],
  ];
  for (const [label, argv, env] of gateCases) {
    const r = await runCli(argv, { ...env, MIGRATE_IT_ALLOWED_PORTS: "" }, { preloads });
    assert.equal(r.status, 2, `${label}: ${r.stderr}`);
    assert.match(r.stderr, /refused:/, label);
    assert.equal(r.stdout, "", label);
    assert.doesNotMatch(r.stderr, /firebase-admin load attempted|egress blocked/, label);
  }

  // Firestore pinned to a port the real hub does not report.
  const wrongFs = await freePort();
  const mismatch = await runCli(SCAN_ARGV, {
    ...SCAN_ENV,
    CONTACT_AUDIT_PINNED_PORTS: `${wrongFs},${HUB_PORT}`,
    FIRESTORE_EMULATOR_HOST: `127.0.0.1:${wrongFs}`,
  }, { preloads: ["migrate-no-admin-preload.mjs"] });
  assert.equal(mismatch.status, 2, mismatch.stderr);
  assert.match(mismatch.stderr, /does not report Firestore on the pinned loopback port/);
  assert.doesNotMatch(mismatch.stderr, /firebase-admin load attempted/);

  // Hub pinned to a closed port.
  const wrongHub = await freePort();
  const noHub = await runCli(SCAN_ARGV, {
    ...SCAN_ENV,
    CONTACT_AUDIT_PINNED_PORTS: `${FS_PORT},${wrongHub}`,
    FIREBASE_EMULATOR_HUB: `127.0.0.1:${wrongHub}`,
  }, { preloads: ["migrate-no-admin-preload.mjs"] });
  assert.equal(noHub.status, 2, noHub.stderr);
  assert.match(noHub.stderr, /emulator hub could not be reached/);
  assert.doesNotMatch(noHub.stderr, /firebase-admin load attempted/);

  assert.deepEqual(await dump(), before, "refusals touched nothing");
});

test("no connection outside the pinned emulator ports was attempted", () => {
  assert.deepEqual(guard.blockedAttempts(), []);
});
