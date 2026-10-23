/**
 * notifyOnAssignmentCreated executed by the Functions emulator runtime.
 *
 * The emulator wraps firebase-admin in a proxy that hands out a bound copy of
 * `admin.firestore`, which carries no static members (`FieldValue`,
 * `Timestamp`, `FieldPath`). Suites that call the fan-out core in-process
 * cannot see that, so this one creates an assignment document and waits for
 * the deployed trigger to write the in-app notifications. Synthetic data
 * only; never touches a real project.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore,functions \
 *     "node --test --test-concurrency=1 functions/test/assignment_notification_trigger.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "assignment trigger suite requires FIRESTORE_EMULATOR_HOST and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const { notificationId } = require("../lib/notifications/academyNotifications.js");

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function waitForDoc(path, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const snap = await db.doc(path).get();
    if (snap.exists) return snap;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  return null;
}

test.before(clearFirestore);
test.after(async () => {
  await clearFirestore();
  await admin.app().delete();
});

test("a created homework assignment notifies the student and the linked parent", async () => {
  const batch = db.batch();
  batch.set(db.doc("halaqat/trigH1"), {
    name: "حلقة",
    teacherId: "trigTeacher",
    studentIds: ["trigStudent"],
    status: "active",
  });
  batch.set(db.doc("users/trigStudent"), { name: "طالب", role: "student", isActive: true });
  batch.set(db.doc("parentProfiles/trigParent"), { childrenIds: ["trigStudent"] });
  await batch.commit();

  await db.doc("assignments/trigA1").set({
    halaqaId: "trigH1",
    assignedBy: "trigTeacher",
    studentId: "trigStudent",
    newMemorizationRange: "البقرة 1-5",
    reviewRange: "",
  });

  const eventId = "homework_assigned_trigA1";
  for (const observer of ["trigStudent", "trigParent"]) {
    const snap = await waitForDoc(`notifications/${notificationId(observer, eventId)}`);
    assert.ok(snap, `no notification written for ${observer}`);
    const data = snap.data();
    assert.equal(data.audience, observer);
    assert.equal(data.data.kind, "homework_assigned");
    assert.deepEqual(data.readBy, []);
    assert.ok(
      data.createdAt instanceof admin.firestore.Timestamp,
      "createdAt must be a server timestamp",
    );
  }
});
