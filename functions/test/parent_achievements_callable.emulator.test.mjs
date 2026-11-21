/**
 * getParentAchievements over HTTP through the Functions emulator, at the URL
 * shape the Flutter client uses (`/{project}/{clientRegion}/{name}`):
 * Auth token -> region -> parent role -> parentProfiles scope -> projection.
 *
 * Isolated run only (demo-rafiq-it, firebase.it.json ports), e.g. from
 * D:\rafiq_test_env after `npm --prefix functions run build`:
 *   npx firebase emulators:exec --config firebase.it.json --project demo-rafiq-it \
 *     --only auth,firestore,functions \
 *     "node functions_preflight_run.mjs functions/test/parent_achievements_callable.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { clientFunctionsRegion } from "./helpers/client_region.mjs";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "Parent achievements emulator suite requires the auth + firestore + functions emulators and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const CLIENT_REGION = clientFunctionsRegion();

async function clearFirestore() {
  const res = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "firestore clear failed");
}

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
      body: JSON.stringify({
        email: `${uid}@example.test`,
        password: "secret123",
        returnSecureToken: true,
      }),
    },
  );
  const body = await res.json();
  assert.ok(body.idToken, `sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function callGetParentAchievements(data, token) {
  const res = await fetch(
    `http://${FUNCTIONS}/${PROJECT_ID}/${CLIENT_REGION}/getParentAchievements`,
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
  let body = null;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: res.status, body };
}

const ts = (iso) => Timestamp.fromDate(new Date(iso));

let parentToken;
let otherParentToken;
let teacherToken;

test.beforeEach(async () => {
  await clearFirestore();
  await clearAuth();
  parentToken = await idTokenFor("parent1");
  otherParentToken = await idTokenFor("parent2");
  teacherToken = await idTokenFor("teacher1");
  const batch = db.batch();
  batch.set(db.doc("users/parent1"), { role: "parent", isActive: true, name: "Parent One" });
  batch.set(db.doc("users/parent2"), { role: "parent", isActive: true, name: "Parent Two" });
  batch.set(db.doc("users/teacher1"), { role: "teacher", isActive: true, name: "Teacher" });
  batch.set(db.doc("parentProfiles/parent1"), {
    uid: "parent1",
    childrenIds: ["student1", "student2"],
  });
  batch.set(db.doc("parentProfiles/parent2"), { uid: "parent2", childrenIds: ["student3"] });
  batch.set(db.doc("achievements/legacy1"), {
    studentId: "student1",
    type: "star",
    title: "نجمة",
    issuedBy: "sup1",
    halaqaId: "h1",
    date: ts("2026-10-01T10:00:00Z"),
  });
  batch.set(db.doc("achievements/multi1"), {
    studentId: "student3",
    studentName: "Other Child",
    recipientStudentIds: ["student3", "student1", "student2"],
    recipientCount: 3,
    type: "custom",
    title: "حفظ جزء",
    note: "حفظ جزء",
    description: "سبب",
    grantedBy: "teacher1",
    issuedBy: "teacher1",
    halaqaId: "h1",
    halaqaIds: ["h1"],
    halaqaName: "Halaqa One",
    date: ts("2026-10-05T10:00:00Z"),
    grantedAt: ts("2026-10-05T10:00:00Z"),
  });
  batch.set(db.doc("achievements/unrelated"), {
    studentId: "student3",
    recipientStudentIds: ["student3"],
    type: "star",
    title: "غير مرتبط",
    date: ts("2026-10-07T10:00:00Z"),
  });
  await batch.commit();
});

test("unauthenticated caller is rejected", async () => {
  const res = await callGetParentAchievements({}, null);
  assert.equal(res.body.error?.status, "UNAUTHENTICATED", JSON.stringify(res.body));
  assert.equal(res.body.result, undefined);
});

test("non-parent caller is rejected", async () => {
  const res = await callGetParentAchievements({}, teacherToken);
  assert.equal(res.body.error?.status, "PERMISSION_DENIED", JSON.stringify(res.body));
});

test("authorized parent receives only linked children's achievements, newest first", async () => {
  const res = await callGetParentAchievements({}, parentToken);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const ids = res.body.result.achievements.map((a) => a.id);
  assert.deepEqual(ids, ["multi1", "legacy1"]);
});

test("a linked child filter returns that child's achievements", async () => {
  const res = await callGetParentAchievements({ studentId: "student2" }, parentToken);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const items = res.body.result.achievements;
  assert.deepEqual(items.map((a) => a.id), ["multi1"]);
  assert.deepEqual(items[0].recipientStudentIds, ["student2"]);
  assert.equal(items[0].studentId, "student2");
});

test("unlinked child is rejected and a spoofed parent id is ignored", async () => {
  const denied = await callGetParentAchievements({ studentId: "student3" }, parentToken);
  assert.equal(denied.body.error?.status, "PERMISSION_DENIED", JSON.stringify(denied.body));
  assert.equal(denied.body.result, undefined);

  const spoofed = await callGetParentAchievements({ parentId: "parent1" }, otherParentToken);
  assert.equal(spoofed.status, 200, JSON.stringify(spoofed.body));
  assert.deepEqual(
    spoofed.body.result.achievements.map((a) => a.id),
    ["unrelated", "multi1"],
  );
  for (const a of spoofed.body.result.achievements) {
    assert.deepEqual(a.recipientStudentIds, ["student3"]);
  }
});

test("multi-recipient award is returned once without other students' data", async () => {
  const res = await callGetParentAchievements({}, parentToken);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const items = res.body.result.achievements;
  const multi = items.filter((a) => a.id === "multi1");
  assert.equal(multi.length, 1, "deduplicated across both children and both query shapes");
  assert.deepEqual([...multi[0].recipientStudentIds].sort(), ["student1", "student2"]);
  assert.equal(multi[0].studentId, "student1");
  assert.deepEqual(Object.keys(multi[0]).sort(), [
    "dateMillis",
    "description",
    "id",
    "imageUrl",
    "issuedBy",
    "recipientStudentIds",
    "studentId",
    "title",
    "type",
  ]);
  const serialized = JSON.stringify(res.body);
  for (const leak of [
    "student3",
    "Other Child",
    "Halaqa One",
    "studentName",
    "halaqaId",
    "grantedBy",
    "recipientCount",
  ]) {
    assert.ok(!serialized.includes(leak), `${leak} must not be returned`);
  }
});

test("legacy single-recipient award (studentId only) is supported", async () => {
  const res = await callGetParentAchievements({ studentId: "student1" }, parentToken);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const legacy = res.body.result.achievements.find((a) => a.id === "legacy1");
  assert.deepEqual(legacy, {
    id: "legacy1",
    studentId: "student1",
    type: "star",
    title: "نجمة",
    description: "",
    imageUrl: null,
    issuedBy: "sup1",
    dateMillis: Date.parse("2026-10-01T10:00:00Z"),
    recipientStudentIds: ["student1"],
  });
});
