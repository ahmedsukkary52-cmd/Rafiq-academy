/**
 * Admin milestone journeys against the Firestore emulator: complaints
 * lifecycle, absence-request notifications and halaqa name uniqueness.
 * Synthetic data only; never touches a real project.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 functions/test/admin_milestone.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;

if (!EMULATOR || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("admin milestone suite requires FIRESTORE_EMULATOR_HOST and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const complaints = require("../lib/complaints/complaintFunctions.js");
const absence = require("../lib/notifications/absenceRequestNotificationFunctions.js");
const halaqa = require("../lib/halaqa/halaqaScheduleFunctions.js");

async function clearFirestore() {
  const res = await fetch(
    `http://${EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "emulator clear failed");
}

async function seed(entries) {
  const batch = db.batch();
  for (const [path, value] of Object.entries(entries)) batch.set(db.doc(path), value);
  await batch.commit();
}

async function expectCode(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `expected ${code}, got ${err.code}: ${err.message}`);
    return true;
  });
}

const data = async (path) => (await db.doc(path).get()).data();
const user = (role, name = role) => ({ name, role, isActive: true });

test.beforeEach(async () => {
  await clearFirestore();
  await seed({
    "users/admin1": user("admin", "المدير"),
    "users/sup1": user("supervisor", "المشرف"),
    "users/teacher1": user("teacher", "المعلم"),
    "users/teacher2": user("teacher", "معلم آخر"),
    "users/parent1": user("parent", "ولي الأمر"),
    "users/parent2": user("parent", "ولي آخر"),
    "users/student1": user("student", "أحمد"),
    "users/inactiveParent": { ...user("parent"), isActive: false },
    "halaqat/h1": {
      name: "حلقة النور",
      teacherId: "teacher1",
      supervisorId: "sup1",
      studentIds: ["student1"],
      status: "active",
      schedule: [],
    },
    "parentProfiles/parent1": { childrenIds: ["student1"] },
    "parentProfiles/parent2": { childrenIds: [] },
  });
});

// ── Complaints ──────────────────────────────────────────────────────────────

test("complaint journey: parent submits → admin notified → admin reply → parent notified", async () => {
  const { complaintId } = await complaints.submitComplaintCore(db, "parent1", {
    subject: "تأخر بدء الحلقة",
    message: "الحلقة تبدأ متأخرة كل أسبوع",
    studentId: "student1",
  });
  const doc = await data(`complaints/${complaintId}`);
  assert.equal(doc.senderId, "parent1");
  assert.equal(doc.senderRole, "parent");
  assert.equal(doc.senderName, "ولي الأمر");
  assert.equal(doc.studentId, "student1");
  assert.equal(doc.studentName, "أحمد");
  assert.equal(doc.status, "open");
  assert.equal("priority" in doc, false);

  const adminNote = await data(`notifications/admin_complaint_created_${complaintId}`);
  assert.equal(adminNote.audience, "admin");
  assert.equal(adminNote.type, "complaint");
  assert.equal(adminNote.data.complaintId, complaintId);

  const reply = await complaints.respondToComplaintCore(db, "admin1", {
    complaintId,
    message: "تم التواصل مع المعلم",
  });
  assert.equal(reply.status, "in_progress");
  const history = await data(`complaints/${complaintId}/history/${reply.historyId}`);
  assert.equal(history.authorRole, "admin");
  assert.equal(history.statusFrom, "open");
  assert.equal(history.statusTo, "in_progress");
  const parentNote = await data(`notifications/parent1_complaint_update_${reply.historyId}`);
  assert.equal(parentNote.audience, "parent1");
  assert.equal(parentNote.data.complaintId, complaintId);

  const resolved = await complaints.respondToComplaintCore(db, "admin1", { complaintId, status: "resolved" });
  assert.equal(resolved.status, "resolved");

  const followUp = await complaints.respondToComplaintCore(db, "parent1", {
    complaintId,
    message: "ما زالت المشكلة قائمة",
  });
  assert.equal(followUp.status, "open");
  assert.ok(await data(`notifications/admin_complaint_reply_${followUp.historyId}`));
  const final = await data(`complaints/${complaintId}`);
  assert.equal(final.historyCount, 3);
  assert.equal(
    (await db.collection(`complaints/${complaintId}/history`).get()).size,
    3,
  );
});

test("complaint submission is restricted by role, relationship and content", async () => {
  await expectCode(
    complaints.submitComplaintCore(db, "student1", { subject: "x", message: "y" }),
    "permission-denied",
  );
  await expectCode(
    complaints.submitComplaintCore(db, "inactiveParent", { subject: "x", message: "y" }),
    "permission-denied",
  );
  await expectCode(
    complaints.submitComplaintCore(db, "parent2", { subject: "x", message: "y", studentId: "student1" }),
    "permission-denied",
  );
  await expectCode(
    complaints.submitComplaintCore(db, "teacher2", { subject: "x", message: "y", halaqaId: "h1" }),
    "permission-denied",
  );
  await expectCode(
    complaints.submitComplaintCore(db, "parent1", { subject: "x", message: "كلمني 01012345678" }),
    "invalid-argument",
  );
  await expectCode(complaints.submitComplaintCore(db, "parent1", { subject: "", message: "y" }), "invalid-argument");

  const teacher = await complaints.submitComplaintCore(db, "teacher1", {
    subject: "نقص في المواد",
    message: "نحتاج مصاحف إضافية",
    halaqaId: "h1",
  });
  const t = await data(`complaints/${teacher.complaintId}`);
  assert.equal(t.halaqaName, "حلقة النور");
  assert.equal(t.senderRole, "teacher");

  const sup = await complaints.submitComplaintCore(db, "sup1", { subject: "ملاحظة", message: "نص" });
  assert.equal((await data(`complaints/${sup.complaintId}`)).senderRole, "supervisor");
});

test("only the admin changes status; strangers cannot reply", async () => {
  const { complaintId } = await complaints.submitComplaintCore(db, "parent1", { subject: "s", message: "m" });
  await expectCode(
    complaints.respondToComplaintCore(db, "parent1", { complaintId, status: "resolved" }),
    "permission-denied",
  );
  await expectCode(
    complaints.respondToComplaintCore(db, "parent2", { complaintId, message: "تدخل" }),
    "permission-denied",
  );
  await expectCode(
    complaints.respondToComplaintCore(db, "teacher1", { complaintId, message: "تدخل" }),
    "permission-denied",
  );
  await expectCode(
    complaints.respondToComplaintCore(db, "admin1", { complaintId, status: "bogus" }),
    "invalid-argument",
  );
  await expectCode(complaints.respondToComplaintCore(db, "admin1", { complaintId }), "invalid-argument");
  await expectCode(
    complaints.respondToComplaintCore(db, "admin1", { complaintId: "missing", message: "x" }),
    "not-found",
  );
});

// ── Absence (permission) requests ───────────────────────────────────────────

const absenceRequest = (overrides = {}) => ({
  studentId: "student1",
  halaqaId: "h1",
  requestedBy: "parent1",
  date: admin.firestore.Timestamp.fromDate(new Date("2026-11-03T08:00:00Z")),
  reason: "موعد طبي",
  status: "pending",
  ...overrides,
});

test("absence request journey: teacher and supervisor notified; parent notified on review", async () => {
  const id = "h1_student1_20261103";
  const created = await absence.fanOutAbsenceRequestCreated(db, id, absenceRequest());
  assert.equal(created.written, 2);
  const teacherNote = await data(`notifications/teacher1_absence_request_${id}`);
  assert.equal(teacherNote.audience, "teacher1");
  assert.equal(teacherNote.type, "absence_request");
  assert.match(teacherNote.body, /أحمد/);
  assert.match(teacherNote.body, /03\/11\/2026/);
  assert.ok(await data(`notifications/sup1_absence_request_${id}`));

  const before = absenceRequest();
  const after = { ...before, status: "approved", reviewedBy: "sup1" };
  const reviewed = await absence.notifyAbsenceRequestReviewed(db, id, before, after);
  assert.equal(reviewed.written, 1);
  const parentNote = await data(`notifications/parent1_absence_request_reviewed_${id}`);
  assert.equal(parentNote.audience, "parent1");
  assert.match(parentNote.title, /الموافقة/);

  const same = await absence.notifyAbsenceRequestReviewed(db, id, after, after);
  assert.equal(same.skipped, "status_unchanged");
});

test("forged absence requests notify nobody", async () => {
  const forgedParent = await absence.fanOutAbsenceRequestCreated(
    db,
    "x1",
    absenceRequest({ requestedBy: "parent2" }),
  );
  assert.equal(forgedParent.skipped, "parent_not_linked");
  const offRoster = await absence.fanOutAbsenceRequestCreated(
    db,
    "x2",
    absenceRequest({ studentId: "ghost" }),
  );
  assert.equal(offRoster.skipped, "parent_not_linked");
  const noHalaqa = await absence.fanOutAbsenceRequestCreated(db, "x3", absenceRequest({ halaqaId: "nope" }));
  assert.equal(noHalaqa.skipped, "halaqa_missing");
  assert.equal((await db.collection("notifications").get()).size, 0);
});

// ── Halaqa name uniqueness ──────────────────────────────────────────────────

let slotCounter = 0;
const nextSlot = () => `slot-${++slotCounter}`;
const newHalaqa = (name, day = "السبت") => ({
  name,
  teacherId: "teacher2",
  schedule: [{ day, startTime: "16:00", endTime: "17:00" }],
});

test("duplicate halaqa names are rejected after Arabic normalization", async () => {
  const created = await halaqa.adminCreateHalaqaCore(db, "admin1", newHalaqa("حلقة الفجر"), nextSlot);
  assert.equal((await data(`halaqat/${created.halaqaId}`)).nameKey, "حلقه الفجر");
  assert.equal((await data("halaqaNameIndex/حلقه الفجر")).halaqaId, created.halaqaId);

  for (const variant of ["حلقة الفجر", "  حَلَقَةُ   الفَجْر ", "حلقه-الفجر"]) {
    await expectCode(
      halaqa.adminCreateHalaqaCore(db, "admin1", newHalaqa(variant, "الأحد"), nextSlot),
      "already-exists",
    );
  }
  // Legacy halaqa (seeded without a lock document) still blocks its name.
  await expectCode(
    halaqa.adminCreateHalaqaCore(db, "admin1", newHalaqa("حلقه النور", "الأحد"), nextSlot),
    "already-exists",
  );
  const other = await halaqa.adminCreateHalaqaCore(db, "admin1", newHalaqa("حلقة العصر", "الأحد"), nextSlot);
  assert.ok(other.halaqaId);
});

test("concurrent creations of the same name: exactly one succeeds", async () => {
  const results = await Promise.allSettled([
    halaqa.adminCreateHalaqaCore(db, "admin1", newHalaqa("حلقة الضحى", "الاثنين"), nextSlot),
    halaqa.adminCreateHalaqaCore(
      db,
      "admin1",
      { ...newHalaqa("حلقة الضُّحى", "الثلاثاء"), teacherId: "teacher1" },
      nextSlot,
    ),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  const rejected = results.find((r) => r.status === "rejected");
  assert.equal(rejected.reason.code, "already-exists");
});

test.after(async () => {
  await clearFirestore();
  await admin.app().delete();
});
