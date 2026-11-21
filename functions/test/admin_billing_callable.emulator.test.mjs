/**
 * Admin billing callables over HTTP through the Functions emulator, at the
 * exact URL shape the Flutter client uses (`/{project}/{clientRegion}/{name}`).
 * Covers invoice generation and payment-access reinstatement end to end:
 * Auth token -> deployed region -> role check -> Firestore + audit writes.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only auth,firestore,functions \
 *     "node --test --test-concurrency=1 functions/test/admin_billing_callable.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { clientFunctionsRegion } from "./helpers/client_region.mjs";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "Admin billing emulator suite requires the auth + firestore + functions emulators and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const CLIENT_REGION = clientFunctionsRegion();

async function clearFirestore() {
  const res = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "firestore clear failed");
}

async function clearAuth() {
  const res = await fetch(`http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: "DELETE",
  });
  assert.equal(res.ok, true, "auth clear failed");
}

async function idTokenFor(uid) {
  await admin.auth().createUser({ uid, email: `${uid}@example.test`, password: "secret123" });
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${uid}@example.test`,
        password: "secret123",
        returnSecureToken: true,
      }),
    },
  );
  const body = await res.json();
  assert.ok(body.idToken, `sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function callCallable(name, data, token, region = CLIENT_REGION) {
  const res = await fetch(`http://${FUNCTIONS}/${PROJECT_ID}/${region}/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const text = await res.text();
  let body = null;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: res.status, body };
}

async function auditCount(action) {
  return (await db.collection("auditLogs").where("action", "==", action).get()).size;
}

let adminToken;
let parentToken;

test.beforeEach(async () => {
  await clearFirestore();
  await clearAuth();
  adminToken = await idTokenFor("admin1");
  parentToken = await idTokenFor("parent1");
  const batch = db.batch();
  batch.set(db.doc("users/admin1"), { role: "admin", isActive: true, name: "Admin" });
  batch.set(db.doc("users/parent1"), { role: "parent", isActive: true, name: "Parent" });
  batch.set(db.doc("users/student1"), { role: "student", isActive: true, name: "Student" });
  batch.set(db.doc("parentProfiles/parent1"), { uid: "parent1", childrenIds: ["student1"] });
  batch.set(db.doc("studentProfiles/student1"), { uid: "student1" });
  batch.set(db.doc("pricingRules/default"), {
    scope: "academy_default",
    amount: 300,
    currency: "EGP",
    active: true,
    version: 1,
  });
  batch.set(db.doc("paymentAccess/parent1"), {
    parentId: "parent1",
    status: "suspended",
    reason: "overdue",
  });
  await batch.commit();
});

test("adminReinstatePaymentAccess works at the client region URL (Admin)", async () => {
  const res = await callCallable(
    "adminReinstatePaymentAccess",
    { parentId: "parent1", reason: "manual" },
    adminToken,
  );
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.deepEqual(res.body.result, { parentId: "parent1", status: "ok" });

  const access = (await db.doc("paymentAccess/parent1").get()).data();
  assert.equal(access.status, "ok");
  assert.equal(access.reinstatedBy, "admin1");
  assert.equal(await auditCount("payment_reinstate"), 1);

  const again = await callCallable("adminReinstatePaymentAccess", { parentId: "parent1" }, adminToken);
  assert.equal(again.status, 200);
  assert.equal(await auditCount("payment_reinstate"), 1, "already-ok reinstatement is a no-op");
});

test("adminGenerateInvoice works at the client region URL (Admin) and is idempotent", async () => {
  const res = await callCallable(
    "adminGenerateInvoice",
    { studentId: "student1", periodKey: "2026-10" },
    adminToken,
  );
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.result.paymentId, "inv_student1_2026-10");
  assert.equal(res.body.result.amount, 300);
  assert.equal(res.body.result.created, true);

  const payment = (await db.doc("payments/inv_student1_2026-10").get()).data();
  assert.equal(payment.parentId, "parent1");
  assert.equal(payment.status, "due");

  const again = await callCallable(
    "adminGenerateInvoice",
    { studentId: "student1", periodKey: "2026-10" },
    adminToken,
  );
  assert.equal(again.status, 200);
  assert.equal(again.body.result.created, false);
});

test("non-Admin and unauthenticated callers are rejected by the server", async () => {
  const parent = await callCallable("adminReinstatePaymentAccess", { parentId: "parent1" }, parentToken);
  assert.equal(parent.body.error?.status, "PERMISSION_DENIED");
  const anon = await callCallable("adminGenerateInvoice", { studentId: "student1" }, null);
  assert.equal(anon.body.error?.status, "UNAUTHENTICATED");
  assert.equal((await db.doc("paymentAccess/parent1").get()).data().status, "suspended");
  assert.equal((await db.doc("payments/inv_student1_2026-10").get()).exists, false);
});

test("a deactivated Admin profile is rejected even with a valid token", async () => {
  await db.doc("users/admin1").update({ isActive: false });
  const res = await callCallable("adminReinstatePaymentAccess", { parentId: "parent1" }, adminToken);
  assert.equal(res.body.error?.status, "PERMISSION_DENIED", JSON.stringify(res.body));
  assert.equal((await db.doc("paymentAccess/parent1").get()).data().status, "suspended");
});

test("the callables are not served from the old us-central1 region", async () => {
  if (CLIENT_REGION === "us-central1") return;
  for (const name of ["adminReinstatePaymentAccess", "adminGenerateInvoice"]) {
    const res = await callCallable(name, { parentId: "parent1" }, adminToken, "us-central1");
    assert.notEqual(res.status, 200, `${name} must not be reachable in us-central1`);
  }
});
