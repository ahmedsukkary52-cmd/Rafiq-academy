/**
 * R1-F — source-write evidence for group and student-search projections.
 * Synthetic Firestore Emulator data only; no production access.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
if (!FIRESTORE || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("projection/group trigger suite requires Firestore and a demo project");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;
const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

async function clearFirestore() {
  const response = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(response.ok, true, "emulator clear failed");
}

async function waitFor(path, predicate = (snapshot) => snapshot.exists, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const snapshot = await db.doc(path).get();
    if (predicate(snapshot)) return snapshot;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(`timed out waiting for ${path}`);
}

async function waitForMissing(path, timeoutMs = 5_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!(await db.doc(path).get()).exists) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(`unexpected document at ${path}`);
}

test.before(clearFirestore);
test.after(async () => {
  await clearFirestore();
  await admin.app().delete();
});

test("source writes converge halaqa/admin groups and student search projections idempotently", async () => {
  await db.doc("conversations/admin_internal_group").set({
    kind: "admin_group",
    title: "مجموعة الإدارة",
    participantIds: [],
    participants: [],
    unreadCounts: {},
  });
  await db.doc("studentProfiles/projStudent").set({ name: "اسم قديم", halaqaId: "projHalaqa" });
  await db.doc("halaqat/projHalaqa").set({
    name: "حلقة قديمة",
    teacherId: "projTeacher",
    supervisorId: "projSupervisor",
    studentIds: ["projStudent"],
    status: "active",
  });

  // users/{uid}: creates the studentSearch projection and the admin-group
  // trigger observes the same user-write family.
  await db.doc("users/projAdmin").set({ name: "المدير", role: "admin", isActive: true });
  await db.doc("users/projStudent").set({ name: "طالب التجربة", role: "student", isActive: true });
  const searchPath = "studentSearch/projStudent";
  const initialSearch = await waitFor(searchPath);
  assert.equal(initialSearch.data().fullName, "طالب التجربة");
  assert.deepEqual(initialSearch.data().halaqaIds, ["projHalaqa"]);
  assert.deepEqual(initialSearch.data().visibleTo.sort(), ["projSupervisor", "projTeacher"]);

  await db.doc("studentProfiles/projStudent").update({ name: "اسم الملف الجديد" });
  await db.doc("users/projStudent").update({ name: "اسم المستخدم الجديد" });
  const renamed = await waitFor(searchPath, (snapshot) => snapshot.data()?.fullName === "اسم المستخدم الجديد");
  assert.equal(renamed.data().fullNameNormalized.length > 0, true);

  // halaqat/{id}: membership/staff projection updates the search row and
  // creates the managed halaqa conversation.
  await db.doc("halaqat/projHalaqa").update({
    name: "حلقة جديدة",
    studentIds: ["projStudent"],
  });
  const group = await waitFor("conversations/halaqa_group_projHalaqa");
  assert.equal(group.data().kind, "halaqa_group");
  assert.deepEqual(group.data().participantIds.sort(), ["projStudent", "projSupervisor", "projTeacher"].sort());
  await waitFor(searchPath, (snapshot) => snapshot.data()?.halaqaName === "حلقة جديدة");

  // A no-op membership write must not multiply participants or alter the
  // deterministic group identity.
  const beforeGroup = (await db.doc("conversations/halaqa_group_projHalaqa").get()).data();
  await db.doc("halaqat/projHalaqa").update({ description: "unrelated field" });
  await new Promise((resolve) => setTimeout(resolve, 750));
  const afterGroup = (await db.doc("conversations/halaqa_group_projHalaqa").get()).data();
  assert.deepEqual(afterGroup.participantIds, beforeGroup.participantIds);

  // users/{uid} drives admin-group membership for active Admin users only.
  const adminGroup = await waitFor("conversations/admin_internal_group");
  assert.equal(adminGroup.data().kind, "admin_group");
  assert.deepEqual(adminGroup.data().participantIds, ["projAdmin"]);

  await db.doc("users/projAdmin").update({ isActive: false });
  await new Promise((resolve) => setTimeout(resolve, 1_000));
  const inactiveGroup = (await db.doc("conversations/admin_internal_group").get()).data();
  assert.deepEqual(inactiveGroup.participantIds, []);

  // A non-student user must not leave a search projection behind.
  await db.doc("users/projStudent").update({ role: "teacher" });
  await waitForMissing(searchPath);
});
