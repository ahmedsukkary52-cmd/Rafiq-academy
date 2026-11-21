/**
 * R1-G — exported wrapper authorization for the remaining high-risk callables.
 * All callable invocations below use the HTTP Functions Emulator. Admin SDK is
 * used only to seed synthetic emulator fixtures and inspect resulting state.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const STORAGE = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";
if (!FIRESTORE || !AUTH || !STORAGE || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("sensitive wrapper suite requires auth, firestore, storage, functions and a demo project");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;
const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket();
const PASSWORD = "Synthetic-Pass-42";
const ids = ["r1admin", "r1supervisor", "r1supervisor2", "r1teacher", "r1teacher2", "r1assistant", "r1parent", "r1student", "r1student2"];

async function clearEmulators() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const response = await fetch(url, { method: "DELETE" });
    assert.equal(response.ok, true, `failed to clear ${url}`);
  }
  const [files] = await bucket.getFiles();
  await Promise.all(files.map((file) => file.delete()));
}

async function token(uid) {
  await admin.auth().createUser({ uid, email: `${uid}@example.test`, password: PASSWORD });
  const response = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: `${uid}@example.test`, password: PASSWORD, returnSecureToken: true }),
    },
  );
  const body = await response.json();
  assert.ok(body.idToken, `could not sign in ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function call(name, data, authToken) {
  const response = await fetch(`http://${FUNCTIONS}/${PROJECT_ID}/europe-west1/${name}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(authToken ? { authorization: `Bearer ${authToken}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = { raw: text }; }
  return { status: response.status, body };
}

async function expectError(name, data, authToken, status) {
  const result = await call(name, data, authToken);
  assert.equal(result.body.error?.status, status, `${name}: ${JSON.stringify(result.body)}`);
  return result;
}

const read = async (path) => (await db.doc(path).get()).data();
const user = (role, name = role) => ({ role, name, isActive: true });

let adminToken;
let supervisorToken;
let teacherToken;
let parentToken;

async function seed() {
  await clearEmulators();
  const roles = {
    r1admin: user("admin", "المدير"),
    r1supervisor: user("supervisor", "المشرف"),
    r1supervisor2: user("supervisor", "مشرف آخر"),
    r1teacher: user("teacher", "المعلم"),
    r1teacher2: user("teacher", "بديل"),
    r1assistant: user("assistant_teacher", "المساعد"),
    r1parent: user("parent", "ولي الأمر"),
    r1student: user("student", "الطالب"),
    r1student2: user("student", "طالب ثان"),
  };
  const batch = db.batch();
  for (const [uid, data] of Object.entries(roles)) batch.set(db.doc(`users/${uid}`), data);
  batch.set(db.doc("parentProfiles/r1parent"), { childrenIds: ["r1student", "r1student2"] });
  batch.set(db.doc("studentProfiles/r1student"), { uid: "r1student", halaqaId: "r1h1" });
  batch.set(db.doc("studentProfiles/r1student2"), { uid: "r1student2", halaqaId: "" });
  batch.set(db.doc("halaqat/r1h1"), {
    name: "حلقة أولى", status: "active", teacherId: "r1teacher", supervisorId: "r1supervisor",
    studentIds: ["r1student"], assistantTeacherIds: [], schedule: [],
  });
  batch.set(db.doc("halaqat/r1h2"), {
    name: "حلقة ثانية", status: "active", teacherId: "r1teacher2", supervisorId: "r1supervisor",
    studentIds: [], assistantTeacherIds: [], schedule: [],
  });
  batch.set(db.doc("halaqat/r1h3"), {
    name: "حلقة ثالثة", status: "active", teacherId: "r1teacher2", supervisorId: "r1supervisor2",
    studentIds: [], assistantTeacherIds: [], schedule: [],
  });
  batch.set(db.doc("payments/r1payment"), {
    parentId: "r1parent", studentId: "r1student", amount: 300, currency: "EGP", status: "due",
  });
  await batch.commit();
  [adminToken, supervisorToken, teacherToken, parentToken] = await Promise.all([
    token("r1admin"), token("r1supervisor"), token("r1teacher"), token("r1parent"),
  ]);
}

test.before(seed);
test.after(async () => { await clearEmulators(); await admin.app().delete(); });

test("Membership wrappers enforce scope and mutation boundaries", async () => {
  // Membership: anonymous, wrong role, wrong supervisor scope, then Admin success.
  const admission = { studentId: "r1student2", halaqaId: "r1h2" };
  await expectError("admitStudentToHalaqa", admission, null, "UNAUTHENTICATED");
  await expectError("admitStudentToHalaqa", admission, teacherToken, "PERMISSION_DENIED");
  await expectError("admitStudentToHalaqa", { studentId: "r1student2", halaqaId: "r1h3" }, supervisorToken, "PERMISSION_DENIED");
  assert.deepEqual((await read("halaqat/r1h2")).studentIds, []);
  assert.equal((await call("admitStudentToHalaqa", admission, adminToken)).status, 200);
  assert.deepEqual((await read("halaqat/r1h2")).studentIds, ["r1student2"]);

  const transfer = { studentId: "r1student", fromHalaqaId: "r1h1", toHalaqaId: "r1h2" };
  await expectError("adminTransferStudent", transfer, null, "UNAUTHENTICATED");
  await expectError("adminTransferStudent", transfer, parentToken, "PERMISSION_DENIED");
  await expectError("adminTransferStudent", { ...transfer, toHalaqaId: "r1h3" }, supervisorToken, "PERMISSION_DENIED");
  assert.deepEqual((await read("halaqat/r1h1")).studentIds, ["r1student"]);
  assert.equal((await call("adminTransferStudent", transfer, adminToken)).status, 200);
  assert.deepEqual((await read("halaqat/r1h1")).studentIds, []);
});

test("Staff and cover wrappers enforce Admin authority and preserve state on rejection", async () => {
  // Staff and cover: all are Admin-only; rejection leaves the halaqa unchanged.
  const assistant = { halaqaId: "r1h1", assistantId: "r1assistant", operation: "assign" };
  await expectError("adminSetHalaqaAssistant", assistant, null, "UNAUTHENTICATED");
  await expectError("adminSetHalaqaAssistant", assistant, supervisorToken, "PERMISSION_DENIED");
  assert.deepEqual((await read("halaqat/r1h1")).assistantTeacherIds, []);
  assert.equal((await call("adminSetHalaqaAssistant", assistant, adminToken)).status, 200);
  assert.deepEqual((await read("halaqat/r1h1")).assistantTeacherIds, ["r1assistant"]);

  const start = { halaqaId: "r1h1", coverTeacherId: "r1assistant", reason: "غياب" };
  await expectError("adminStartHalaqaCover", start, teacherToken, "PERMISSION_DENIED");
  assert.equal((await call("adminStartHalaqaCover", start, adminToken)).status, 200);
  const started = await read("halaqat/r1h1");
  assert.equal(started.coverTeacherId, "r1assistant");
  assert.ok(started.coverId);
  const endCover = { halaqaId: "r1h1", coverId: started.coverId };
  await expectError("adminEndHalaqaCover", endCover, null, "UNAUTHENTICATED");
  await expectError("adminEndHalaqaCover", endCover, supervisorToken, "PERMISSION_DENIED");
  await expectError("adminEndHalaqaCover", endCover, teacherToken, "PERMISSION_DENIED");
  assert.equal((await read("halaqat/r1h1")).coverId, started.coverId);
  assert.equal((await call("adminEndHalaqaCover", endCover, adminToken)).status, 200);
  assert.equal((await read("halaqat/r1h1")).coverId, "");

  const reassign = { halaqaId: "r1h1", role: "teacher", newStaffId: "r1teacher2" };
  await expectError("adminReassignHalaqaStaff", reassign, supervisorToken, "PERMISSION_DENIED");
  assert.equal((await call("adminReassignHalaqaStaff", reassign, adminToken)).status, 200);
  assert.equal((await read("halaqat/r1h1")).teacherId, "r1teacher2");

  await expectError("adminSetStaffStatus", { uid: "r1teacher2", action: "deactivate" }, teacherToken, "PERMISSION_DENIED");
  // The teacher is still assigned to h1; the rejection must not change status.
  assert.equal((await read("users/r1teacher2")).isActive, true);
});

test("Payment wrappers enforce parent ownership and supervisor review scope", async () => {
  // Payment wrappers: parent ownership and supervisor review scope are enforced.
  await expectError("submitPaymentProof", { paymentId: "r1payment", fileName: "receipt.jpg" }, null, "UNAUTHENTICATED");
  await expectError("submitPaymentProof", { paymentId: "r1payment", fileName: "receipt.jpg" }, teacherToken, "PERMISSION_DENIED");
  await bucket.file("payment_proofs/r1parent/r1payment/receipt.jpg").save(Buffer.alloc(64, 7), { contentType: "image/jpeg", resumable: false });
  const submitted = await call("submitPaymentProof", { paymentId: "r1payment", fileName: "receipt.jpg" }, parentToken);
  assert.equal(submitted.status, 200, JSON.stringify(submitted.body));
  const payment = await read("payments/r1payment");
  await expectError("reviewPaymentProof", {
    paymentId: "r1payment", decision: "approve", requestId: "r1-review-000001",
    expectedProofFileName: payment.proofFileName, expectedProofCycleId: payment.proofCycleId,
  }, teacherToken, "PERMISSION_DENIED");
  const reviewed = await call("reviewPaymentProof", {
    paymentId: "r1payment", decision: "approve", requestId: "r1-review-000001",
    expectedProofFileName: payment.proofFileName, expectedProofCycleId: payment.proofCycleId,
  }, supervisorToken);
  assert.equal(reviewed.status, 200, JSON.stringify(reviewed.body));
  assert.equal((await read("payments/r1payment")).status, "paid");
});

test("Chat group wrappers enforce Admin authority and membership mutation boundaries", async () => {
  // Dynamic groups: Admin-only wrapper, with persisted rejection invariants.
  const groupData = { requestId: "r1-group-0001", title: "مجموعة تشغيلية", description: "اختبار", memberIds: ["r1parent", "r1supervisor"] };
  await expectError("adminCreateChatGroup", groupData, null, "UNAUTHENTICATED");
  await expectError("adminCreateChatGroup", groupData, parentToken, "PERMISSION_DENIED");
  assert.equal((await db.doc("conversations/group_r1-group-0001").get()).exists, false);
  const created = await call("adminCreateChatGroup", groupData, adminToken);
  assert.equal(created.status, 200, JSON.stringify(created.body));
  const groupId = created.body.result.conversationId;
  await expectError("adminUpdateChatGroup", { conversationId: groupId, title: "مرفوض" }, teacherToken, "PERMISSION_DENIED");
  assert.equal((await read(`conversations/${groupId}`)).title, "مجموعة تشغيلية");
  assert.equal((await call("adminUpdateChatGroup", { conversationId: groupId, title: "مجموعة محدثة" }, adminToken)).status, 200);
  await expectError("adminSetChatGroupMembers", { conversationId: groupId, add: ["r1student"] }, parentToken, "PERMISSION_DENIED");
  assert.equal((await call("adminSetChatGroupMembers", { conversationId: groupId, remove: ["r1parent"] }, adminToken)).status, 200);
  assert.equal((await read(`conversations/${groupId}`)).participantIds.includes("r1parent"), false);
});
