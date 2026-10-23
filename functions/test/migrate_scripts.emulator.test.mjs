/**
 * Migration scripts against the real Firebase Admin SDK and isolated
 * Firestore + Auth emulators. Synthetic data only.
 *
 * Refuses to start unless MIGRATE_EMULATOR_IT=1, MIGRATE_IT_PORTS lists the
 * non-default firestore,auth,hub ports, and the emulator env vars point at
 * exactly those loopback ports for project demo-rafiq-rules. A process-wide
 * egress guard (also preloaded into every CLI child) refuses any connection
 * that is not loopback to those ports.
 *
 *   firebase emulators:exec --config <isolated firebase.json> \
 *     --project demo-rafiq-rules --only firestore,auth \
 *     "node --test --test-concurrency=1 <repo>/functions/test/migrate_scripts.emulator.test.mjs"
 */
import test from "node:test";
import assert from "node:assert/strict";
import net from "node:net";
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";

const PROJECT = "demo-rafiq-rules";
const PORTS = (process.env.MIGRATE_IT_PORTS ?? "").split(",").map(Number);
const [FS_PORT, AUTH_PORT, HUB_PORT] = PORTS;
const EXPECTED_ENV = {
  FIRESTORE_EMULATOR_HOST: `127.0.0.1:${FS_PORT}`,
  FIREBASE_AUTH_EMULATOR_HOST: `127.0.0.1:${AUTH_PORT}`,
  FIREBASE_EMULATOR_HUB: `127.0.0.1:${HUB_PORT}`,
};
{
  const problems = [];
  if (process.env.MIGRATE_EMULATOR_IT !== "1") problems.push("MIGRATE_EMULATOR_IT must be 1");
  if (PORTS.length !== 3 || PORTS.some((p) => !Number.isInteger(p) || p < 1024 || p > 65535)) {
    problems.push("MIGRATE_IT_PORTS must be firestore,auth,hub");
  }
  if (PORTS.some((p) => [8080, 9099, 4400, 4000, 5001, 9199].includes(p))) {
    problems.push("default (possibly shared) emulator ports are refused");
  }
  for (const [key, value] of Object.entries(EXPECTED_ENV)) {
    if (process.env[key] !== value) problems.push(`${key} is not ${value}`);
  }
  for (const key of ["GCLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT"]) {
    if (process.env[key] && process.env[key] !== PROJECT) problems.push(`${key} is not ${PROJECT}`);
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) problems.push("GOOGLE_APPLICATION_CREDENTIALS must be unset");
  if (problems.length > 0) throw new Error(`isolation check failed: ${problems.join("; ")}`);
}
process.env.METADATA_SERVER_DETECTION = "none";

const guard = installEgressGuard({ allowedPorts: PORTS });
assert.equal(await guard.selfTest(), true, "egress guard self-test");

const { initializeApp } = await import("firebase-admin/app");
const { getAuth } = await import("firebase-admin/auth");
const { getFirestore, FieldValue, FieldPath, Timestamp } = await import("firebase-admin/firestore");
const { runContactFieldCleanup, CONTACT_FIELD_KEYS } = await import("../scripts/migrate-contact-fields.mjs");
const { runEmailBackfill, OUTCOME } = await import("../scripts/migrate-email-backfill.mjs");

const here = dirname(fileURLToPath(import.meta.url));
const scriptsDir = join(here, "..", "scripts");
const preloadUrl = pathToFileURL(join(here, "migrate-egress-preload.mjs")).href;

const app = initializeApp({ projectId: PROJECT }, "migrate-emulator-it");
const db = getFirestore(app);
const auth = getAuth(app);

// ── synthetic values (every one must stay out of reports) ──────────────────
const P1 = "01011112222";
const P2 = "+966500000001";
const P3 = "0599990000";
const N = ["Syn Name Alpha 4711", "Syn Name Beta 4712", "Syn Name Gamma 4713", "Syn Name Delta 4714"];
const BIO = "Synthetic bio marker Z9Q";
const CITY = "Synthetic City Marker K2";
const mail = (tag) => `synthetic.${tag}@example.test`;
const TS = Timestamp.fromMillis(Date.UTC(2026, 0, 2));
const SECRETS = [P1, P2, P3, ...N, BIO, CITY, "@example.test", "@"];

function assertNoLeak(text, label) {
  for (const secret of SECRETS) assert.ok(!text.includes(secret), `${label} leaked a synthetic value`);
}

