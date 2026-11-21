/**
 * D0 — Trial over-read isolation matrix against **repo** firestore.rules.
 *
 * Mirrors the Confirmed live-cloud gaps from Trial (BASMA-100) as emulator
 * expectations for the rules *in this repository*. Passing here does **not**
 * prove `rafiq-academy` is secure until those rules are deployed.
 *
 * Synthetic UIDs only. Project: demo-rafiq-rules (see project_id.mjs).
 *
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "npm --prefix rules_test run test:d0:isolation"
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PROJECT_ID } from "./project_id.mjs";
import test from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, "..", "firestore.rules"), "utf8");

let testEnv;
const db = (uid) => testEnv.authenticatedContext(uid).firestore();

async function seed(entries) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const firestore = ctx.firestore();
    for (const [path, value] of Object.entries(entries)) {
      await firestore.doc(path).set(value);
    }
  });
}

const user = (role, extra = {}) => ({
  name: role,
  role,
  isActive: true,
  ...extra,
});

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed({
    "users/admin1": user("admin"),
    "users/supervisor1": user("supervisor"),
    "users/teacher1": user("teacher"),
    "users/teacherOther": user("teacher"),
    "users/parent1": user("parent"),
    "users/parentOther": user("parent"),
    "users/student1": user("student"),
    "users/student2": user("student"),
    "users/studentOtherHalaqa": user("student"),
    "userPrivate/admin1": { email: "admin1@example.test", emailSource: "auth" },
    "userPrivate/parent1": { email: "parent1@example.test", emailSource: "auth" },
    "userPrivate/student1": { email: "student1@example.test", emailSource: "auth" },
    "parentProfiles/parent1": { childrenIds: ["student1"] },
    "parentProfiles/parentOther": { childrenIds: ["studentOtherHalaqa"] },
    "halaqat/h1": {
      name: "حلقة أ",
      status: "active",
      teacherId: "teacher1",
      supervisorId: "supervisor1",
      studentIds: ["student1", "student2"],
      assistantTeacherIds: [],
      coverTeacherId: "",
      coverId: "",
    },
    "halaqat/h2": {
      name: "حلقة ب",
      status: "active",
      teacherId: "teacherOther",
      supervisorId: "supervisor1",
      studentIds: ["studentOtherHalaqa"],
      assistantTeacherIds: [],
      coverTeacherId: "",
      coverId: "",
    },
    "studentProfiles/student1": { uid: "student1", halaqaId: "h1", coins: 0 },
    "studentProfiles/student2": { uid: "student2", halaqaId: "h1", coins: 0 },
    "studentProfiles/studentOtherHalaqa": {
      uid: "studentOtherHalaqa",
      halaqaId: "h2",
      coins: 0,
    },
    "payments/pay_s1": {
      parentId: "parent1",
      studentId: "student1",
      amount: 200,
      status: "due",
      reviewStatus: "none",
    },
    "payments/pay_other": {
      parentId: "parentOther",
      studentId: "studentOtherHalaqa",
      amount: 500,
      status: "due",
      reviewStatus: "none",
    },
    "pricingRules/default": { monthlyAmount: 200 },
    "academySettings/main": { note: "admin-private" },
    "academySettings/paymentPublic": {
      vodafoneCashDestination: "01000000000",
      instapayDestination: "pay@example.test",
    },
  });
});

// ── Student ───────────────────────────────────────────────────────────────

test("D0 student cannot list all users (directory scan)", async () => {
  await assertFails(db("student1").collection("users").get());
});

test("D0 student cannot list studentProfiles", async () => {
  await assertFails(db("student1").collection("studentProfiles").get());
});

test("D0 student cannot get another halaqa student profile", async () => {
  await assertFails(db("student1").doc("studentProfiles/studentOtherHalaqa").get());
});

test("D0 student may get roster-mate profile for display names", async () => {
  await assertSucceeds(db("student1").doc("studentProfiles/student2").get());
});

test("D0 student cannot read another family payment", async () => {
  await assertFails(db("student1").doc("payments/pay_other").get());
  await assertFails(db("student1").doc("payments/pay_s1").get());
});

test("D0 student cannot read admin userPrivate", async () => {
  await assertFails(db("student1").doc("userPrivate/admin1").get());
});

// ── Parent ────────────────────────────────────────────────────────────────

test("D0 parent cannot read admin userPrivate", async () => {
  await assertFails(db("parent1").doc("userPrivate/admin1").get());
});

test("D0 parent cannot read another parent profile graph", async () => {
  await assertFails(db("parent1").doc("parentProfiles/parentOther").get());
});

test("D0 parent can read own payment and not other family payment", async () => {
  await assertSucceeds(db("parent1").doc("payments/pay_s1").get());
  await assertFails(db("parent1").doc("payments/pay_other").get());
});

test("D0 parent can read paymentPublic settings only", async () => {
  await assertSucceeds(db("parent1").doc("academySettings/paymentPublic").get());
  await assertFails(db("parent1").doc("academySettings/main").get());
  await assertFails(db("parent1").doc("pricingRules/default").get());
});

// ── Teacher / Supervisor ──────────────────────────────────────────────────

test("D0 teacher cannot list studentProfiles (must get by id)", async () => {
  await assertFails(db("teacher1").collection("studentProfiles").get());
});

test("D0 teacher of h1 can get roster student, not foreign halaqa student", async () => {
  await assertSucceeds(db("teacher1").doc("studentProfiles/student1").get());
  await assertFails(db("teacher1").doc("studentProfiles/studentOtherHalaqa").get());
});

test("D0 teacher cannot write pricingRules or academySettings", async () => {
  await assertFails(db("teacher1").doc("pricingRules/default").set({ monthlyAmount: 1 }));
  await assertFails(
    db("teacher1").doc("academySettings/paymentPublic").set({
      vodafoneCashDestination: "01011111111",
    }),
  );
});

test("D0 teacher cannot update payment docs", async () => {
  await assertFails(db("teacher1").doc("payments/pay_s1").update({ status: "paid" }));
});

test("D0 supervisor can read supervised student payment, not write", async () => {
  await assertSucceeds(db("supervisor1").doc("payments/pay_s1").get());
  await assertFails(db("supervisor1").doc("payments/pay_s1").update({ status: "paid" }));
});

// ── Admin allow-list ──────────────────────────────────────────────────────

test("D0 admin can read/write pricingRules", async () => {
  await assertSucceeds(db("admin1").doc("pricingRules/default").get());
  await assertSucceeds(
    db("admin1").doc("pricingRules/default").set({ monthlyAmount: 250 }),
  );
});

test("D0 admin paymentPublic write is field-bounded", async () => {
  await assertSucceeds(
    db("admin1").doc("academySettings/paymentPublic").set({
      vodafoneCashDestination: "01022222222",
      instapayDestination: "x@example.test",
    }),
  );
  await assertFails(
    db("admin1").doc("academySettings/paymentPublic").set({
      vodafoneCashDestination: "01022222222",
      secretInternal: "leak",
    }),
  );
});

test("D0 admin may get userPrivate; nobody lists the collection", async () => {
  await assertSucceeds(db("admin1").doc("userPrivate/parent1").get());
  await assertFails(db("admin1").collection("userPrivate").get());
});
