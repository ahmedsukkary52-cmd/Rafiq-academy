import assert from "node:assert/strict";
import test from "node:test";
import { call, clearEmulatorData, closeAdminApp, createIdentity, db, expectCallableError } from "./helpers/http_callable_emulator.mjs";

test("halaqa creation wrapper is Admin-only and persists a valid authorized creation", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("r1halaqa_admin", "admin");
  const supervisorToken = await createIdentity("r1halaqa_supervisor", "supervisor");
  await createIdentity("r1halaqa_teacher", "teacher");
  await db.doc("teacherProfiles/r1halaqa_teacher").set({ halaqatIds: [] });
  const payload = {
    name: "حلقة اختبار HTTP",
    teacherId: "r1halaqa_teacher",
    schedule: [{ day: "الأحد", startTime: "18:00", endTime: "19:00" }],
    requestId: "r1-halaqa-create-0001",
  };
  await expectCallableError("adminCreateHalaqa", payload, null, "UNAUTHENTICATED");
  await expectCallableError("adminCreateHalaqa", payload, supervisorToken, "PERMISSION_DENIED");
  assert.equal((await db.doc(`halaqat/${payload.requestId}`).get()).exists, false);
  const created = await call("adminCreateHalaqa", payload, adminToken);
  assert.equal(created.status, 200, JSON.stringify(created.body));
  assert.equal(created.body.result.halaqaId, payload.requestId);
  const halaqa = await db.doc(`halaqat/${payload.requestId}`).get();
  assert.equal(halaqa.get("teacherId"), "r1halaqa_teacher");
  assert.equal(halaqa.get("createdBy"), "r1halaqa_admin");
  assert.ok((await db.doc(`teacherProfiles/r1halaqa_teacher`).get()).get("halaqatIds").includes(payload.requestId));
  assert.equal((await db.collection("auditLogs").where("source", "==", "adminCreateHalaqa").get()).size, 1);
});

test("adminCreateHalaqa refuses deactivated teacher even with pendingHalaqaAssignment forged", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("r1halaqa2_admin", "admin");
  await createIdentity("r1halaqa2_teacher", "teacher");
  await db.doc("users/r1halaqa2_teacher").set(
    {
      role: "teacher",
      isActive: false,
      staffStatus: "deactivated",
      pendingHalaqaAssignment: true,
      name: "معلم موقف",
    },
    { merge: true },
  );
  await db.doc("teacherProfiles/r1halaqa2_teacher").set({ halaqatIds: [] });
  const payload = {
    name: "حلقة معلم موقف",
    teacherId: "r1halaqa2_teacher",
    schedule: [{ day: "الإثنين", startTime: "18:00", endTime: "19:00" }],
    requestId: "r1-halaqa-create-deact-0001",
  };
  await expectCallableError(
    "adminCreateHalaqa",
    payload,
    adminToken,
    "FAILED_PRECONDITION",
  );
  assert.equal((await db.doc(`halaqat/${payload.requestId}`).get()).exists, false);
  const teacher = await db.doc("users/r1halaqa2_teacher").get();
  assert.equal(teacher.get("isActive"), false);
  assert.equal(teacher.get("staffStatus"), "deactivated");
});

test.after(closeAdminApp);
