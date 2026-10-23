/**
 * Contact-field cleanup script, against an in-memory Firestore with
 * synthetic data only. Never touches Firebase or an emulator.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  CONTACT_FIELD_KEYS,
  TARGET_COLLECTIONS,
  classifyDocument,
  runContactFieldCleanup,
} from "../scripts/migrate-contact-fields.mjs";
import { DOCUMENT_ID, FakeDb, FakeFieldValue } from "./migration_fakes.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");

const PHONE_A = "01011112222";
const PHONE_B = "+966500000001";
const EMAIL_A = "synthetic.a@example.test";

const seed = () => ({
  "users/u1": { name: "Synthetic One", role: "parent", isActive: true, phone: PHONE_A, createdAt: "T0" },
  "users/u2": { name: "Synthetic Two", role: "student", isActive: true, email: EMAIL_A },
  "userPrivate/u1": { phone: PHONE_A, updatedAt: "T1", migratedFromUsers: true },
  "userPrivate/u2": { email: EMAIL_A, emailSource: "auth", emailUpdatedAt: "T2" },
  "userPrivate/u3": { email: EMAIL_A, whatsapp: PHONE_B, mobile: "", phoneNumber: null },
  "parentProfiles/u1": { childrenIds: ["s1"], phone: PHONE_B, guardianPhone: PHONE_A },
  "studentProfiles/s1": {
    halaqaId: "h1",
    parentPhone: PHONE_A,
    guardian: { name: "G", phone: PHONE_B },
    contacts: [{ mobile: PHONE_A }],
    emergencyPhone: PHONE_B,
  },
  "teacherProfiles/t1": { bio: "synthetic", phone: "" },
  "supervisorProfiles/v1": { name: "Sup" },
  "studentSearch/s1": { nameNormalized: "synthetic", parentPhone: PHONE_A },
  "halaqat/h1": { name: "Halaqa", phone: PHONE_A },
});

const run = (db, mode, opts = {}) =>
  runContactFieldCleanup({ db, mode, FieldValue: FakeFieldValue, documentId: DOCUMENT_ID, ...opts });

const without = (data, keys) => Object.fromEntries(Object.entries(data).filter(([k]) => !keys.includes(k)));

test("classification: removes exactly the policy keys; nested and look-alike keys are review-only", () => {
  const found = classifyDocument(seed()["studentProfiles/s1"]);
  assert.deepEqual(found.remove, ["parentPhone"]);
  assert.deepEqual(found.phoneLikeKeys, ["emergencyPhone"]);
  assert.equal(found.nestedContactKeys, 2);

  const marker = classifyDocument(seed()["userPrivate/u1"]);
  assert.deepEqual(marker.remove, ["phone"]);
  assert.deepEqual(marker.reviewMarkers, ["migratedFromUsers"]);

  // Presence decides, not value: empty and null contact keys are removed too.
  assert.deepEqual(classifyDocument(seed()["userPrivate/u3"]).remove, ["phoneNumber", "mobile", "whatsapp"]);
  assert.deepEqual(classifyDocument({ email: EMAIL_A, emailSource: "auth", name: "x" }).remove, []);
});

test("dry run is the default behaviour of the runner: counts only, zero writes", async () => {
  const db = new FakeDb(seed());
  const before = db.dump();
  const report = await run(db, "dry-run");

  assert.equal(db.writes.length, 0);
  assert.deepEqual(db.dump(), before);
  assert.equal(report.mode, "dry-run");
  assert.equal(report.totals.docsUpdated, 0);
  assert.equal(report.totals.docsWithContactFields, 7);
  assert.equal(report.totals.fieldsToRemove, 10);
  assert.deepEqual(report.collections.parentProfiles.fieldsToRemove, {
    phone: 1, phoneNumber: 0, mobile: 0, whatsapp: 0, parentPhone: 0, guardianPhone: 1,
  });
  assert.ok(!("halaqat" in report.collections), "only target collections are scanned");
  await assert.rejects(run(db, "apply-now"), /mode must be/);
});

test("apply removes only the listed keys and preserves every other field and document", async () => {
  const db = new FakeDb(seed());
  const before = db.dump();
  const report = await run(db, "apply");
  const after = db.dump();

  assert.equal(report.totals.docsUpdated, 7);
  assert.equal(report.totals.errors, 0);
  assert.equal(db.deletes, 0);
  assert.deepEqual(Object.keys(after).sort(), Object.keys(before).sort(), "no document added or deleted");

  for (const [path, data] of Object.entries(before)) {
    const collection = path.split("/")[0];
    const expected = TARGET_COLLECTIONS.includes(collection) ? without(data, CONTACT_FIELD_KEYS) : data;
    assert.deepEqual(after[path], expected, path);
  }
  // Nested / look-alike data is untouched for manual review.
  assert.deepEqual(after["studentProfiles/s1"].guardian, { name: "G", phone: PHONE_B });
  assert.equal(after["studentProfiles/s1"].emergencyPhone, PHONE_B);
  // A phone-only private doc survives as a document, keeping its metadata.
  assert.deepEqual(after["userPrivate/u1"], { updatedAt: "T1", migratedFromUsers: true });
  // Each write deletes contact keys only.
  for (const write of db.writes) {
    assert.equal(write.op, "update");
    assert.ok(write.keys.every((k) => CONTACT_FIELD_KEYS.includes(k)), write.path);
  }
});

test("idempotent: a second apply finds nothing and writes nothing", async () => {
  const db = new FakeDb(seed());
  await run(db, "apply");
  const settled = db.dump();
  const writes = db.writes.length;

  const again = await run(db, "apply");
  assert.equal(again.totals.docsWithContactFields, 0);
  assert.equal(again.totals.docsUpdated, 0);
  assert.equal(db.writes.length, writes);
  assert.deepEqual(db.dump(), settled);
});

test("a document changed after it was read is skipped, not overwritten", async () => {
  const db = new FakeDb(seed());
  db.beforeWrite = (path) => {
    if (path === "users/u1") db.put(path, { ...db.dump()[path], name: "Edited meanwhile" });
  };
  const report = await run(db, "apply");
  assert.equal(report.collections.users.skippedChangedSinceRead, 1);
  assert.equal(db.dump()["users/u1"].name, "Edited meanwhile");
  assert.equal(db.dump()["users/u1"].phone, PHONE_A, "left for the next run");
});

test("paging visits every document exactly once", async () => {
  const docs = {};
  for (let i = 0; i < 23; i++) docs[`users/u${String(i).padStart(2, "0")}`] = { name: "n", phone: PHONE_A };
  const db = new FakeDb(docs);
  const report = await run(db, "apply", { collections: ["users"], pageSize: 5 });
  assert.equal(report.collections.users.scanned, 23);
  assert.equal(report.collections.users.docsUpdated, 23);
});

test("report carries counts and UID-shaped ids only, never field values", async () => {
  const db = new FakeDb({
    ...seed(),
    "studentProfiles/odd id with spaces": { guardian: { phone: PHONE_A } },
  });
  for (const mode of ["dry-run", "apply"]) {
    const text = JSON.stringify(await run(db, mode));
    for (const secret of [PHONE_A, PHONE_B, EMAIL_A, "Synthetic One", "01011112222".slice(0, 6)]) {
      assert.ok(!text.includes(secret), `${mode} report leaked a value`);
    }
    assert.ok(!text.includes("odd id with spaces"));
  }
  const report = await run(new FakeDb(seed()), "dry-run");
  assert.deepEqual(report.collections.studentProfiles.review.phoneLikeKeyNames, { emergencyPhone: 1 });
  assert.deepEqual(report.collections.studentProfiles.review.docIds.toJSON().ids, ["s1"]);
});

test("key list matches the backend policy and firestore.rules", () => {
  const ts = readFileSync(join(root, "functions", "src", "privacy", "contactInfoPolicy.ts"), "utf8");
  const tsList = ts.match(/CONTACT_FIELD_KEYS = \[([\s\S]*?)\]/)[1].match(/"([^"]+)"/g).map((s) => s.slice(1, -1));
  const rules = readFileSync(join(root, "firestore.rules"), "utf8");
  const rulesList = rules.match(/function contactFieldKeys\(\) \{\s*return \[([^\]]*)\]/)[1]
    .match(/'([^']+)'/g).map((s) => s.slice(1, -1));
  assert.deepEqual([...CONTACT_FIELD_KEYS], tsList);
  assert.deepEqual([...CONTACT_FIELD_KEYS], rulesList);
});

test("script source never deletes documents or Auth users and never logs values", () => {
  const source = readFileSync(join(here, "..", "scripts", "migrate-contact-fields.mjs"), "utf8");
  assert.doesNotMatch(source, /(?<!FieldValue)\.delete\(|recursiveDelete|deleteUsers?\(|\.set\(/);
  assert.doesNotMatch(source, /console\.(log|error)\([^)]*(doc\.data|\.data\(\)|error\.message)/);
});
