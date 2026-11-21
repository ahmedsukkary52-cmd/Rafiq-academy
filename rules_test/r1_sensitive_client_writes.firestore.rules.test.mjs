/**
 * R1-G — focused client-write proof for sensitive server-owned fields.
 * Uses rules-unit-testing client contexts; Admin is used only for fixture setup.
 * Protected Quran/Mushaf paths are intentionally excluded.
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, "..", "firestore.rules"), "utf8");
let testEnv;
const client = (uid) => testEnv.authenticatedContext(uid).firestore();

async function seed(entries) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [path, value] of Object.entries(entries)) await db.doc(path).set(value);
  });
}

async function readWithAdmin(path) {
  // Read through an authenticated client context so the no-mutation check does
  // not depend on the disabled-rules helper's return-value behavior.
  return (await client("admin1").doc(path).get()).data();
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({ projectId: "demo-rafiq-rules", firestore: { rules } });
});
test.after(async () => testEnv?.cleanup());
test.beforeEach(async () => {
  await testEnv.clearFirestore();
  const user = (role, extra = {}) => ({ name: role, role, isActive: true, ...extra });
  await seed({
    "users/admin1": user("admin"),
    "users/supervisor1": user("supervisor"),
    "users/teacher1": user("teacher"),
    "users/parent1": user("parent"),
    "users/parent2": user("parent"),
    "users/student1": user("student"),
    "parentProfiles/parent1": { childrenIds: ["student1"] },
    "halaqat/h1": {
      name: "حلقة", status: "active", teacherId: "teacher1", supervisorId: "supervisor1",
      studentIds: ["student1"], assistantTeacherIds: [], coverTeacherId: "", coverId: "",
    },
    "studentProfiles/student1": { uid: "student1", halaqaId: "h1" },
    "payments/pay1": { parentId: "parent1", studentId: "student1", amount: 300, status: "due", reviewStatus: "pending_review" },
    "conversations/group_sensitive": {
      kind: "custom_group", participantIds: ["admin1", "parent1"],
      participants: [{ uid: "admin1", role: "admin", name: "admin" }, { uid: "parent1", role: "parent", name: "parent" }],
      groupAdminIds: ["admin1"], unreadCounts: { admin1: 0, parent1: 0 },
    },
  });
});

test("client cannot mutate roster membership or staff/cover authority fields", async () => {
  const attempts = [
    () => client("admin1").doc("halaqat/h1").update({ studentIds: [] }),
    () => client("supervisor1").doc("halaqat/h1").update({ studentIds: [] }),
    () => client("teacher1").doc("halaqat/h1").update({ assistantTeacherIds: ["teacher1"] }),
    () => client("student1").doc("halaqat/h1").update({ coverTeacherId: "student1", coverId: "x" }),
  ];
  for (const attempt of attempts) await assertFails(attempt());
  const halaqa = await readWithAdmin("halaqat/h1");
  if (JSON.stringify(halaqa.studentIds) !== JSON.stringify(["student1"])) throw new Error("roster mutated after denied writes");
  if (halaqa.coverId !== "") throw new Error("cover mutated after denied write");
});

test("client profile ownership is bounded and account status remains server-owned", async () => {
  await assertSucceeds(client("parent1").doc("users/parent1").update({ name: "اسم جديد" }));
  await assertFails(client("parent1").doc("users/parent1").update({ isActive: false }));
  await assertFails(client("admin1").doc("users/parent1").update({ isActive: false }));
  await assertFails(client("student1").doc("studentProfiles/student1").update({ halaqaId: "h2" }));
  const parent = await readWithAdmin("users/parent1");
  const profile = await readWithAdmin("studentProfiles/student1");
  if (parent.isActive !== true) throw new Error("denied account-status write mutated the account");
  if (profile.halaqaId !== "h1") throw new Error("denied ownership write mutated the profile");
});

test("payment documents and payment access cannot be changed by clients", async () => {
  for (const uid of ["parent1", "supervisor1", "admin1"]) {
    await assertFails(client(uid).doc("payments/pay1").update({ status: "paid", paymentAccess: "granted" }));
  }
  const payment = await readWithAdmin("payments/pay1");
  if (payment.status !== "due" || payment.paymentAccess !== undefined) throw new Error("payment changed after denied client writes");
});

test("conversation membership and group authority fields are server-owned", async () => {
  await assertFails(client("admin1").doc("conversations/group_sensitive").update({ participantIds: ["admin1"] }));
  await assertFails(client("parent1").doc("conversations/group_sensitive").update({ groupAdminIds: ["parent1"] }));
  const group = await readWithAdmin("conversations/group_sensitive");
  if (JSON.stringify(group.participantIds) !== JSON.stringify(["admin1", "parent1"])) throw new Error("group membership mutated");
  if (JSON.stringify(group.groupAdminIds) !== JSON.stringify(["admin1"])) throw new Error("group authority mutated");
});
