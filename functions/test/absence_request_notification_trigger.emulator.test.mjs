/**
 * R1-E — absence-request notification triggers.
 *
 * This suite drives both exported Firestore triggers through source-document
 * writes in the local Functions Emulator. It uses synthetic data only.
 *
 * Run from the repository root:
 *   npx firebase-tools emulators:exec --project demo-rafiq-rules --only firestore,functions \
 *     "node --test --test-concurrency=1 functions/test/absence_request_notification_trigger.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "absence trigger suite requires FIRESTORE_EMULATOR_HOST and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

async function clearFirestore() {
  const response = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(response.ok, true, "emulator clear failed");
}

async function waitForDoc(path, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const snapshot = await db.doc(path).get();
    if (snapshot.exists) return snapshot;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  return null;
}

async function waitForMissing(path, timeoutMs = 5_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const snapshot = await db.doc(path).get();
    if (!snapshot.exists) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(`unexpected notification at ${path}`);
}

const notificationPath = (id) => `notifications/${id}`;

test.before(clearFirestore);
test.after(async () => {
  await clearFirestore();
  await admin.app().delete();
});

test("absence request triggers notify scoped staff and parent without duplicate review notifications", async () => {
  const batch = db.batch();
  batch.set(db.doc("halaqat/absenceH1"), {
    name: "حلقة الاختبار",
    teacherId: "absenceTeacher",
    supervisorId: "absenceSupervisor",
    studentIds: ["absenceStudent"],
    status: "active",
  });
  batch.set(db.doc("users/absenceStudent"), {
    name: "طالب الغياب",
    role: "student",
    isActive: true,
  });
  batch.set(db.doc("parentProfiles/absenceParent"), {
    childrenIds: ["absenceStudent"],
  });
  await batch.commit();

  await db.doc("absenceRequests/absenceR1").set({
    halaqaId: "absenceH1",
    studentId: "absenceStudent",
    requestedBy: "absenceParent",
    date: "2026-11-14T08:00:00.000Z",
    status: "pending",
  });

  for (const recipient of ["absenceTeacher", "absenceSupervisor"]) {
    const snapshot = await waitForDoc(
      notificationPath(`${recipient}_absence_request_absenceR1`),
    );
    assert.ok(snapshot, `missing staff notification for ${recipient}`);
    const data = snapshot.data();
    assert.equal(data.audience, recipient);
    assert.equal(data.type, "absence_request");
    assert.deepEqual(data.data, {
      requestId: "absenceR1",
      halaqaId: "absenceH1",
      studentId: "absenceStudent",
    });
  }

  await db.doc("absenceRequests/absenceR1").update({ status: "approved" });
  const parentPath = notificationPath(
    "absenceParent_absence_request_reviewed_absenceR1",
  );
  const parentNotification = await waitForDoc(parentPath);
  assert.ok(parentNotification, "missing parent review notification");
  assert.equal(parentNotification.data().audience, "absenceParent");
  assert.equal(parentNotification.data().title, "تمت الموافقة على طلب الاستئذان");

  await db.doc("absenceRequests/absenceR1").update({
    status: "approved",
    reviewerNote: "same status retry",
  });
  await new Promise((resolve) => setTimeout(resolve, 1_000));
  const notifications = await db
    .collection("notifications")
    .where("type", "==", "absence_request")
    .get();
  assert.equal(notifications.size, 3, "same review status must not duplicate notification");

  await db.doc("absenceRequests/absenceForged").set({
    halaqaId: "absenceH1",
    studentId: "absenceStudent",
    requestedBy: "unlinkedParent",
    status: "pending",
  });
  await waitForMissing(
    notificationPath("absenceTeacher_absence_request_absenceForged"),
  );
  await waitForMissing(
    notificationPath("absenceSupervisor_absence_request_absenceForged"),
  );
});