// ── emulator helpers ───────────────────────────────────────────────────────
async function clearAll() {
  const fsRes = await fetch(
    `http://${EXPECTED_ENV.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(fsRes.ok, true, "firestore clear");
  const authRes = await fetch(
    `http://${EXPECTED_ENV.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/accounts`,
    { method: "DELETE" },
  );
  assert.equal(authRes.ok, true, "auth clear");
}

async function seedDocs(docs) {
  const batch = db.batch();
  for (const [path, data] of Object.entries(docs)) batch.set(db.doc(path), data);
  await batch.commit();
}

const ALL_COLLECTIONS = [
  "users", "userPrivate", "parentProfiles", "studentProfiles", "teacherProfiles",
  "supervisorProfiles", "studentSearch", "halaqat",
];

/** path -> { data, updateTime } for every doc, including one known subcollection. */
async function dump() {
  const out = {};
  const add = (snap) => {
    out[snap.ref.path] = { data: snap.data(), updateTime: `${snap.updateTime.seconds}.${snap.updateTime.nanoseconds}` };
  };
  for (const name of ALL_COLLECTIONS) (await db.collection(name).get()).docs.forEach(add);
  (await db.collection("users/u1/devices").get()).docs.forEach(add);
  return out;
}

const dataOf = (d) => Object.fromEntries(Object.entries(d).map(([p, v]) => [p, v.data]));
const without = (data, keys) => Object.fromEntries(Object.entries(data).filter(([k]) => !keys.includes(k)));

/** Real db, but lets a test write "concurrently" right after a read returns. */
function racingDb({ afterQuery = async () => {}, afterDocGet = async () => {} }) {
  const wrapQuery = (q, name) => ({
    orderBy: (...a) => wrapQuery(q.orderBy(...a), name),
    limit: (n) => wrapQuery(q.limit(n), name),
    startAfter: (s) => wrapQuery(q.startAfter(s), name),
    get: async () => {
      const snap = await q.get();
      await afterQuery(name, snap);
      return snap;
    },
  });
  return {
    collection: (name) => ({
      ...wrapQuery(db.collection(name), name),
      doc: (id) => {
        const ref = db.collection(name).doc(id);
        return {
          id,
          get: async () => {
            const snap = await ref.get();
            await afterDocGet(`${name}/${id}`);
            return snap;
          },
          create: (data) => ref.create(data),
          update: (data, pre) => ref.update(data, pre),
        };
      },
    }),
  };
}

const cleanup = (mode, target = db, opts = {}) =>
  runContactFieldCleanup({ db: target, mode, FieldValue, documentId: FieldPath.documentId(), ...opts });

async function* listAuthUsers() {
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) yield { uid: user.uid, email: user.email ?? null };
    pageToken = page.pageToken;
  } while (pageToken);
}

const backfill = (mode, target = db) =>
  runEmailBackfill({ db: target, listAuthUsers, mode, FieldValue, documentId: FieldPath.documentId() });

// ── fixtures ───────────────────────────────────────────────────────────────
const cleanupSeed = () => ({
  "users/u1": { name: N[0], role: "parent", isActive: true, phone: P1, createdAt: TS, email: mail("legacy-u1") },
  "users/u2": { name: N[1], role: "student", isActive: true, email: mail("u2"), prefs: { lang: "ar" } },
  "users/u1/devices/d1": { token: "t", phone: P1 },
  "userPrivate/u1": { phone: P1, updatedAt: TS, migratedFromUsers: true },
  "userPrivate/u3": { email: mail("u3"), whatsapp: P2, mobile: "", phoneNumber: null },
  "parentProfiles/u1": { childrenIds: ["s1"], phone: P2, guardianPhone: P1, address: { city: CITY } },
  "studentProfiles/s1": {
    halaqaId: "h1", parentPhone: P1, score: 12,
    guardian: { name: N[2], phone: P2 }, contacts: [{ mobile: P1 }], emergencyPhone: P3,
  },
  "teacherProfiles/t1": { bio: BIO, phone: "" },
  "supervisorProfiles/v1": { name: N[3] },
  "studentSearch/s1": { nameNormalized: "syn alpha", parentPhone: P1 },
  "halaqat/h1": { name: "Halaqa", phone: P1 },
});

