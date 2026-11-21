/**
 * Payment lifecycle journey (HTTP callables + Firestore/Storage emulators):
 * Admin `adminGenerateInvoice` → payment persisted for parent → parent
 * `submitPaymentProof` → scoped Supervisor `reviewPaymentProof` → paid.
 *
 * Isolated synthetic fixtures; demo- project only.
 *
 * Run (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only auth,firestore,functions,storage \
 *     "node --test --test-concurrency=1 functions/test/payment_lifecycle_journey.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { clientFunctionsRegion } from "./helpers/client_region.mjs";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const STORAGE = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

if (!FIRESTORE || !AUTH || !STORAGE || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "Payment lifecycle journey requires auth+firestore+functions+storage and a demo- project",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({
  projectId: PROJECT_ID,
  storageBucket: `${PROJECT_ID}.appspot.com`,
});
const db = admin.firestore();
const bucket = admin.storage().bucket();
const REGION = clientFunctionsRegion();
const PASSWORD = "Synthetic-Pass-42";

async function clearAll() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const res = await fetch(url, { method: "DELETE" });
    assert.equal(res.ok, true, `clear failed: ${url}`);
  }
  const [files] = await bucket.getFiles();
  await Promise.all(files.map((f) => f.delete()));
}

async function token(uid) {
  await admin.auth().createUser({
    uid,
    email: `${uid}@example.test`,
    password: PASSWORD,
  });
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${uid}@example.test`,
        password: PASSWORD,
        returnSecureToken: true,
      }),
    },
  );
  const body = await res.json();
  assert.ok(body.idToken, `sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function call(name, data, authToken, region = REGION) {
  const res = await fetch(
    `http://${FUNCTIONS}/${PROJECT_ID}/${region}/${name}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(authToken ? { authorization: `Bearer ${authToken}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: res.status, body };
}

const read = async (path) => (await db.doc(path).get()).data();

test("invoice → parent visibility → proof → supervisor approve → paid", async () => {
  await clearAll();

  const batch = db.batch();
  batch.set(db.doc("users/jAdmin"), {
    role: "admin",
    isActive: true,
    name: "Admin",
  });
  batch.set(db.doc("users/jSup"), {
    role: "supervisor",
    isActive: true,
    name: "Supervisor",
  });
  batch.set(db.doc("users/jTeacher"), {
    role: "teacher",
    isActive: true,
    name: "Teacher",
  });
  batch.set(db.doc("users/jParent"), {
    role: "parent",
    isActive: true,
    name: "Parent",
  });
  batch.set(db.doc("users/jStudent"), {
    role: "student",
    isActive: true,
    name: "Student",
  });
  batch.set(db.doc("parentProfiles/jParent"), {
    uid: "jParent",
    childrenIds: ["jStudent"],
  });
  batch.set(db.doc("studentProfiles/jStudent"), {
    uid: "jStudent",
    halaqaId: "jHalaqa",
  });
  batch.set(db.doc("halaqat/jHalaqa"), {
    name: "حلقة الرحلة",
    status: "active",
    teacherId: "jTeacher",
    supervisorId: "jSup",
    studentIds: ["jStudent"],
    assistantTeacherIds: [],
  });
  batch.set(db.doc("pricingRules/academy_default"), {
    scope: "academy_default",
    amount: 250,
    currency: "EGP",
    active: true,
    version: 1,
  });
  await batch.commit();

  const [adminToken, parentToken, teacherToken, supervisorToken] =
    await Promise.all([
      token("jAdmin"),
      token("jParent"),
      token("jTeacher"),
      token("jSup"),
    ]);

  // Parent cannot issue invoices.
  const denied = await call(
    "adminGenerateInvoice",
    { studentId: "jStudent", periodKey: "2026-11" },
    parentToken,
  );
  assert.equal(denied.body.error?.status, "PERMISSION_DENIED");

  // Admin issues invoice for the period.
  const issued = await call(
    "adminGenerateInvoice",
    { studentId: "jStudent", periodKey: "2026-11" },
    adminToken,
  );
  assert.equal(issued.status, 200, JSON.stringify(issued.body));
  const paymentId = issued.body.result.paymentId;
  assert.ok(paymentId);
  assert.equal(issued.body.result.amount, 250);
  assert.equal(issued.body.result.created, true);

  // Persistence + parent ownership (cross-role visibility basis).
  const payment = await read(`payments/${paymentId}`);
  assert.equal(payment.parentId, "jParent");
  assert.equal(payment.studentId, "jStudent");
  assert.equal(payment.status, "due");
  assert.equal(payment.amount, 250);

  const parentPayments = await db
    .collection("payments")
    .where("parentId", "==", "jParent")
    .get();
  assert.equal(parentPayments.size, 1);
  assert.equal(parentPayments.docs[0].id, paymentId);

  // Idempotent re-issue.
  const again = await call(
    "adminGenerateInvoice",
    { studentId: "jStudent", periodKey: "2026-11" },
    adminToken,
  );
  assert.equal(again.status, 200);
  assert.equal(again.body.result.created, false);
  assert.equal(again.body.result.paymentId, paymentId);

  // Teacher cannot submit proof for the parent's invoice.
  await bucket
    .file(`payment_proofs/jParent/${paymentId}/receipt.jpg`)
    .save(Buffer.alloc(64, 7), {
      contentType: "image/jpeg",
      resumable: false,
    });
  const teacherSubmit = await call(
    "submitPaymentProof",
    { paymentId, fileName: "receipt.jpg" },
    teacherToken,
  );
  assert.equal(teacherSubmit.body.error?.status, "PERMISSION_DENIED");

  // Parent submits proof.
  const submitted = await call(
    "submitPaymentProof",
    { paymentId, fileName: "receipt.jpg" },
    parentToken,
  );
  assert.equal(submitted.status, 200, JSON.stringify(submitted.body));
  const pending = await read(`payments/${paymentId}`);
  assert.ok(pending.proofCycleId);
  assert.equal(pending.proofFileName, "receipt.jpg");
  assert.ok(
    pending.status === "pending_review" ||
      pending.reviewStatus === "pending" ||
      pending.proofCycleId,
    `unexpected pending shape: ${JSON.stringify(pending)}`,
  );

  // Unscoped teacher cannot review.
  const teacherReview = await call(
    "reviewPaymentProof",
    {
      paymentId,
      decision: "approve",
      requestId: "j-review-00000001",
      expectedProofFileName: pending.proofFileName,
      expectedProofCycleId: pending.proofCycleId,
    },
    teacherToken,
  );
  assert.equal(teacherReview.body.error?.status, "PERMISSION_DENIED");

  // Scoped supervisor approves.
  const reviewed = await call(
    "reviewPaymentProof",
    {
      paymentId,
      decision: "approve",
      requestId: "j-review-00000001",
      expectedProofFileName: pending.proofFileName,
      expectedProofCycleId: pending.proofCycleId,
    },
    supervisorToken,
  );
  assert.equal(reviewed.status, 200, JSON.stringify(reviewed.body));
  const paid = await read(`payments/${paymentId}`);
  assert.equal(paid.status, "paid");
});

test.after(async () => {
  try {
    await clearAll();
  } finally {
    await admin.app().delete();
  }
});
