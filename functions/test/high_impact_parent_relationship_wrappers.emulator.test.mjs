import assert from "node:assert/strict";
import test from "node:test";
import { call, clearEmulatorData, closeAdminApp, createIdentity, db, expectCallableError } from "./helpers/http_callable_emulator.mjs";

test("parent-child relationship wrappers reject non-Admin mutation and preserve relationships", async () => {
  await clearEmulatorData();
  const adminToken = await createIdentity("r1link_admin", "admin");
  const parentToken = await createIdentity("r1link_parent", "parent");
  await createIdentity("r1link_parent2", "parent");
  await createIdentity("r1link_student", "student");
  await createIdentity("r1link_student2", "student");
  await db.doc("parentProfiles/r1link_parent").set({ childrenIds: ["r1link_student"] });
  await db.doc("parentProfiles/r1link_parent2").set({ childrenIds: [] });
  await db.doc("studentProfiles/r1link_student").set({ uid: "r1link_student", lifecycle: "active" });
  await db.doc("studentProfiles/r1link_student2").set({ uid: "r1link_student2", lifecycle: "active" });

  const link = { parentId: "r1link_parent2", studentId: "r1link_student2", operation: "link" };
  await expectCallableError("adminLinkParentChild", link, null, "UNAUTHENTICATED");
  await expectCallableError("adminLinkParentChild", link, parentToken, "PERMISSION_DENIED");
  assert.deepEqual((await db.doc("parentProfiles/r1link_parent2").get()).get("childrenIds"), []);
  const linked = await call("adminLinkParentChild", link, adminToken);
  assert.equal(linked.status, 200, JSON.stringify(linked.body));
  assert.deepEqual((await db.doc("parentProfiles/r1link_parent2").get()).get("childrenIds"), ["r1link_student2"]);

  const replacement = { studentId: "r1link_student", fromParentId: "r1link_parent", toParentId: "r1link_parent2" };
  await expectCallableError("adminReplaceParentLink", replacement, null, "UNAUTHENTICATED");
  await expectCallableError("adminReplaceParentLink", replacement, parentToken, "PERMISSION_DENIED");
  assert.deepEqual((await db.doc("parentProfiles/r1link_parent").get()).get("childrenIds"), ["r1link_student"]);
  assert.deepEqual((await db.doc("parentProfiles/r1link_parent2").get()).get("childrenIds"), ["r1link_student2"]);
  const replaced = await call("adminReplaceParentLink", replacement, adminToken);
  assert.equal(replaced.status, 200, JSON.stringify(replaced.body));
  assert.deepEqual((await db.doc("parentProfiles/r1link_parent").get()).get("childrenIds"), []);
  assert.deepEqual((await db.doc("parentProfiles/r1link_parent2").get()).get("childrenIds").sort(), ["r1link_student", "r1link_student2"]);
});

test.after(closeAdminApp);
