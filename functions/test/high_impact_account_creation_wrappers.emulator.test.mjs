import assert from "node:assert/strict";
import test from "node:test";
import { admin, call, clearEmulatorData, closeAdminApp, createIdentity, db, expectCallableError } from "./helpers/http_callable_emulator.mjs";

test("account creation wrappers enforce Admin authorization and persist only authorized requests", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("r1acct_admin", "admin");
  const parentToken = await createIdentity("r1acct_parent", "parent");
  const teacherToken = await createIdentity("r1acct_teacher", "teacher");
  await db.doc("parentProfiles/r1acct_parent").set({ childrenIds: [] });
  await db.doc("teacherProfiles/r1acct_teacher").set({ halaqatIds: [] });
  await db.doc("halaqat/r1acct_halaqa").set({ name: "اختبار", status: "active", teacherId: "r1acct_teacher", supervisorId: "", studentIds: [], schedule: [] });

  const accountData = { role: "parent", name: "ولي تجريبي" };
  await expectCallableError("adminCreateMemberAccount", accountData, null, "UNAUTHENTICATED");
  await expectCallableError("adminCreateMemberAccount", accountData, parentToken, "PERMISSION_DENIED");
  assert.equal((await db.collection("users").where("name", "==", accountData.name).get()).size, 0);
  const created = await call("adminCreateMemberAccount", accountData, adminToken);
  assert.equal(created.status, 200, JSON.stringify(created.body));
  const member = created.body.result;
  assert.equal((await db.doc(`users/${member.uid}`).get()).get("role"), "parent");
  assert.equal((await db.doc(`userPrivate/${member.uid}`).get()).get("mustChangePassword"), true);

  const importData = { importId: "imp_0123456789abcdef", row: { kind: "parent", ref: "P-901", name: "ولي استيراد" } };
  await expectCallableError("adminImportAcademyRow", importData, null, "UNAUTHENTICATED");
  await expectCallableError("adminImportAcademyRow", importData, teacherToken, "PERMISSION_DENIED");
  assert.equal((await db.doc("importRows/P-901").get()).exists, false);
  assert.equal((await db.collection("users").where("name", "==", "ولي استيراد").get()).size, 0);
  const imported = await call("adminImportAcademyRow", importData, adminToken);
  assert.equal(imported.status, 200, JSON.stringify(imported.body));
  assert.equal(imported.body.result.kind, "parent");
  assert.equal((await db.doc("importRows/P-901").get()).get("status"), "done");

  const onboardData = { requestId: "r1onboardrequest001", studentName: "طالب تجريبي", parent: { mode: "existing", parentId: "r1acct_parent" }, halaqaId: "r1acct_halaqa" };
  await expectCallableError("adminOnboardStudent", onboardData, null, "UNAUTHENTICATED");
  await expectCallableError("adminOnboardStudent", onboardData, parentToken, "PERMISSION_DENIED");
  assert.deepEqual((await db.doc("parentProfiles/r1acct_parent").get()).get("childrenIds"), []);
  assert.deepEqual((await db.doc("halaqat/r1acct_halaqa").get()).get("studentIds"), []);
  assert.equal((await db.collection("users").where("name", "==", "طالب تجريبي").get()).size, 0);
  assert.equal((await db.doc("onboardingRequests/r1acct_admin_r1onboardrequest001").get()).exists, false);
  const onboarded = await call("adminOnboardStudent", onboardData, adminToken);
  assert.equal(onboarded.status, 200, JSON.stringify(onboarded.body));
  assert.equal(onboarded.body.result.status, "completed");
  const studentId = onboarded.body.result.studentId;
  assert.equal((await db.doc(`users/${studentId}`).get()).get("role"), "student");
  assert.deepEqual((await db.doc("parentProfiles/r1acct_parent").get()).get("childrenIds"), [studentId]);
  assert.deepEqual((await db.doc("halaqat/r1acct_halaqa").get()).get("studentIds"), [studentId]);
});

test("supervisorOnboardStudent rejects unauthenticated, wrong-role, and cross-halaqa callers", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("r1sup_admin", "admin");
  const parentToken = await createIdentity("r1sup_parent", "parent");
  const teacherToken = await createIdentity("r1sup_teacher", "teacher");
  const supervisorToken = await createIdentity("r1sup_supervisor", "supervisor");
  const otherSupervisorToken = await createIdentity("r1sup_supervisor2", "supervisor");
  await db.doc("parentProfiles/r1sup_parent").set({ childrenIds: [] });
  await db.doc("halaqat/r1sup_halaqa").set({
    name: "حلقة مشرف",
    status: "active",
    teacherId: "r1sup_teacher",
    supervisorId: "r1sup_supervisor",
    studentIds: [],
    schedule: [],
  });

  const payload = {
    requestId: "r1superonboardreq001",
    studentName: "طالب مشرف",
    parent: { mode: "existing", parentId: "r1sup_parent" },
    halaqaId: "r1sup_halaqa",
  };

  await expectCallableError("supervisorOnboardStudent", payload, null, "UNAUTHENTICATED");
  await expectCallableError("supervisorOnboardStudent", payload, adminToken, "PERMISSION_DENIED");
  await expectCallableError("supervisorOnboardStudent", payload, teacherToken, "PERMISSION_DENIED");
  await expectCallableError("supervisorOnboardStudent", payload, parentToken, "PERMISSION_DENIED");
  await expectCallableError(
    "supervisorOnboardStudent",
    payload,
    otherSupervisorToken,
    "PERMISSION_DENIED",
  );
  assert.equal((await db.collection("users").where("name", "==", "طالب مشرف").get()).size, 0);
  assert.deepEqual((await db.doc("parentProfiles/r1sup_parent").get()).get("childrenIds"), []);
  assert.deepEqual((await db.doc("halaqat/r1sup_halaqa").get()).get("studentIds"), []);

  const ok = await call("supervisorOnboardStudent", payload, supervisorToken);
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  assert.equal(ok.body.result.status, "completed");
  const studentId = ok.body.result.studentId;
  assert.equal((await db.doc(`users/${studentId}`).get()).get("role"), "student");
  assert.deepEqual((await db.doc("parentProfiles/r1sup_parent").get()).get("childrenIds"), [studentId]);
  assert.deepEqual((await db.doc("halaqat/r1sup_halaqa").get()).get("studentIds"), [studentId]);
});

test.after(closeAdminApp);
