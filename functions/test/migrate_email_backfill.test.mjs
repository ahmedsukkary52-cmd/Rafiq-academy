/**
 * Email backfill script, against an in-memory Firestore and a synthetic Auth
 * user list. Never touches Firebase or an emulator.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { OUTCOME, classifyAccount, runEmailBackfill } from "../scripts/migrate-email-backfill.mjs";
import { DOCUMENT_ID, FakeDb, FakeFieldValue } from "./migration_fakes.mjs";

const here = dirname(fileURLToPath(import.meta.url));

const mail = (n) => `synthetic.${n}@example.test`;
const PHONE = "01022223333";

// One account per outcome, plus a users doc without an Auth account.
const authUsers = [
  { uid: "create1", email: mail("create1") },
  { uid: "add1", email: ` ${mail("add1")} ` },
  { uid: "current1", email: mail("current1").toUpperCase() },
  { uid: "conflict1", email: mail("conflict1") },
  { uid: "invalid1", email: mail("invalid1") },
  { uid: "blocked1", email: mail("blocked1") },
  { uid: "noemail1", email: null },
  { uid: "noprofile1", email: mail("noprofile1") },
];

const seed = () => ({
  "users/create1": { name: "c", role: "student", isActive: true },
  "users/add1": { name: "a", role: "parent", isActive: true, email: mail("legacy-add1") },
  "users/current1": { name: "k", role: "teacher", isActive: true, email: mail("current1") },
  "users/conflict1": { name: "x", role: "parent", isActive: true },
  "users/invalid1": { name: "i", role: "parent", isActive: true },
  "users/blocked1": { name: "b", role: "parent", isActive: true },
  "users/noemail1": { name: "n", role: "student", isActive: true, email: mail("legacy-only") },
  "users/orphan1": { name: "o", role: "student", isActive: false, email: mail("orphan") },
  "userPrivate/add1": { updatedAt: "T1", migratedFromUsers: true },
  "userPrivate/current1": { email: mail("current1"), emailSource: "auth", emailUpdatedAt: "T0" },
  "userPrivate/conflict1": { email: mail("someone-else"), emailSource: "auth" },
  "userPrivate/invalid1": { email: 42 },
  "userPrivate/blocked1": { phone: PHONE },
});

const listOf = (users) => async function* () {
  for (const user of users) yield user;
};

const run = (db, mode, users = authUsers) =>
  runEmailBackfill({ db, listAuthUsers: listOf(users), mode, FieldValue: FakeFieldValue, documentId: DOCUMENT_ID });

test("classifyAccount covers every outcome", () => {
  const c = (o) => classifyAccount({ userExists: true, privateExists: false, privateData: null, authEmail: mail(1), ...o });
  assert.equal(c({ userExists: false }), OUTCOME.noAppProfile);
  assert.equal(c({ authEmail: "  " }), OUTCOME.missingAuthEmail);
  assert.equal(c({ authEmail: undefined }), OUTCOME.missingAuthEmail);
  assert.equal(c({}), OUTCOME.create);
  assert.equal(c({ privateExists: true, privateData: {} }), OUTCOME.addEmail);
  assert.equal(c({ privateExists: true, privateData: { email: mail(1).toUpperCase() } }), OUTCOME.alreadyCurrent);
  assert.equal(c({ privateExists: true, privateData: { email: mail(2) } }), OUTCOME.conflictDiffers);
  assert.equal(c({ privateExists: true, privateData: { email: "" } }), OUTCOME.conflictInvalid);
  assert.equal(c({ privateExists: true, privateData: { email: mail(1), whatsapp: PHONE } }), OUTCOME.blockedByContactField);
});

test("dry run: aggregate outcomes, zero writes", async () => {
  const db = new FakeDb(seed());
  const before = db.dump();
  const report = await run(db, "dry-run");

  assert.equal(db.writes.length, 0);
  assert.deepEqual(db.dump(), before);
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
  assert.deepEqual(report.written, { created: 0, emailAdded: 0, skippedChangedSinceRead: 0 });
  assert.deepEqual(report.legacyUsersEmail, {
    usersEmailPresent: 3,
    usersEmailDiffersFromAuth: 1,
    missingAuthEmailButUsersEmailPresent: 1,
  });
  assert.deepEqual(report.review.usersDocsWithoutAuthAccount.toJSON().ids, ["orphan1"]);
  assert.deepEqual(report.review[OUTCOME.conflictDiffers].toJSON().ids, ["conflict1"]);
  assert.deepEqual(report.review[OUTCOME.missingAuthEmail].toJSON().ids, ["noemail1"]);
});

test("apply writes Auth email only where missing; conflicts, blocked docs and users stay untouched", async () => {
  const db = new FakeDb(seed());
  const before = db.dump();
  const report = await run(db, "apply");
  const after = db.dump();

  assert.deepEqual(report.written, { created: 1, emailAdded: 1, skippedChangedSinceRead: 0 });
  assert.deepEqual(report.errors, {});
  assert.equal(db.deletes, 0);

  assert.deepEqual(after["userPrivate/create1"], {
    email: mail("create1"), emailSource: "auth", emailUpdatedAt: "<serverTimestamp>",
  });
  // Existing fields kept; Auth (trimmed) wins over the legacy users.email.
  assert.deepEqual(after["userPrivate/add1"], {
    updatedAt: "T1", migratedFromUsers: true,
    email: mail("add1"), emailSource: "auth", emailUpdatedAt: "<serverTimestamp>",
  });
  for (const path of ["userPrivate/current1", "userPrivate/conflict1", "userPrivate/invalid1", "userPrivate/blocked1"]) {
    assert.deepEqual(after[path], before[path], `${path} must not change`);
  }
  // No fallback to users.email, no doc for accounts without a profile.
  assert.equal(after["userPrivate/noemail1"], undefined);
  assert.equal(after["userPrivate/noprofile1"], undefined);
  // users/{uid} (including users.email) is never written.
  for (const [path, data] of Object.entries(before)) {
    if (path.startsWith("users/")) assert.deepEqual(after[path], data, path);
  }
  assert.ok(db.writes.every((w) => w.path.startsWith("userPrivate/")));
  assert.ok(db.writes.every((w) => w.keys.join() === "email,emailSource,emailUpdatedAt"));
});

test("idempotent: a second apply writes nothing", async () => {
  const db = new FakeDb(seed());
  await run(db, "apply");
  const settled = db.dump();
  const writes = db.writes.length;
  const again = await run(db, "apply");
  assert.equal(db.writes.length, writes);
  assert.deepEqual(db.dump(), settled);
  assert.equal(again.outcomes[OUTCOME.alreadyCurrent], 3);
  assert.equal(again.outcomes[OUTCOME.create] + again.outcomes[OUTCOME.addEmail], 0);
});

test("a private doc created or changed after the read is skipped, not overwritten", async () => {
  const db = new FakeDb(seed());
  db.beforeWrite = (path) => {
    if (path === "userPrivate/create1") db.put(path, { email: mail("raced"), emailSource: "auth" });
    if (path === "userPrivate/add1") db.put(path, { updatedAt: "T9" });
  };
  const report = await run(db, "apply");
  assert.equal(report.written.skippedChangedSinceRead, 2);
  assert.deepEqual(report.review.skippedChangedSinceRead.toJSON().ids, ["create1", "add1"]);
  assert.equal(db.dump()["userPrivate/create1"].email, mail("raced"));
  assert.deepEqual(db.dump()["userPrivate/add1"], { updatedAt: "T9" });
});

test("report never contains an email address or phone number", async () => {
  for (const mode of ["dry-run", "apply"]) {
    const text = JSON.stringify(await run(new FakeDb(seed()), mode));
    assert.doesNotMatch(text, /@/, `${mode} report contains an email`);
    assert.ok(!text.includes(PHONE));
  }
});

test("review UID lists are capped and skip non UID-shaped ids", async () => {
  const users = [];
  const docs = {};
  for (let i = 0; i < 60; i++) {
    const uid = `nomail${String(i).padStart(2, "0")}`;
    users.push({ uid, email: null });
    docs[`users/${uid}`] = { name: "n" };
  }
  users.push({ uid: "bad id/x", email: null });
  docs["users/bad id"] = { name: "n" };
  const report = await run(new FakeDb(docs), "dry-run", users);
  const list = report.review[OUTCOME.missingAuthEmail].toJSON();
  assert.equal(list.total, 60);
  assert.equal(list.ids.length, 50);
  assert.equal(list.truncated, true);
  assert.equal(report.review.usersDocsWithoutAuthAccount.toJSON().unprintable, 1);
});

test("script source never writes users, deletes data, or logs values", () => {
  const source = readFileSync(join(here, "..", "scripts", "migrate-email-backfill.mjs"), "utf8");
  assert.doesNotMatch(source, /(?<!FieldValue)\.delete\(|recursiveDelete|deleteUsers?\(|\.set\(/);
  assert.doesNotMatch(source, /collection\("users"\)\.doc\([^)]*\)\.(update|create)/);
  assert.doesNotMatch(source, /console\.(log|error)\([^)]*(\.email|\.data\(\)|error\.message)/);
});