async function seedBackfill() {
  const accounts = [
    { uid: "create1", email: mail("create1") },
    { uid: "add1", email: mail("add1") },
    { uid: "current1", email: mail("current1") },
    { uid: "conflict1", email: mail("conflict1") },
    { uid: "invalid1", email: mail("invalid1") },
    { uid: "blocked1", email: mail("blocked1") },
    { uid: "noemail1" },
    { uid: "noprofile1", email: mail("noprofile1") },
  ];
  for (const account of accounts) await auth.createUser(account);
  await seedDocs({
    "users/create1": { name: N[0], role: "student", isActive: true, createdAt: TS },
    "users/add1": { name: N[1], role: "parent", isActive: true, email: mail("legacy-add1") },
    "users/current1": { name: N[2], role: "teacher", isActive: true, email: mail("current1") },
    "users/conflict1": { name: N[3], role: "parent", isActive: true },
    "users/invalid1": { name: N[0], role: "parent", isActive: true },
    "users/blocked1": { name: N[1], role: "parent", isActive: true },
    "users/noemail1": { name: N[2], role: "student", isActive: true, email: mail("legacy-only") },
    "users/orphan1": { name: N[3], role: "student", isActive: false, email: mail("orphan") },
    "userPrivate/add1": { updatedAt: TS, migratedFromUsers: true },
    // Auth stores emails lower-case; an upper-case private copy must count as current.
    "userPrivate/current1": { email: mail("current1").toUpperCase(), emailSource: "auth", emailUpdatedAt: TS },
    "userPrivate/conflict1": { email: mail("someone-else"), emailSource: "auth" },
    "userPrivate/invalid1": { email: 42 },
    "userPrivate/blocked1": { phone: P1, email: mail("blocked1") },
  });
}

// ── CLI helpers ────────────────────────────────────────────────────────────
function baseChildEnv() {
  const env = {};
  for (const key of ["PATH", "Path", "SystemRoot", "SYSTEMROOT", "TEMP", "TMP", "windir"]) {
    if (process.env[key] !== undefined) env[key] = process.env[key];
  }
  // No APPDATA/HOME: firebase-admin cannot discover gcloud credentials.
  return { ...env, METADATA_SERVER_DETECTION: "none" };
}

