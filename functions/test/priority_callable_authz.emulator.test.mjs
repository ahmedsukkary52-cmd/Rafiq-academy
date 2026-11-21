/**
 * Security Closure — HTTP AuthZ negatives for priority callables that were
 * EMULATOR_POSITIVE / UNIT_ONLY only:
 *   - ensureAdminGroupConversation
 *   - materializeSession
 *
 * Run (repo root, after functions build):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only auth,firestore,functions \
 *     "node --test --test-concurrency=1 functions/test/priority_callable_authz.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import {
  call,
  clearEmulatorData,
  closeAdminApp,
  createIdentity,
  db,
  expectCallableError,
} from "./helpers/http_callable_emulator.mjs";

test("ensureAdminGroupConversation rejects non-admin and spoofed membership fields", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("pc_admin", "admin");
  const supervisorToken = await createIdentity("pc_supervisor", "supervisor");
  const teacherToken = await createIdentity("pc_teacher", "teacher");
  const parentToken = await createIdentity("pc_parent", "parent");
  await expectCallableError("ensureAdminGroupConversation", {}, null, "UNAUTHENTICATED");
  await expectCallableError("ensureAdminGroupConversation", {}, supervisorToken, "PERMISSION_DENIED");
  await expectCallableError("ensureAdminGroupConversation", {}, teacherToken, "PERMISSION_DENIED");
  await expectCallableError("ensureAdminGroupConversation", {}, parentToken, "PERMISSION_DENIED");
  assert.equal((await db.doc("conversations/admin_internal_group").get()).exists, false);

  await expectCallableError(
    "ensureAdminGroupConversation",
    { participantIds: ["pc_teacher"] },
    adminToken,
    "INVALID_ARGUMENT",
  );
  assert.equal((await db.doc("conversations/admin_internal_group").get()).exists, false);

  const ok = await call("ensureAdminGroupConversation", {}, adminToken);
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  assert.equal(ok.body.result.conversationId, "admin_internal_group");
  assert.equal(
    (await db.doc("conversations/admin_internal_group").get()).get("participantIds").includes("pc_admin"),
    true,
  );
});

test("materializeSession rejects unauthenticated and out-of-scope roles over HTTP", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("ms_admin", "admin");
  const teacherToken = await createIdentity("ms_teacher", "teacher");
  const otherTeacherToken = await createIdentity("ms_teacher2", "teacher");
  const supervisorToken = await createIdentity("ms_supervisor", "supervisor");
  const parentToken = await createIdentity("ms_parent", "parent");
  const studentToken = await createIdentity("ms_student", "student");

  await db.doc("halaqat/ms_halaqa").set({
    name: "حلقة اختبار",
    status: "active",
    teacherId: "ms_teacher",
    supervisorId: "ms_supervisor",
    studentIds: ["ms_student"],
    schedule: [
      {
        slotId: "slot_ms_1",
        day: "السبت",
        startTime: "16:00",
        endTime: "17:00",
      },
    ],
  });

  // Saturday in Cairo (same contract as P0-04 materialize fixture).
  const payload = { halaqaId: "ms_halaqa", slotId: "slot_ms_1", date: "2026-10-03" };

  await expectCallableError("materializeSession", payload, null, "UNAUTHENTICATED");
  await expectCallableError("materializeSession", payload, supervisorToken, "PERMISSION_DENIED");
  await expectCallableError("materializeSession", payload, parentToken, "PERMISSION_DENIED");
  await expectCallableError("materializeSession", payload, studentToken, "PERMISSION_DENIED");
  await expectCallableError("materializeSession", payload, otherTeacherToken, "PERMISSION_DENIED");
  assert.equal((await db.collection("sessions").get()).size, 0);

  // Spoofed staff/roster fields must be ignored by the wrapper.
  const spoofed = await call(
    "materializeSession",
    {
      ...payload,
      teacherId: "ms_teacher2",
      studentIds: ["forged"],
    },
    teacherToken,
  );
  assert.equal(spoofed.status, 200, JSON.stringify(spoofed.body));
  const sessionId = spoofed.body.result.sessionId;
  const session = (await db.doc(`sessions/${sessionId}`).get()).data();
  // Authoritative halaqa teacher; client studentIds/teacherId are never persisted.
  assert.equal(session.teacherId, "ms_teacher");
  assert.equal(session.studentIds, undefined);
  assert.notEqual(session.teacherId, "ms_teacher2");

  const adminOk = await call("materializeSession", payload, adminToken);
  assert.equal(adminOk.status, 200, JSON.stringify(adminOk.body));
  assert.equal(adminOk.body.result.sessionId, sessionId);
});

test.after(closeAdminApp);
