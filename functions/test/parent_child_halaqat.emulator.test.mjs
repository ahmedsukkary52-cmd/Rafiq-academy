/**
 * getParentChildHalaqat core against the Firestore emulator (real
 * array-contains query): a linked parent receives only name/teacherId/
 * supervisorId, never the roster or a legacy meeting link. Never touches a
 * real project.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 functions/test/parent_child_halaqat.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "Parent Halaqat emulator suite requires FIRESTORE_EMULATOR_HOST and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const { getParentChildHalaqatCore } = require("../lib/halaqa/parentHalaqaFunctions.js");

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed() {
  const docs = {
    "users/parent1": { role: "parent", isActive: true },
    "users/parentOff": { role: "parent", isActive: false },
    "users/teacher1": { role: "teacher", isActive: true },
    "parentProfiles/parent1": { childrenIds: ["student1"] },
    "parentProfiles/parentOff": { childrenIds: ["student1"] },
    "halaqat/h1": {
      name: "حلقة الفجر",
      teacherId: "teacher1",
      supervisorId: "sup1",
      studentIds: ["student1", "student2"],
      meetingLink: "https://meet.example.test/legacy-h1",
      status: "active",
    },
    "halaqat/h2": {
      name: "حلقة العصر",
      teacherId: "teacher2",
      supervisorId: "sup2",
      studentIds: ["student2"],
    },
    "halaqaMeetingLinks/h1": { meetingLink: "https://meet.example.test/canonical-h1" },
  };
  const batch = db.batch();
  for (const [path, data] of Object.entries(docs)) batch.set(db.doc(path), data);
  await batch.commit();
}

test.beforeEach(async () => {
  await clearFirestore();
  await seed();
});

test("linked parent: projection of the child's Halaqat only", async () => {
  const res = await getParentChildHalaqatCore(db, "parent1", { studentId: "student1" });
  assert.deepEqual(res, {
    halaqat: [{ id: "h1", name: "حلقة الفجر", teacherId: "teacher1", supervisorId: "sup1" }],
  });
  const json = JSON.stringify(res);
  for (const leaked of ["student2", "studentIds", "meetingLink", "meet.example.test"]) {
    assert.equal(json.includes(leaked), false, `response leaks ${leaked}`);
  }
});

test("roster change is reflected immediately (no stored projection)", async () => {
  await db.doc("halaqat/h2").update({ studentIds: admin.firestore.FieldValue.arrayUnion("student1") });
  await db.doc("halaqat/h1").update({ studentIds: ["student2"] });
  const res = await getParentChildHalaqatCore(db, "parent1", { studentId: "student1" });
  assert.deepEqual(res.halaqat.map((h) => h.id), ["h2"]);
});

test("unlinked child, deactivated parent and non-parent are denied", async () => {
  for (const [uid, studentId] of [
    ["parent1", "student2"],
    ["parentOff", "student1"],
    ["teacher1", "student1"],
    ["ghost", "student1"],
  ]) {
    await assert.rejects(
      getParentChildHalaqatCore(db, uid, { studentId }),
      (err) => err.code === "permission-denied",
      `${uid} -> ${studentId}`,
    );
  }
});
