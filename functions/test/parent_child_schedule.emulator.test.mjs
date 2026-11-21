/**
 * Parent schedule projection through the exported callable and Functions
 * Emulator. This verifies the real wrapper gate, Auth token, Firestore reads,
 * authorization, and sanitized data projection.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("Parent schedule suite requires auth + firestore + functions and a demo- project id");
}

process.env.GCLOUD_PROJECT = PROJECT_ID;
const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

async function clearEmulators() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const response = await fetch(url, { method: "DELETE" });
    assert.equal(response.ok, true, `emulator clear failed: ${url}`);
  }
}

async function idTokenFor(uid) {
  await admin.auth().createUser({
    uid,
    email: `${uid}@example.test`,
    password: "secret123",
  });
  const response = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${uid}@example.test`,
        password: "secret123",
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  assert.ok(body.idToken, `sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function callSchedule(data, token) {
  const response = await fetch(
    `http://${FUNCTIONS}/${PROJECT_ID}/europe-west1/getParentChildSchedule`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
  const text = await response.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: response.status, body };
}

async function seed() {
  const batch = db.batch();
  batch.set(db.doc("users/parent1"), { role: "parent", isActive: true });
  batch.set(db.doc("users/parent2"), { role: "parent", isActive: true });
  batch.set(db.doc("users/teacher1"), { role: "teacher", isActive: true });
  batch.set(db.doc("users/inactive"), { role: "parent", isActive: false });
  batch.set(db.doc("parentProfiles/parent1"), { childrenIds: ["student1"] });
  batch.set(db.doc("parentProfiles/parent2"), { childrenIds: ["student2"] });
  batch.set(db.doc("halaqat/h1"), {
    name: "حلقة الفجر",
    teacherId: "teacher1",
    studentIds: ["student1"],
    meetingLink: "https://legacy.example.test/should-not-leak",
    schedule: [
      { day: " السبت ", startTime: "06:00 ", endTime: "07:00", slotId: "slot-a" },
    ],
  });
  await batch.commit();
}

let parentToken;
let otherParentToken;
let teacherToken;
let inactiveToken;

test.beforeEach(async () => {
  await clearEmulators();
  parentToken = await idTokenFor("parent1");
  otherParentToken = await idTokenFor("parent2");
  teacherToken = await idTokenFor("teacher1");
  inactiveToken = await idTokenFor("inactive");
  await seed();
});

test("linked parent receives only the sanitized schedule projection", async () => {
  const response = await callSchedule(
    { studentId: "student1", halaqaId: "h1" },
    parentToken,
  );
  assert.equal(response.status, 200, JSON.stringify(response.body));
  assert.deepEqual(response.body.result, {
    halaqaId: "h1",
    name: "حلقة الفجر",
    schedule: [{ day: "السبت", startTime: "06:00", endTime: "07:00" }],
  });
  assert.equal(JSON.stringify(response.body).includes("meetingLink"), false);
  assert.equal(JSON.stringify(response.body).includes("studentIds"), false);
});

test("unlinked, non-parent, inactive, and anonymous callers are rejected", async () => {
  const denied = await callSchedule(
    { studentId: "student1", halaqaId: "h1" },
    otherParentToken,
  );
  assert.equal(denied.body.error?.status, "PERMISSION_DENIED", JSON.stringify(denied.body));

  const teacher = await callSchedule(
    { studentId: "student1", halaqaId: "h1" },
    teacherToken,
  );
  assert.equal(teacher.body.error?.status, "PERMISSION_DENIED", JSON.stringify(teacher.body));

  const inactive = await callSchedule(
    { studentId: "student1", halaqaId: "h1" },
    inactiveToken,
  );
  assert.equal(inactive.body.error?.status, "PERMISSION_DENIED", JSON.stringify(inactive.body));

  const anonymous = await callSchedule({ studentId: "student1", halaqaId: "h1" }, null);
  assert.equal(anonymous.body.error?.status, "UNAUTHENTICATED", JSON.stringify(anonymous.body));
});