function runCli(script, argv, env, allowedPorts = PORTS) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ["--import", preloadUrl, join(scriptsDir, script), ...argv], {
      env: { ...baseChildEnv(), MIGRATE_IT_ALLOWED_PORTS: allowedPorts.join(","), ...env },
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

const emulatorEnv = {
  FIRESTORE_EMULATOR_HOST: EXPECTED_ENV.FIRESTORE_EMULATOR_HOST,
  FIREBASE_AUTH_EMULATOR_HOST: EXPECTED_ENV.FIREBASE_AUTH_EMULATOR_HOST,
};

// ── tests ──────────────────────────────────────────────────────────────────
test("isolation: hub lists only this run's firestore + auth on the pinned ports", async () => {
  const res = await fetch(`http://${EXPECTED_ENV.FIREBASE_EMULATOR_HUB}/emulators`);
  const emulators = await res.json();
  assert.equal(emulators.firestore.port, FS_PORT);
  assert.equal(emulators.auth.port, AUTH_PORT);
  assert.equal(emulators.hub.port, HUB_PORT);
  for (const name of ["functions", "storage", "database", "pubsub", "hosting"]) {
    assert.equal(emulators[name], undefined, `${name} must not be running`);
  }
});

test("cleanup dry run (real SDK): counts only, no document written", async () => {
  await clearAll();
  await seedDocs(cleanupSeed());
  const before = await dump();
  const report = await cleanup("dry-run");
  assert.deepEqual(await dump(), before, "data and updateTime unchanged");
  assert.equal(report.totals.docsWithContactFields, 7);
  assert.equal(report.totals.fieldsToRemove, 10);
  assert.equal(report.totals.docsUpdated, 0);
  assertNoLeak(JSON.stringify(report), "cleanup dry-run report");
});

test("cleanup apply (real SDK): removes only approved top-level keys; nested/look-alike untouched", async () => {
  await clearAll();
  await seedDocs(cleanupSeed());
  const before = await dump();
  const report = await cleanup("apply");
  const after = await dump();

  assert.equal(report.totals.docsUpdated, 7);
  assert.equal(report.totals.errors, 0);
  assert.deepEqual(Object.keys(after).sort(), Object.keys(before).sort(), "no document added or deleted");
  const targets = new Set(["users", "userPrivate", "parentProfiles", "studentProfiles", "teacherProfiles", "supervisorProfiles", "studentSearch"]);
  for (const [path, entry] of Object.entries(before)) {
    const segments = path.split("/");
    const topLevelTarget = segments.length === 2 && targets.has(segments[0]);
    const expected = topLevelTarget ? without(entry.data, CONTACT_FIELD_KEYS) : entry.data;
    assert.deepEqual(after[path].data, expected, path);
    const hadContact = CONTACT_FIELD_KEYS.some((k) => k in entry.data);
    if (!topLevelTarget || !hadContact) assert.equal(after[path].updateTime, entry.updateTime, `${path} not rewritten`);
  }
  // Timestamps survive as real Timestamps; nested and look-alike data stays.
  assert.ok(after["users/u1"].data.createdAt.isEqual(TS));
  assert.deepEqual(after["studentProfiles/s1"].data.guardian, { name: N[2], phone: P2 });
  assert.deepEqual(after["studentProfiles/s1"].data.contacts, [{ mobile: P1 }]);
  assert.equal(after["studentProfiles/s1"].data.emergencyPhone, P3);
  assert.equal(after["users/u1/devices/d1"].data.phone, P1, "subcollections are out of scope");
  assert.equal(after["halaqat/h1"].data.phone, P1, "non-target collections are untouched");
  assert.deepEqual(Object.keys(after["userPrivate/u1"].data).sort(), ["migratedFromUsers", "updatedAt"]);

  const sp = report.collections.studentProfiles.review;
  assert.equal(sp.docsWithNestedContactKeys, 1);
  assert.deepEqual(sp.phoneLikeKeyNames, { emergencyPhone: 1 });
  assert.equal(report.collections.userPrivate.review.docsWithMigratedFromUsersMarker, 1);
  assertNoLeak(JSON.stringify(report), "cleanup apply report");
});

test("cleanup rerun (real SDK): nothing found, no updateTime changes", async () => {
  const settled = await dump();
  const again = await cleanup("apply");
  assert.equal(again.totals.docsWithContactFields, 0);
  assert.equal(again.totals.docsUpdated, 0);
  assert.deepEqual(await dump(), settled);
});

test("cleanup precondition (real SDK): a doc changed after the read is skipped, not overwritten", async () => {
  await clearAll();
  await seedDocs(cleanupSeed());
  let raced = false;
  const target = racingDb({
    afterQuery: async (name) => {
      if (name === "users" && !raced) {
        raced = true;
        await db.doc("users/u1").update({ name: "Edited meanwhile" });
      }
    },
  });
  const report = await cleanup("apply", target);
  assert.equal(raced, true);
  assert.equal(report.collections.users.skippedChangedSinceRead, 1);
  assert.deepEqual(report.collections.users.errors, {});
  const u1 = (await db.doc("users/u1").get()).data();
  assert.equal(u1.name, "Edited meanwhile");
  assert.equal(u1.phone, P1, "left for the next run");
  assert.equal((await db.doc("parentProfiles/u1").get()).data().phone, undefined, "others still cleaned");
});

test("cleanup paging (real SDK): every document visited once across pages", async () => {
  await clearAll();
  const docs = {};
  for (let i = 0; i < 23; i++) docs[`users/p${String(i).padStart(2, "0")}`] = { name: "n", phone: P1 };
  await seedDocs(docs);
  const report = await cleanup("apply", db, { collections: ["users"], pageSize: 5 });
  assert.equal(report.collections.users.scanned, 23);
  assert.equal(report.collections.users.docsUpdated, 23);
});

test("backfill dry run (real SDK + Auth emulator): outcomes counted, nothing written", async () => {
  await clearAll();
  await seedBackfill();
  const before = await dump();
  const report = await backfill("dry-run");
  assert.deepEqual(await dump(), before);
  assert.equal(report.authAccounts, 8);
  assert.equal(report.usersDocs, 8);
  assert.deepEqual(report.outcomes, {
    [OUTCOME.noAppProfile]: 1,
    [OUTCOME.missingAuthEmail]: 1,
    [OUTCOME.blockedByContactField]: 1,
    [OUTCOME.alreadyCurrent]: 1,
    [OUTCOME.conflictDiffers]: 1,
    [OUTCOME.conflictInvalid]: 1,
    [OUTCOME.create]: 1,
    [OUTCOME.addEmail]: 1,
  });
  assert.deepEqual(report.review[OUTCOME.conflictDiffers].toJSON().ids, ["conflict1"]);
  assert.deepEqual(report.review[OUTCOME.conflictInvalid].toJSON().ids, ["invalid1"]);
  assert.deepEqual(report.review[OUTCOME.missingAuthEmail].toJSON().ids, ["noemail1"]);
  assert.deepEqual(report.review[OUTCOME.blockedByContactField].toJSON().ids, ["blocked1"]);
  assert.deepEqual(report.review.usersDocsWithoutAuthAccount.toJSON().ids, ["orphan1"]);
  assertNoLeak(JSON.stringify(report), "backfill dry-run report");
});

test("backfill apply (real SDK): creates/adds from Auth only; conflicts, blocked and users untouched", async () => {
  const before = await dump();
  const report = await backfill("apply");
  const after = await dump();

  assert.deepEqual(report.written, { created: 1, emailAdded: 1, skippedChangedSinceRead: 0 });
  assert.deepEqual(report.errors, {});

  const created = after["userPrivate/create1"].data;
  assert.deepEqual(Object.keys(created).sort(), ["email", "emailSource", "emailUpdatedAt"]);
  assert.equal(created.email, mail("create1"));
  assert.equal(created.emailSource, "auth");
  assert.ok(created.emailUpdatedAt instanceof Timestamp, "server timestamp resolved");

  const added = after["userPrivate/add1"].data;
  assert.equal(added.email, mail("add1"), "Auth wins over legacy users.email");
  assert.equal(added.migratedFromUsers, true);
  assert.ok(added.updatedAt.isEqual(TS));

  for (const path of ["userPrivate/current1", "userPrivate/conflict1", "userPrivate/invalid1", "userPrivate/blocked1"]) {
    assert.deepEqual(after[path], before[path], `${path} unchanged (data + updateTime)`);
  }
  assert.equal(after["userPrivate/noemail1"], undefined, "no fallback to users.email");
  assert.equal(after["userPrivate/noprofile1"], undefined);
  for (const [path, entry] of Object.entries(before)) {
    if (path.startsWith("users/")) assert.deepEqual(after[path], entry, `${path} never written`);
  }
  assert.equal(after["users/add1"].data.email, mail("legacy-add1"), "users.email kept");
  assertNoLeak(JSON.stringify(report), "backfill apply report");
});

test("backfill rerun (real SDK): no writes, no updateTime changes", async () => {
  const settled = await dump();
  const again = await backfill("apply");
  assert.deepEqual(again.written, { created: 0, emailAdded: 0, skippedChangedSinceRead: 0 });
  assert.equal(again.outcomes[OUTCOME.alreadyCurrent], 3);
  assert.deepEqual(await dump(), settled);
});

test("backfill preconditions (real SDK): create race and update race are skipped", async () => {
  await clearAll();
  await seedBackfill();
  const target = racingDb({
    afterDocGet: async (path) => {
      if (path === "userPrivate/create1") await db.doc(path).create({ email: mail("raced"), emailSource: "auth" });
      if (path === "userPrivate/add1") await db.doc(path).update({ updatedAt: Timestamp.fromMillis(1) });
    },
  });
  const report = await backfill("apply", target);
  assert.equal(report.written.skippedChangedSinceRead, 2);
  assert.deepEqual(report.errors, {});
  assert.deepEqual(report.review.skippedChangedSinceRead.toJSON().ids.sort(), ["add1", "create1"]);
  assert.equal((await db.doc("userPrivate/create1").get()).data().email, mail("raced"));
  const add1 = (await db.doc("userPrivate/add1").get()).data();
  assert.equal(add1.email, undefined, "update race not overwritten");
  assert.ok(add1.updatedAt.isEqual(Timestamp.fromMillis(1)));
});

test("CLI end-to-end (real main): dry run, confirmed apply, rerun — both scripts", async () => {
  await clearAll();
  await seedDocs(cleanupSeed());
  await seedBackfill();
  const env = emulatorEnv;

  const before = await dump();
  for (const script of ["migrate-contact-fields.mjs", "migrate-email-backfill.mjs"]) {
    const r = await runCli(script, ["--project", PROJECT], env);
    assert.equal(r.status, 0, r.stderr);
    assert.equal(JSON.parse(r.stdout).mode, "dry-run");
    assert.doesNotMatch(r.stderr, /egress blocked/);
    assertNoLeak(r.stdout + r.stderr, `${script} dry-run output`);
  }
  assert.deepEqual(await dump(), before, "CLI dry runs wrote nothing");

  const c = await runCli("migrate-contact-fields.mjs",
    ["--project", PROJECT, "--apply", "--confirm", `contact-field-cleanup:${PROJECT}`], env);
  assert.equal(c.status, 0, c.stderr);
  const cReport = JSON.parse(c.stdout);
  assert.equal(cReport.mode, "apply");
  assert.ok(cReport.totals.docsUpdated > 0);
  assertNoLeak(c.stdout + c.stderr, "cleanup apply output");

  const b = await runCli("migrate-email-backfill.mjs",
    ["--project", PROJECT, "--apply", "--confirm", `email-backfill:${PROJECT}`], env);
  assert.equal(b.status, 0, b.stderr);
  const bReport = JSON.parse(b.stdout);
  // Cleanup ran first, so blocked1's phone is gone and it is now already current.
  assert.equal(bReport.outcomes[OUTCOME.blockedByContactField], 0);
  assert.equal(bReport.written.created + bReport.written.emailAdded, 2);
  assertNoLeak(b.stdout + b.stderr, "backfill apply output");

  const settled = await dump();
  for (const [script, token] of [["migrate-contact-fields.mjs", "contact-field-cleanup"], ["migrate-email-backfill.mjs", "email-backfill"]]) {
    const r = await runCli(script, ["--project", PROJECT, "--apply", "--confirm", `${token}:${PROJECT}`], env);
    assert.equal(r.status, 0, r.stderr);
    const rep = JSON.parse(r.stdout);
    if (rep.totals) assert.equal(rep.totals.docsUpdated, 0);
    else assert.deepEqual(rep.written, { created: 0, emailAdded: 0, skippedChangedSinceRead: 0 });
    assert.doesNotMatch(r.stderr, /egress blocked/);
  }
  assert.deepEqual(await dump(), settled, "CLI reruns wrote nothing");
});

test("CLI refusals happen before any data access", async () => {
  await clearAll();
  await seedDocs(cleanupSeed());
  const before = await dump();

  // A loopback sentinel stands in for the emulators: any connection is a failure.
  let connections = 0;
  const sentinel = net.createServer((socket) => {
    connections += 1;
    socket.destroy();
  });
  await new Promise((r) => sentinel.listen(0, "127.0.0.1", r));
  const port = sentinel.address().port;
  const fake = { FIRESTORE_EMULATOR_HOST: `127.0.0.1:${port}`, FIREBASE_AUTH_EMULATOR_HOST: `127.0.0.1:${port}` };

  const cases = [
    ["wrong project (not allowlisted)", "migrate-contact-fields.mjs", ["--project", "someone-elses-project"], fake],
    ["real project with emulator env (live/emulator mix)", "migrate-contact-fields.mjs", ["--project", "rafiq-academy-staging"], fake],
    ["real project, correct token, emulator env", "migrate-email-backfill.mjs",
      ["--project", "rafiq-academy-prod", "--apply", "--confirm", "email-backfill:rafiq-academy-prod"], fake],
    ["apply without confirmation", "migrate-contact-fields.mjs", ["--project", PROJECT, "--apply"], fake],
    ["confirmation for another project", "migrate-contact-fields.mjs",
      ["--project", PROJECT, "--apply", "--confirm", "contact-field-cleanup:rafiq-academy"], fake],
    ["confirmation for the other script", "migrate-email-backfill.mjs",
      ["--project", PROJECT, "--apply", "--confirm", `contact-field-cleanup:${PROJECT}`], fake],
    ["env project mismatch", "migrate-contact-fields.mjs", ["--project", PROJECT],
      { ...fake, GOOGLE_CLOUD_PROJECT: "rafiq-academy-prod" }],
    ["demo project without emulator env", "migrate-contact-fields.mjs", ["--project", PROJECT], {}],
    ["backfill demo project without Auth emulator", "migrate-email-backfill.mjs", ["--project", PROJECT],
      { FIRESTORE_EMULATOR_HOST: fake.FIRESTORE_EMULATOR_HOST }],
  ];
  try {
    for (const [label, script, argv, env] of cases) {
      const r = await runCli(script, argv, env, [port]);
      assert.equal(r.status, 2, `${label}: ${r.stderr}`);
      assert.match(r.stderr, /refused:/, label);
      assert.equal(r.stdout, "", label);
      assert.doesNotMatch(r.stderr, /egress blocked/, label);
      assertNoLeak(r.stderr, label);
    }
    await new Promise((r) => setTimeout(r, 200));
    assert.equal(connections, 0, "no refused run opened a connection");
  } finally {
    await new Promise((r) => sentinel.close(r));
  }
  assert.deepEqual(await dump(), before, "refused runs changed nothing");
});

test("no connection outside the isolated emulators was attempted", () => {
  assert.deepEqual(guard.blockedAttempts(), []);
});

test.after(async () => {
  await clearAll().catch(() => {});
});
