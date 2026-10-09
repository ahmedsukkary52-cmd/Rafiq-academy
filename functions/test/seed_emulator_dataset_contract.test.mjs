/**
 * Demo dataset v1 contract (scripts/seed-emulator-dataset.mjs): fixed UIDs,
 * no phone on users, and field names identical to what adminProvisionUser
 * writes today, read from the current sources. Pure: nothing is written.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildDemoDataset,
  classifyEmulatorState,
  DEMO_ACCOUNTS,
  SEED_META,
  SERVER_TIMESTAMP,
} from "../scripts/seed-emulator-dataset.mjs";

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

/** Top-level keys of the first object literal after `anchor` in TS source. */
function objectKeysAfter(source, anchor) {
  const match = anchor.exec(source);
  assert.ok(match, `anchor not found: ${anchor}`);
  const start = source.indexOf("{", match.index + match[0].length);
  let depth = 0;
  let end = start;
  for (; end < source.length; end++) {
    if (source[end] === "{") depth++;
    if (source[end] === "}" && --depth === 0) break;
  }
  const body = source
    .slice(start + 1, end)
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
    .map((e) => e.match(/^([A-Za-z_$][\w$]*)/)[1])
    .sort();
}

const provisionKeys = (collection) =>
  objectKeysAfter(provisionSource, new RegExp(`collection\\("${collection}"\\)\\.doc\\(uid\\)\\.set\\(`));

const dataset = buildDemoDataset();
const docsIn = (collection) => dataset.documents.filter((d) => d.collection === collection);
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

test("users documents never carry a phone; phones live only in userPrivate", () => {
  for (const doc of docsIn("users")) assert.equal("phone" in doc.data, false, doc.id);
  for (const doc of dataset.documents) {
    if (doc.collection !== "userPrivate") assert.equal("phone" in doc.data, false, `${doc.collection}/${doc.id}`);
  }
  assert.equal(docsIn("userPrivate").length, DEMO_ACCOUNTS.length);
});

test("users fields equal adminProvisionUser and are a subset of UserModel.toFirestore", () => {
  const expected = provisionKeys("users");
  assert.deepEqual(expected, ["createdAt", "email", "isActive", "name", "role"]);
  const toFirestore = userModelSource.slice(userModelSource.indexOf("toFirestore()"));
  const dartKeys = [...toFirestore.slice(0, toFirestore.indexOf("};")).matchAll(/'(\w+)':/g)].map((m) => m[1]);
  for (const doc of docsIn("users")) {
    assert.deepEqual(keysOf(doc), expected, doc.id);
    for (const key of keysOf(doc)) assert.ok(dartKeys.includes(key), key);
  }
});

test("userPrivate and role profile fields equal adminProvisionUser", () => {
  for (const collection of ["userPrivate", "studentProfiles", "parentProfiles", "teacherProfiles"]) {
    const expected = provisionKeys(collection);
    assert.ok(docsIn(collection).length > 0, collection);
    for (const doc of docsIn(collection)) assert.deepEqual(keysOf(doc), expected, `${collection}/${doc.id}`);
  }
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
