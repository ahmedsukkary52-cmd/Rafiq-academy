import assert from "node:assert/strict";
import test from "node:test";
import { admin, call, clearEmulatorData, closeAdminApp, createIdentity, db, expectCallableError } from "./helpers/http_callable_emulator.mjs";

const authTokenFor = async (uid, password) => {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const response = await fetch(`http://${host}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: `${uid}@example.test`, password, returnSecureToken: true }),
  });
  return response.json();
};

test("password recovery is Admin-only and first login changes only the authenticated member password", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("r1recovery_admin", "admin");
  const parentToken = await createIdentity("r1recovery_parent", "parent");
  const memberPassword = "Temporary-Pass-17";
  await admin.auth().createUser({ uid: "r1recovery_member", email: "r1recovery_member@example.test", password: memberPassword });
  await db.doc("users/r1recovery_member").set({ role: "teacher", name: "معلم", isActive: true, passwordChangeRequired: true });
  await db.doc("userPrivate/r1recovery_member").set({ email: "r1recovery_member@example.test", loginUsername: "teacher-test", mustChangePassword: true });
  const memberResponse = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "r1recovery_member@example.test", password: memberPassword, returnSecureToken: true }),
  });
  const memberToken = (await memberResponse.json()).idToken;
  assert.ok(memberToken);

  const resetData = { userId: "r1recovery_member" };
  await expectCallableError("adminResetMemberPassword", resetData, null, "UNAUTHENTICATED");
  await expectCallableError("adminResetMemberPassword", resetData, parentToken, "PERMISSION_DENIED");
  assert.equal((await authTokenFor("r1recovery_member", memberPassword)).idToken != null, true, "rejected reset must preserve the existing credential");
  const reset = await call("adminResetMemberPassword", resetData, adminToken);
  assert.equal(reset.status, 200, JSON.stringify(reset.body));
  assert.equal(reset.body.result.userId, "r1recovery_member");
  assert.equal((await authTokenFor("r1recovery_member", memberPassword)).idToken, undefined, "successful reset revokes the old password");
  assert.ok((await authTokenFor("r1recovery_member", reset.body.result.temporaryPassword)).idToken, "issued temporary credential must work");

  const newPassword = "Changed-Pass-93";
  await expectCallableError("completeFirstLogin", { newPassword }, null, "UNAUTHENTICATED");
  await expectCallableError("completeFirstLogin", { newPassword }, parentToken, "FAILED_PRECONDITION");
  assert.equal((await db.doc("userPrivate/r1recovery_member").get()).get("mustChangePassword"), true);
  const completed = await call("completeFirstLogin", { newPassword }, memberToken);
  assert.equal(completed.status, 200, JSON.stringify(completed.body));
  assert.equal((await db.doc("userPrivate/r1recovery_member").get()).get("mustChangePassword"), false);
  assert.equal((await db.doc("users/r1recovery_member").get()).get("passwordChangeRequired"), false);
  assert.ok((await authTokenFor("r1recovery_member", newPassword)).idToken);
  assert.equal((await authTokenFor("r1recovery_member", memberPassword)).idToken, undefined);
});

test.after(closeAdminApp);
