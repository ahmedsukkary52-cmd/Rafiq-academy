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
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

if (!EMULATOR || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "Parent Halaqat emulator suite requires FIRESTORE_EMULATOR_HOST and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

async function clearAuth() {
  const res = await fetch(`http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: "DELETE",
  });
  assert.equal(res.ok, true, "auth clear failed");
}

async function idTokenFor(uid) {
  await admin.auth().createUser({ uid, email: `${uid}@example.test`, password: "secret123" });
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: `${uid}@example.test`, password: "secret123", returnSecureToken: true }),
    },
  );
  const body = await res.json();
  assert.ok(body.idToken, `sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function call(data, token) {
  const res = await fetch(
    `http://${FUNCTIONS}/${PROJECT_ID}/europe-west1/getParentChildHalaqat`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: res.status, body };
}

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

let parentToken;
let parentOffToken;
let teacherToken;

test.beforeEach(async () => {
  await clearFirestore();
  await clearAuth();
  parentToken = await idTokenFor("parent1");
  parentOffToken = await idTokenFor("parentOff");
  teacherToken = await idTokenFor("teacher1");
  await seed();
});

test("linked parent: projection of the child's Halaqat only", async () => {
  const response = await call({ studentId: "student1" }, parentToken);
  assert.equal(response.status, 200, JSON.stringify(response.body));
  const res = response.body.result;
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
  const response = await call({ studentId: "student1" }, parentToken);
  assert.equal(response.status, 200, JSON.stringify(response.body));
  assert.deepEqual(response.body.result.halaqat.map((h) => h.id), ["h2"]);
});

test("unlinked child, deactivated parent and non-parent are denied", async () => {
  const cases = [
    ["parent1", "student2", parentToken, "PERMISSION_DENIED"],
    ["parentOff", "student1", parentOffToken, "PERMISSION_DENIED"],
    ["teacher1", "student1", teacherToken, "PERMISSION_DENIED"],
    ["ghost", "student1", null, "UNAUTHENTICATED"],
  ];
  for (const [uid, studentId, token, expectedStatus] of cases) {
    const response = await call({ studentId }, token);
    assert.equal(
      response.body.error?.status,
      expectedStatus,
      `${uid} -> ${studentId}: ${JSON.stringify(response.body)}`,
    );
  }
});
