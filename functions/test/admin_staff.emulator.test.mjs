/**
 * Admin staff lifecycle (journey 13) and halaqa staff reassignment
 * (journey 14) against the Firestore + Auth emulators. Synthetic data only.
 *
 * Run from repo root (after building functions):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore \
 *     "node --test --test-concurrency=1 functions/test/admin_staff.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("staff suite requires firestore + auth emulators and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();
const { Timestamp } = require("firebase-admin/firestore");

const staff = require("../lib/staff/staffLifecycleFunctions.js");

const ADMIN = "admin_staff";
const PASSWORD = "Synthetic-Pass-42";
const deps = { db, auth };
const HOUR = 3600 * 1000;
const slot = (day, startTime, endTime, slotId) => ({ slotId, day, startTime, endTime });

async function clearAll() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const res = await fetch(url, { method: "DELETE" });
    assert.equal(res.ok, true, `emulator clear failed: ${url}`);
  }
}

async function signIn(email) {
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password: PASSWORD, returnSecureToken: true }),
    },
  );
  return res.ok;
}

const email = (uid) => `${uid}@members.rafiq-academy.invalid`;

async function seed() {
  const users = {
    [ADMIN]: { name: "المدير", role: "admin", isActive: true },
    t1: { name: "أحمد", role: "teacher", isActive: true },
    t2: { name: "محمود", role: "teacher", isActive: true },
    t3: { name: "خالد", role: "teacher", isActive: true },
    t4: { name: "يوسف", role: "teacher", isActive: true },
    tLegacyOff: { name: "قديم", role: "teacher", isActive: false },
    s1: { name: "سعاد", role: "supervisor", isActive: true },
    s2: { name: "منى", role: "supervisor", isActive: true },
    p1: { name: "ولي", role: "parent", isActive: true },
  };
  const batch = db.batch();
  for (const [uid, data] of Object.entries(users)) {
    batch.set(db.doc(`users/${uid}`), data);
    await auth.createUser({ uid, email: email(uid), password: PASSWORD, displayName: data.name });
  }
  batch.set(db.doc("userPrivate/t1"), { email: email("t1"), loginUsername: "tc000001" });
  batch.set(db.doc("loginUsernames/tc000001"), { uid: "t1", role: "teacher", status: "active" });
  batch.set(db.doc("teacherProfiles/t1"), { halaqatIds: ["h1"] });
  batch.set(db.doc("teacherProfiles/t3"), { halaqatIds: ["h2"] });
  batch.set(db.doc("halaqat/h1"), {
    name: "حلقة الفجر",
    status: "active",
    teacherId: "t1",
    supervisorId: "s1",
    studentIds: ["st1"],
    schedule: [slot("الأحد", "16:00", "17:00", "slot_a")],
  });
  batch.set(db.doc("halaqat/h2"), {
    name: "حلقة العصر",
    status: "active",
    teacherId: "t3",
    supervisorId: "",
    studentIds: [],
    schedule: [slot("الأحد", "16:30", "17:30", "slot_b")],
  });
  const now = Date.now();
  const session = (status, startMs) => ({
    halaqaId: "h1",
    slotId: "slot_a",
    status,
    teacherId: "t1",
    supervisorId: "s1",
    startAt: Timestamp.fromMillis(startMs),
    endAt: Timestamp.fromMillis(startMs + HOUR),
  });
  batch.set(db.doc("sessions/past"), session("completed", now - 48 * HOUR));
  batch.set(db.doc("sessions/missed"), session("scheduled", now - 24 * HOUR));
  batch.set(db.doc("sessions/live"), session("in_progress", now - 10 * 60 * 1000));
  batch.set(db.doc("sessions/next"), session("scheduled", now + 24 * HOUR));
  batch.set(db.doc("sessions/later"), session("scheduled", now + 7 * 24 * HOUR));
  await batch.commit();
}

const data = async (path) => (await db.doc(path).get()).data();
const audits = async (action) =>
  (await db.collection("auditLogs").where("action", "==", action).get()).docs.map((d) => d.data());

async function rejects(promise, code, messagePart) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code, `expected ${code}, got ${e.code}: ${e.message}`);
    if (messagePart) assert.match(e.message, new RegExp(messagePart));
    return true;
  });
}

test.beforeEach(async () => {
  await clearAll();
  await seed();
});

test("journey 14: transactional, audited reassignment never leaves a halaqa without a teacher", async () => {
  const reassign = (uid, d) => staff.adminReassignHalaqaStaffCore(db, uid, d);

  await rejects(reassign("t2", { halaqaId: "h1", role: "teacher", newStaffId: "t2" }), "permission-denied");
  await rejects(reassign(ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "" }), "invalid-argument", "بلا معلم");
  await rejects(reassign(ADMIN, { halaqaId: "h1", role: "owner", newStaffId: "t2" }), "invalid-argument");
  await rejects(reassign(ADMIN, { halaqaId: "nope", role: "teacher", newStaffId: "t2" }), "not-found");
  await rejects(reassign(ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "s1" }), "failed-precondition", "المعلم المحدد غير صالح");
  await rejects(reassign(ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "tLegacyOff" }), "failed-precondition", "غير نشط");
  // t3 already teaches h2 on Sunday 16:30 — overlaps h1's 16:00-17:00 slot.
  await rejects(reassign(ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "t3" }), "failed-precondition", "يتداخل");
  assert.equal((await data("halaqat/h1")).teacherId, "t1", "failed attempts change nothing");
  assert.equal((await audits("halaqa_staff_reassign")).length, 0);

  const moved = await reassign(ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "t2" });
  assert.deepEqual(moved, {
    halaqaId: "h1",
    role: "teacher",
    previousStaffId: "t1",
    newStaffId: "t2",
    changed: true,
    sessionsUpdated: 2,
  });
  assert.equal((await data("halaqat/h1")).teacherId, "t2");
  assert.deepEqual((await data("teacherProfiles/t1")).halaqatIds, []);
  assert.deepEqual((await data("teacherProfiles/t2")).halaqatIds, ["h1"]);
  assert.equal((await data("sessions/next")).teacherId, "t2");
  assert.equal((await data("sessions/later")).teacherId, "t2");
  for (const kept of ["past", "missed", "live"]) {
    assert.equal((await data(`sessions/${kept}`)).teacherId, "t1", `${kept} keeps its historical teacher`);
  }
  const [entry] = await audits("halaqa_staff_reassign");
  assert.equal(entry.actorId, ADMIN);
  assert.equal(entry.targetId, "h1");
  assert.deepEqual(entry.metadata, {
    halaqaId: "h1",
    role: "teacher",
    previousStaffId: "t1",
    newStaffId: "t2",
    updatedCount: 2,
  });

  const again = await reassign(ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "t2" });
  assert.equal(again.changed, false);
  assert.equal((await audits("halaqa_staff_reassign")).length, 1, "retry is idempotent");

  await reassign(ADMIN, { halaqaId: "h1", role: "supervisor", newStaffId: "s2" });
  assert.equal((await data("halaqat/h1")).supervisorId, "s2");
  assert.equal((await data("sessions/next")).supervisorId, "s2");
  assert.equal((await data("sessions/past")).supervisorId, "s1");
  await reassign(ADMIN, { halaqaId: "h1", role: "supervisor", newStaffId: "" });
  assert.equal((await data("halaqat/h1")).supervisorId, "");
  assert.equal((await data("sessions/next")).supervisorId, undefined);
});

test("journey 13: deactivate / archive / delete are distinct, gated and audited", async () => {
  const setStatus = (uid, d) => staff.adminSetStaffStatusCore(deps, uid, d);
  assert.equal(await signIn(email("t1")), true);

  await rejects(setStatus("t2", { uid: "t1", action: "deactivate" }), "permission-denied");
  await rejects(setStatus(ADMIN, { uid: ADMIN, action: "deactivate" }), "failed-precondition", "حسابك");
  await rejects(setStatus(ADMIN, { uid: "p1", action: "deactivate" }), "failed-precondition", "للمعلمين والمشرفين");
  await rejects(setStatus(ADMIN, { uid: "t1", action: "suspend" }), "invalid-argument");

  // Still teaching h1: refused, with the halaqa named, and nothing changes.
  await assert.rejects(setStatus(ADMIN, { uid: "t1", action: "deactivate" }), (e) => {
    assert.equal(e.code, "failed-precondition");
    assert.match(e.message, /حلقة الفجر/);
    assert.equal(e.details.code, "staff_has_halaqat");
    assert.deepEqual(e.details.halaqat, [{ id: "h1", name: "حلقة الفجر" }]);
    return true;
  });
  await rejects(setStatus(ADMIN, { uid: "s1", action: "deactivate" }), "failed-precondition", "حلقة الفجر");
  assert.equal((await data("users/t1")).isActive, true);
  assert.equal((await auth.getUser("t1")).disabled, false);
  await rejects(setStatus(ADMIN, { uid: "t1", action: "archive" }), "failed-precondition", "عطّل الحساب أولاً");

  await staff.adminReassignHalaqaStaffCore(db, ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "t2" });
  const off = await setStatus(ADMIN, { uid: "t1", action: "deactivate" });
  assert.deepEqual(off, { uid: "t1", status: "deactivated", changed: true });
  const t1 = await data("users/t1");
  assert.equal(t1.isActive, false);
  assert.equal(t1.staffStatus, "deactivated");
  assert.equal((await auth.getUser("t1")).disabled, true);
  assert.equal(await signIn(email("t1")), false, "a deactivated teacher cannot sign in");
  assert.equal((await setStatus(ADMIN, { uid: "t1", action: "deactivate" })).changed, false);
  await rejects(
    staff.adminReassignHalaqaStaffCore(db, ADMIN, { halaqaId: "h1", role: "teacher", newStaffId: "t1" }),
    "failed-precondition",
    "غير نشط",
  );
  await rejects(setStatus(ADMIN, { uid: "t1", action: "delete" }), "failed-precondition", "أرشف الحساب أولاً");

  assert.equal((await setStatus(ADMIN, { uid: "t1", action: "archive" })).status, "archived");
  assert.equal((await data("users/t1")).isActive, false);
  const deleted = await setStatus(ADMIN, { uid: "t1", action: "delete" });
  assert.equal(deleted.status, "deleted");
  await assert.rejects(auth.getUser("t1"), (e) => e.code === "auth/user-not-found");
  assert.equal((await db.doc("userPrivate/t1").get()).exists, false);
  assert.equal((await data("loginUsernames/tc000001")).status, "retired");
  const tomb = await data("users/t1");
  assert.equal(tomb.name, "أحمد", "history still resolves a name");
  assert.equal(tomb.staffStatus, "deleted");
  assert.equal(tomb.role, "teacher");
  await rejects(setStatus(ADMIN, { uid: "t1", action: "reactivate" }), "failed-precondition", "محذوف نهائياً");
  assert.equal((await data("sessions/past")).teacherId, "t1", "history is untouched by deletion");

  const trail = (await audits("staff_status_change")).map((a) => [a.targetId, a.metadata.previousStatus, a.metadata.newStatus]);
  assert.deepEqual(trail.sort(), [
    ["t1", "active", "deactivated"],
    ["t1", "archived", "deleted"],
    ["t1", "deactivated", "archived"],
  ]);
});

test("reactivation restores sign-in; legacy inactive accounts follow the same lifecycle", async () => {
  const setStatus = (d) => staff.adminSetStaffStatusCore(deps, ADMIN, d);
  await setStatus({ uid: "t4", action: "deactivate" });
  await setStatus({ uid: "t4", action: "archive" });
  assert.equal(await signIn(email("t4")), false);
  const back = await setStatus({ uid: "t4", action: "reactivate" });
  assert.equal(back.status, "active");
  assert.equal((await data("users/t4")).isActive, true);
  assert.equal((await auth.getUser("t4")).disabled, false);
  assert.equal(await signIn(email("t4")), true);

  // No staffStatus field, isActive false → treated as deactivated.
  assert.equal(staff.staffStatusOf(await data("users/tLegacyOff")), "deactivated");
  assert.equal((await setStatus({ uid: "tLegacyOff", action: "archive" })).status, "archived");
  await rejects(setStatus({ uid: "t4", action: "archive" }), "failed-precondition", "عطّل الحساب أولاً");
});
