/**
 * Demo dataset v2 contract (scripts/seed-emulator-dataset.mjs): fixed UIDs,
 * no personal phone numbers anywhere, email only in userPrivate, and fields and values identical
 * to what adminProvisionUser writes today (read from the current sources), including
 * nameNormalized from the compiled backend normalizer and the pending first-login flags of an
 * Admin. Writes go only to in-memory doubles: nothing reaches an emulator or Firebase.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildDemoDataset,
  classifyEmulatorState,
  DEMO_ACCOUNTS,
  DEMO_PASSWORD,
  DEMO_SEED_VERSION,
  SEED_META,
  SERVER_TIMESTAMP,
  writeDemoDataset,
} from "../scripts/seed-emulator-dataset.mjs";

const require = createRequire(import.meta.url);
// The compiled Functions modules, the same code adminProvisionUser and the
// callables run (`npm run build` first).
const { normalizeArabicSearchText, ARABIC_NORMALIZATION_VECTORS } = require("../lib/search/arabicNormalization.js");
const { ALLOWED_PROVISION_ROLES } = require("../lib/admin/assertAdmin.js");
const { activeRoleOf } = require("../lib/authority/callerContext.js");
const { completeFirstLoginCore } = require("../lib/accounts/onboardingFunctions.js");

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const repoRoot = join(functionsDir, "..");
const read = (...p) => readFileSync(join(...p), "utf8");

const provisionSource = read(functionsDir, "src", "admin", "adminProvisionUser.ts");
const assertAdminSource = read(functionsDir, "src", "admin", "assertAdmin.ts");
const userModelSource = read(repoRoot, "lib", "features", "auth", "data", "models", "user_model.dart");
const dartDatasetSource = read(repoRoot, "tool", "demo_academy_dataset.dart");
const rulesSource = read(repoRoot, "firestore.rules");
const datasetSource = read(functionsDir, "scripts", "seed-emulator-dataset.mjs");

/** `{ ... }` block (braces included) starting at the first `{` at or after `from`. */
function blockAt(source, from) {
  const start = source.indexOf("{", from);
  assert.ok(start >= 0, `no block after offset ${from}`);
  let depth = 0;
  let end = start;
  for (; end < source.length; end++) {
    if (source[end] === "{") depth++;
    if (source[end] === "}" && --depth === 0) break;
  }
  return { start, end, text: source.slice(start, end + 1) };
}

