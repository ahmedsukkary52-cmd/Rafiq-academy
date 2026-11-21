/**
 * Safe WA-6 core verification. This calls runOverdueGracePass against the
 * Firestore Emulator only; it never invokes the scheduled trigger.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;

if (!FIRESTORE || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("Overdue pass suite requires Firestore Emulator and a demo- project id");
}

process.env.GCLOUD_PROJECT = PROJECT_ID;
const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const { Timestamp } = admin.firestore;
const { runOverdueGracePass } = require("../lib/billing/processOverdueGrace.js");

async function clearFirestore() {
  const response = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(response.ok, true, "emulator clear failed");
}

async function seed() {
  const batch = db.batch();
  batch.set(db.doc("academySettings/pricingDefaults"), { gracePeriodDays: 0 });
  batch.set(db.doc("parentProfiles/parent1"), { childrenIds: ["student1"] });
  batch.set(db.doc("payments/invoice1"), {
    parentId: "parent1",
    studentId: "student1",
    status: "due",
    dueDate: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
  });
  await batch.commit();
}

test.beforeEach(async () => {
  await clearFirestore();
  await seed();
});

test("overdue pass marks due invoices and is idempotent on retry", async () => {
  const now = new Date("2026-01-10T00:00:00Z");
  const first = await runOverdueGracePass(db, now);
  assert.equal(first.parentsProcessed, 1);
  assert.equal(first.paymentsMarkedOverdue, 1);
  assert.equal(first.accessUpserts, 1);

  const payment = (await db.doc("payments/invoice1").get()).data();
  assert.equal(payment.status, "overdue");
  const access = (await db.doc("paymentAccess/parent1").get()).data();
  assert.equal(access.status, "suspended");
  assert.deepEqual(access.affectedStudentIds, ["student1"]);

  const second = await runOverdueGracePass(db, now);
  assert.equal(second.parentsProcessed, 1);
  assert.equal(second.paymentsMarkedOverdue, 0);
  assert.equal(second.accessUpserts, 0);
});