/** [key, value expression] of each top-level entry in `{ ... }` source; shorthand `uid` is ["uid", "uid"]. */
function objectEntries(block) {
  const body = block
    .slice(1, -1)
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/.*$/gm, "");
  const entries = [];
  let level = 0;
  let current = "";
  for (const ch of body) {
    if ("{[(".includes(ch)) level++;
    if ("}])".includes(ch)) level--;
    if (ch === "," && level === 0) {
      entries.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  entries.push(current);
  return entries
    .map((e) => e.trim())
    .filter(Boolean)
    .map((e) => {
      const [, key, value] = /^([A-Za-z_$][\w$]*)\s*(?::\s*([\s\S]+))?$/.exec(e);
      return [key, (value ?? key).trim()];
    });
}

/** Entries of the first object literal after `anchor` in TS source. */
function objectEntriesAfter(source, anchor) {
  const match = anchor.exec(source);
  assert.ok(match, `anchor not found: ${anchor}`);
  return objectEntries(blockAt(source, match.index + match[0].length).text);
}

// Matches both `collection(c).doc(uid).set({` and `batch.set(db.collection(c).doc(uid), {`.
const provisionEntries = (collection) =>
  objectEntriesAfter(provisionSource, new RegExp(`collection\\("${collection}"\\)\\.doc\\(uid\\)(?:\\.set\\(|,)`));
const provisionKeys = (collection) => provisionEntries(collection).map(([key]) => key).sort();

// adminProvisionUser adds fields with batch.update after its batch.set; the
// ones inside `if (role === "admin") { ... }` apply to Admins only.
const adminOnlyBlock = (() => {
  const at = provisionSource.indexOf('if (role === "admin") {');
  assert.ok(at > 0, "adminProvisionUser admin-only block");
  return blockAt(provisionSource, at);
})();
const updateEntries = (source, collection) =>
  [...source.matchAll(new RegExp(`batch\\.update\\(db\\.collection\\("${collection}"\\)\\.doc\\(uid\\),\\s*\\{`, "g"))]
    .flatMap((m) => objectEntries(blockAt(source, m.index + m[0].length - 1).text));
const provisionUpdates = (collection) => ({
  everyone: updateEntries(
    provisionSource.slice(0, adminOnlyBlock.start) + provisionSource.slice(adminOnlyBlock.end + 1),
    collection,
  ),
  adminOnly: updateEntries(adminOnlyBlock.text, collection),
});

/** Value adminProvisionUser writes for `expression`, in dataset terms. */
function provisionedValue(expression, account) {
  switch (expression) {
    case "now":
    case "FieldValue.serverTimestamp()":
      return SERVER_TIMESTAMP;
    case "uid":
      return account.uid;
    case "name":
      return account.name;
    case "email":
      return account.email;
    case "role":
      return account.role;
    case "isActive":
      return true; // the callable's default; every demo account is active
    case "normalizeArabicSearchText(name)":
      return normalizeArabicSearchText(account.name);
    default:
      return JSON.parse(expression);
  }
}
const expectedData = (entries, account) =>
  Object.fromEntries(entries.map(([key, expression]) => [key, provisionedValue(expression, account)]));

const dataset = buildDemoDataset();
const docsIn = (collection) => dataset.documents.filter((d) => d.collection === collection);
const docOf = (collection, uid) => dataset.documents.find((d) => d.collection === collection && d.id === uid);
const keysOf = (doc) => Object.keys(doc.data).sort();

test("UIDs are fixed and unique; emails are unique demo addresses", () => {
  assert.deepEqual(
    DEMO_ACCOUNTS.map((a) => a.uid),
    ["demo-admin-01", "demo-supervisor-01", "demo-teacher-01", "demo-parent-01", "demo-student-01", "demo-student-02"],
  );
  assert.deepEqual(buildDemoDataset().authUsers, dataset.authUsers, "deterministic");
  for (const key of ["uid", "email"]) {
    const values = DEMO_ACCOUNTS.map((a) => a[key]);
    assert.equal(new Set(values).size, values.length, key);
  }
  for (const a of DEMO_ACCOUNTS) {
    assert.match(a.uid, /^demo-[a-z]+-\d{2}$/);
    assert.match(a.email, /^[a-z0-9]+@rafiq\.demo$/);
  }
  assert.deepEqual(dataset.authUsers.map((u) => u.uid), DEMO_ACCOUNTS.map((a) => a.uid));
});

test("accounts match the Dart demo catalog (email, role, name)", () => {
  for (const a of DEMO_ACCOUNTS) {
    const match = new RegExp(
      `DemoAccount\\(\\s*email:\\s*'${a.email.replace(".", "\\.")}',\\s*role:\\s*AppRoles\\.(\\w+),\\s*name:\\s*'([^']+)'`,
    ).exec(dartDatasetSource);
    assert.ok(match, a.email);
    assert.equal(match[1], a.role, a.email);
    assert.equal(match[2], a.name, a.email);
  }
});

test("roles are provisionable roles", () => {
  for (const a of DEMO_ACCOUNTS) {
    assert.ok(assertAdminSource.includes(`"${a.role}"`), a.role);
  }
});

test("no personal phone number is seeded anywhere (no-phone policy)", () => {
  const contactKeys = ["phone", "phoneNumber", "mobile", "whatsapp", "parentPhone", "guardianPhone"];
  for (const account of DEMO_ACCOUNTS) {
    for (const key of contactKeys) assert.equal(key in account, false, `${account.uid}.${key}`);
  }
  for (const doc of dataset.documents) {
    for (const key of contactKeys) assert.equal(key in doc.data, false, `${doc.collection}/${doc.id}.${key}`);
  }
  for (const doc of docsIn("userPrivate")) {
    for (const key of keysOf(doc)) {
      assert.ok(["email", "emailSource", "emailUpdatedAt", "mustChangePassword"].includes(key), `${doc.id}.${key}`);
    }
  }
  assert.doesNotMatch(JSON.stringify(dataset), /phone|whatsapp|\b05\d{8}\b|\b01[0125]\d{8}\b/i);
  assert.doesNotMatch(datasetSource.replace(/\/\*[\s\S]*?\*\/|\/\/.*$/gm, ""), /phone/i);
});

test("adminProvisionUser's users and userPrivate writes are the ones this contract mirrors", () => {
  assert.deepEqual(provisionKeys("users"), ["createdAt", "isActive", "name", "role"]);
  assert.deepEqual(provisionKeys("userPrivate"), ["email", "emailSource", "emailUpdatedAt"]);
  assert.deepEqual(provisionUpdates("users"), {
    everyone: [["nameNormalized", "normalizeArabicSearchText(name)"]],
    adminOnly: [["passwordChangeRequired", "true"]],
  });
  assert.deepEqual(provisionUpdates("userPrivate"), { everyone: [], adminOnly: [["mustChangePassword", "true"]] });
});

test("users documents equal what adminProvisionUser writes for each account, values included", () => {
  const { everyone, adminOnly } = provisionUpdates("users");
  assert.equal(docsIn("users").length, DEMO_ACCOUNTS.length);
  for (const a of DEMO_ACCOUNTS) {
    const entries = [...provisionEntries("users"), ...everyone, ...(a.role === "admin" ? adminOnly : [])];
    assert.deepEqual(docOf("users", a.uid).data, expectedData(entries, a), a.uid);
  }
});

test("users fields the app writes itself stay within UserModel.toFirestore; the rest are server-only", () => {
  const toFirestore = userModelSource.slice(userModelSource.indexOf("toFirestore()"));
  const dartKeys = [...toFirestore.slice(0, toFirestore.indexOf("};")).matchAll(/'(\w+)':/g)].map((m) => m[1]);
  const serverOnly = ["nameNormalized", "passwordChangeRequired"];
  for (const doc of docsIn("users")) {
    for (const key of keysOf(doc)) {
      assert.ok(dartKeys.includes(key) || serverOnly.includes(key), `${doc.id}.${key}`);
    }
  }
  for (const key of serverOnly) assert.equal(dartKeys.includes(key), false, `${key} is never written by the app`);
  // The app reads the pending-Admin flag (it routes to the password change).
  assert.match(userModelSource, /mustChangePassword: data\['passwordChangeRequired'\] == true/);
});

test("email lives only in userPrivate, with the fields adminProvisionUser writes", () => {
  const { adminOnly } = provisionUpdates("userPrivate");
  assert.equal(docsIn("userPrivate").length, DEMO_ACCOUNTS.length);
  for (const a of DEMO_ACCOUNTS) {
    const priv = docOf("userPrivate", a.uid);
    assert.ok(priv, a.uid);
    const entries = [...provisionEntries("userPrivate"), ...(a.role === "admin" ? adminOnly : [])];
    assert.deepEqual(priv.data, expectedData(entries, a), a.uid);
    assert.equal(priv.data.email === a.email, true, `${a.uid}: email matches its Auth account`);
    assert.equal(priv.data.emailSource, "auth", a.uid);
  }
  for (const doc of dataset.documents.filter((d) => d.collection !== "userPrivate")) {
    assert.equal("email" in doc.data, false, `${doc.collection}/${doc.id}`);
  }
});

test("role profile fields and values equal adminProvisionUser's writeRoleProfile", () => {
  for (const collection of ["studentProfiles", "parentProfiles", "teacherProfiles"]) {
    const entries = provisionEntries(collection);
    assert.ok(docsIn(collection).length > 0, collection);
    for (const doc of docsIn(collection)) {
      const account = DEMO_ACCOUNTS.find((a) => a.uid === doc.id);
      assert.deepEqual(doc.data, expectedData(entries, account), `${collection}/${doc.id}`);
    }
  }
});

test("supervisor, assistant_teacher and admin get no profile document, as in writeRoleProfile", () => {
  assert.deepEqual([...ALLOWED_PROVISION_ROLES].sort(), [
    "admin", "assistant_teacher", "parent", "student", "supervisor", "teacher",
  ]);
  const roleProfile = provisionSource.slice(provisionSource.indexOf("export async function writeRoleProfile"));
  assert.match(
    roleProfile,
    /case "supervisor":\s*case "assistant_teacher":\s*case "admin":\s*(?:\/\/[^\n]*\n\s*)*break;/,
    "these roles fall through to a bare break in writeRoleProfile",
  );
  // Every provisionable role, including one the demo catalog does not use.
  const everyRole = buildDemoDataset(
    ALLOWED_PROVISION_ROLES.map((role, i) => ({ uid: `role-${i}`, email: `r${i}@rafiq.demo`, name: `اسم ${i}`, role })),
  );
  const profiles = everyRole.documents.filter((d) => !["users", "userPrivate"].includes(d.collection));
  const byRole = Object.fromEntries(
    ALLOWED_PROVISION_ROLES.map((role, i) => [role, profiles.filter((d) => d.id === `role-${i}`).map((d) => d.collection)]),
  );
  assert.deepEqual(byRole, {
    student: ["studentProfiles"],
    parent: ["parentProfiles"],
    teacher: ["teacherProfiles"],
    supervisor: [],
    assistant_teacher: [],
    admin: [],
  });
});

test("each account gets exactly the profile adminProvisionUser gives its role", () => {
  const profileCollection = { student: "studentProfiles", parent: "parentProfiles", teacher: "teacherProfiles" };
  for (const a of DEMO_ACCOUNTS) {
    const profiles = dataset.documents.filter((d) => d.id === a.uid && d.collection.endsWith("Profiles"));
    assert.deepEqual(profiles.map((p) => p.collection), profileCollection[a.role] ? [profileCollection[a.role]] : [], a.uid);
  }
});

test("only known collections are written; all fit in one batch", () => {
  const collections = new Set(dataset.documents.map((d) => d.collection));
  assert.deepEqual([...collections].sort(), ["parentProfiles", "studentProfiles", "teacherProfiles", "userPrivate", "users"]);
  for (const c of collections) assert.match(rulesSource, new RegExp(`match /${c}/\\{`), c);
  assert.doesNotMatch(rulesSource, new RegExp(`match /${SEED_META.collection}/`), "seed marker stays under the catch-all deny");
  assert.ok(dataset.documents.length < 500);
});

test("timestamps are server timestamps; the dataset names no real project", () => {
  for (const doc of dataset.documents) {
    for (const key of ["createdAt", "updatedAt"]) {
      if (key in doc.data) assert.equal(doc.data[key], SERVER_TIMESTAMP, `${doc.collection}/${doc.id}.${key}`);
    }
  }
  assert.doesNotMatch(datasetSource, /rafiq-academy/);
});

test("only an empty emulator may be seeded", () => {
  assert.deepEqual(classifyEmulatorState({ collectionIds: [], userCount: 0, meta: null }), { ok: true });
  for (const state of [
    { collectionIds: ["users"], userCount: 0, meta: null },
    { collectionIds: [], userCount: 1, meta: null },
    { collectionIds: [], userCount: 0, meta: { status: "in_progress", version: 1 } },
    { collectionIds: [], userCount: 0, meta: { status: "complete", version: 1 } },
    { collectionIds: [], userCount: 0, meta: { status: "weird" } },
  ]) {
    assert.equal(classifyEmulatorState(state).ok, false, JSON.stringify(state));
  }
});

// ── nameNormalized ───────────────────────────────────────────────────────────

test("nameNormalized is the backend normalizer's value for every Arabic demo name", () => {
  assert.deepEqual(
    Object.fromEntries(docsIn("users").map((d) => [d.id, d.data.nameNormalized])),
    {
      "demo-admin-01": "خالد عبدالرحمن",
      "demo-supervisor-01": "فهد السبيعي",
      "demo-teacher-01": "عبدالله الحربي",
      "demo-parent-01": "محمد العتيبي",
      "demo-student-01": "احمد محمد",
      "demo-student-02": "ساره علي",
    },
  );
  for (const doc of docsIn("users")) {
    assert.equal(doc.data.nameNormalized, normalizeArabicSearchText(doc.data.name), doc.id);
  }
});

test("seeded nameNormalized follows every frozen normalization vector (shared with the Dart normalizer)", () => {
  const accounts = ARABIC_NORMALIZATION_VECTORS.map((v, i) => ({
    uid: `vector-${i}`, email: `v${i}@rafiq.demo`, name: v.input, role: "student",
  }));
  const users = buildDemoDataset(accounts).documents.filter((d) => d.collection === "users");
  assert.equal(users.length, ARABIC_NORMALIZATION_VECTORS.length);
  ARABIC_NORMALIZATION_VECTORS.forEach((v, i) => {
    assert.equal(users[i].data.nameNormalized, v.expected, v.label);
  });
});

test("the seeder imports the backend normalizer instead of carrying its own", () => {
  assert.match(datasetSource, /^import \{ normalizeArabicSearchText \} from "\.\.\/lib\/search\/arabicNormalization\.js";$/m);
  assert.match(datasetSource, /nameNormalized: normalizeArabicSearchText\(account\.name\)/);
  assert.doesNotMatch(datasetSource, /\\u06|\\u0622|\.normalize\(|\.replace\(/, "no local normalization steps");
});

test("Directory prefix search finds the seeded Arabic names however hamza and teh marbuta are typed", () => {
  // AcademyDirectoryRepository.searchPeople: Dart ArabicSearchNormalizer
  // (pinned to the same vectors) on the query, then a prefix range on
  // nameNormalized, plus a raw `name` prefix fallback for legacy accounts.
  const repository = read(repoRoot, "lib", "features", "directory", "data", "academy_directory_repository.dart");
  assert.match(repository, /final normalized = ArabicSearchNormalizer\.normalize\(raw\);/);
  assert.match(repository, /\.orderBy\('nameNormalized'\)\s*\.startAt\(\[normalized\]\)/);
  const dartParity = read(repoRoot, "test", "security", "wa14_student_search_contract_test.dart");
  assert.match(dartParity, /'functions\/src\/search\/arabicNormalization\.ts'/);
  assert.match(dartParity, /ArabicSearchNormalizer\.normalize\(vector\.input\)/);

  const users = docsIn("users");
  const byNameNormalized = (query) =>
    users.filter((d) => d.data.nameNormalized.startsWith(normalizeArabicSearchText(query))).map((d) => d.id);
  const byRawName = (query) => users.filter((d) => d.data.name.startsWith(query)).map((d) => d.id);
  for (const [query, expected] of [
    ["أحمد", ["demo-student-01"]],
    ["احمد", ["demo-student-01"]],
    ["إحمد", ["demo-student-01"]],
    ["سارة", ["demo-student-02"]],
    ["ساره", ["demo-student-02"]],
    ["عبدالله", ["demo-teacher-01"]],
    ["محمد", ["demo-parent-01"]],
    ["خالد", ["demo-admin-01"]],
  ]) {
    assert.deepEqual(byNameNormalized(query), expected, query);
  }
  // Without nameNormalized only the raw-name fallback would run, and it misses these.
  assert.deepEqual(byRawName("احمد"), []);
  assert.deepEqual(byRawName("ساره"), []);
});

// ── Admin first login ────────────────────────────────────────────────────────

/** In-memory Firestore/Auth double with just what writeDemoDataset and completeFirstLoginCore call. */
function fakeFirebase() {
  const store = new Map();
  const authUsers = new Map();
  const authCalls = [];
  const snapshot = (key) => {
    const data = store.get(key);
    return { exists: data !== undefined, data: () => (data ? { ...data } : undefined), get: (field) => data?.[field] };
  };
  const ref = (collection, id) => {
    const key = `${collection}/${id}`;
    return {
      key,
      create: async (data) => {
        if (store.has(key)) throw new Error(`${key} already exists`);
        store.set(key, { ...data });
      },
      update: async (data) => {
        if (!store.has(key)) throw new Error(`${key} does not exist`);
        store.set(key, { ...store.get(key), ...data });
      },
      get: async () => snapshot(key),
    };
  };
  const db = {
    collection: (collection) => ({ doc: (id) => ref(collection, id) }),
    batch: () => {
      const ops = [];
      return {
        create: (r, data) => ops.push(() => r.create(data)),
        update: (r, data) => ops.push(() => r.update(data)),
        set: (r, data, options) =>
          ops.push(async () => store.set(r.key, options?.merge ? { ...(store.get(r.key) ?? {}), ...data } : { ...data })),
        commit: async () => {
          for (const op of ops) await op();
        },
      };
    },
  };
  const auth = {
    createUser: async (user) => {
      authCalls.push(["createUser", user.uid]);
      authUsers.set(user.uid, { ...user });
      return { uid: user.uid };
    },
    getUser: async (uid) => ({ uid, email: authUsers.get(uid)?.email }),
    updateUser: async (uid, patch) => {
      authCalls.push(["updateUser", uid, Object.keys(patch)]);
      authUsers.set(uid, { ...authUsers.get(uid), ...patch });
    },
  };
  return { store, authUsers, authCalls, db, auth };
}

async function seedIntoFake() {
  const fake = fakeFirebase();
  const logs = [];
  await writeDemoDataset({
    dataset: buildDemoDataset(),
    auth: fake.auth,
    db: fake.db,
    serverTimestamp: () => "server-timestamp",
    log: (line) => logs.push(line),
  });
  return { ...fake, logs };
}

/** Every string inside plain objects and arrays (Firestore sentinels are skipped). */
function stringsIn(value, out = []) {
  if (typeof value === "string") out.push(value);
  else if (Array.isArray(value)) value.forEach((v) => stringsIn(v, out));
  else if (value && Object.getPrototypeOf(value) === Object.prototype) {
    for (const [k, v] of Object.entries(value)) {
      out.push(k);
      stringsIn(v, out);
    }
  }
  return out;
}

test("the demo Admin has no authority until first login, like a provisioned Admin; other roles are active", () => {
  for (const a of DEMO_ACCOUNTS) {
    const user = docOf("users", a.uid).data;
    assert.equal(activeRoleOf(user), a.role === "admin" ? "" : a.role, a.uid);
    if (a.role !== "admin") {
      assert.equal("passwordChangeRequired" in user, false, a.uid);
      assert.equal("mustChangePassword" in docOf("userPrivate", a.uid).data, false, a.uid);
    }
  }
  assert.equal(activeRoleOf({ ...docOf("users", "demo-admin-01").data, passwordChangeRequired: false }), "admin");
  // Security rules: no Admin rights while the flag is set, and no client may clear it.
  assert.match(rulesSource, /userDoc\(\)\.get\('passwordChangeRequired', false\) != true;/);
  const protectedLists = [...rulesSource.matchAll(/\.hasAny\(\[([^\]]*)\]\)/g)].map((m) => m[1]);
  assert.ok(protectedLists.some((list) => list.includes("'passwordChangeRequired'")), "users self-update protects the flag");
});

test("completeFirstLogin accepts the seeded Admin, clears both flags and restores the Admin role", async () => {
  const fake = await seedIntoFake();
  const newPassword = "NewAdmin2026";
  assert.deepEqual(await completeFirstLoginCore(fake, "demo-admin-01", { newPassword }), { ok: true });
  const user = fake.store.get("users/demo-admin-01");
  const priv = fake.store.get("userPrivate/demo-admin-01");
  assert.equal(user.passwordChangeRequired, false);
  assert.equal(priv.mustChangePassword, false);
  assert.equal(activeRoleOf(user), "admin");
  assert.deepEqual(fake.authCalls.at(-1), ["updateUser", "demo-admin-01", ["password"]]);
  for (const [key, doc] of fake.store) {
    assert.equal(stringsIn(doc).some((s) => s.includes(newPassword)), false, `${key} holds the new password`);
  }
});

test("completeFirstLogin refuses seeded non-Admin accounts: no first-login flag was added to them", async () => {
  const fake = await seedIntoFake();
  for (const a of DEMO_ACCOUNTS.filter((x) => x.role !== "admin")) {
    await assert.rejects(
      completeFirstLoginCore(fake, a.uid, { newPassword: "NewMember2026" }),
      (e) => e.code === "failed-precondition",
      a.uid,
    );
  }
  assert.equal(fake.authCalls.some(([call]) => call === "updateUser"), false);
});

// ── secrets, audit and relationships ─────────────────────────────────────────

test("the demo password reaches Auth only: never Firestore, the seed marker, logs or audit records", async () => {
  const fake = await seedIntoFake();
  assert.equal(fake.authUsers.size, DEMO_ACCOUNTS.length);
  for (const user of fake.authUsers.values()) assert.equal(user.password, DEMO_PASSWORD);
  assert.equal(stringsIn(dataset.documents).some((s) => s.includes(DEMO_PASSWORD)), false, "dataset documents");
  for (const [key, doc] of fake.store) {
    assert.equal(stringsIn(doc).some((s) => s.includes(DEMO_PASSWORD)), false, key);
    for (const field of Object.keys(doc).filter((f) => /password/i.test(f))) {
      assert.ok(["passwordChangeRequired", "mustChangePassword"].includes(field), `${key}.${field}`);
      assert.equal(typeof doc[field], "boolean", `${key}.${field}`);
    }
  }
  const output = fake.logs.join("\n");
  assert.doesNotMatch(output, new RegExp(DEMO_PASSWORD.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  for (const a of DEMO_ACCOUNTS) {
    assert.ok(!output.includes(a.email) && !output.includes(a.name), `${a.uid}: logs name no email or name`);
  }
  assert.equal([...fake.store.keys()].some((k) => k.startsWith("auditLogs/")), false, "no audit records are seeded");
  const marker = fake.store.get(`${SEED_META.collection}/${SEED_META.id}`);
  assert.equal(marker.status, "complete");
  assert.equal(marker.version, DEMO_SEED_VERSION);
  assert.equal(DEMO_SEED_VERSION, 2);
  assert.deepEqual(marker.counts, { authUsers: DEMO_ACCOUNTS.length, documents: dataset.documents.length });
});

test("no relationship is seeded, so nothing contradicts the server-owned relationship invariants", () => {
  for (const doc of docsIn("parentProfiles")) assert.deepEqual(doc.data.childrenIds, [], doc.id);
  for (const doc of docsIn("teacherProfiles")) assert.deepEqual(doc.data.halaqatIds, [], doc.id);
  for (const doc of docsIn("studentProfiles")) {
    assert.equal(doc.data.halaqaId, null, doc.id);
    assert.equal(doc.data.halaqaName, null, doc.id);
  }
  for (const doc of dataset.documents) {
    for (const key of ["academyRef", "parentIds", "studentIds", "teacherId", "supervisorId", "assistantTeacherIds"]) {
      assert.equal(key in doc.data, false, `${doc.collection}/${doc.id}.${key}`);
    }
  }
});
