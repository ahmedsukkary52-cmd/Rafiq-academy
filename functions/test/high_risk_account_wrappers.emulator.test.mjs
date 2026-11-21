/**
 * High-risk account wrapper authorization through the Functions Emulator.
 * Synthetic data only; no production backend and no scheduled execution.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("Account wrapper suite requires auth + firestore + functions and a demo- project id");
}

process.env.GCLOUD_PROJECT = PROJECT_ID;
const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

async function clearEmulators() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const response = await fetch(url, { method: "DELETE" });
    assert.equal(response.ok, true, `emulator clear failed: ${url}`);
  }
}

async function createToken(uid) {
  await admin.auth().createUser({ uid, email: `${uid}@example.test`, password: "secret123" });
  const response = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: `${uid}@example.test`, password: "secret123", returnSecureToken: true }),
    },
  );
  const body = await response.json();
  assert.ok(body.idToken, `sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function call(name, data, token) {
  const response = await fetch(
    `http://${FUNCTIONS}/${PROJECT_ID}/europe-west1/${name}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
  const text = await response.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: response.status, body };
}

let adminToken;
let parentToken;

test.beforeEach(async () => {
  await clearEmulators();
  adminToken = await createToken("admin1");
  parentToken = await createToken("parent1");
  const batch = db.batch();
  batch.set(db.doc("users/admin1"), { role: "admin", isActive: true });
  batch.set(db.doc("users/parent1"), { role: "parent", isActive: true, name: "Parent" });
  await batch.commit();
});

test("adminProvisionUser rejects unauthenticated/wrong-role and provisions only for Admin", async () => {
  const payload = {
    email: "parent-new@example.test",
    password: "secret123",
    name: "Parent New",
    role: "parent",
  };

  const anonymous = await call("adminProvisionUser", payload, null);
  assert.equal(anonymous.body.error?.status, "UNAUTHENTICATED");

  const wrongRole = await call("adminProvisionUser", payload, parentToken);
  assert.equal(wrongRole.body.error?.status, "PERMISSION_DENIED");
  await assert.rejects(admin.auth().getUserByEmail(payload.email), (error) => error.code === "auth/user-not-found");

  const allowed = await call("adminProvisionUser", payload, adminToken);
  assert.equal(allowed.status, 200, JSON.stringify(allowed.body));
  const uid = allowed.body.result.uid;
  assert.equal((await db.doc(`users/${uid}`).get()).data().role, "parent");
  assert.equal((await db.doc(`userPrivate/${uid}`).get()).data().email, payload.email);
});

test("adminProvisionUser refuses standalone student creation without relationships", async () => {
  const payload = { email: "orphan-student@example.test", password: "secret123", name: "Orphan", role: "student" };
  const denied = await call("adminProvisionUser", payload, adminToken);
  assert.equal(denied.body.error?.status, "FAILED_PRECONDITION");
  await assert.rejects(admin.auth().getUserByEmail(payload.email), (error) => error.code === "auth/user-not-found");
  assert.equal((await db.collection("users").where("role", "==", "student").get()).size, 0);
  assert.equal((await db.collection("studentProfiles").get()).size, 0);
});

test("adminSetMemberActive rejects unauthenticated/wrong-role and changes only the target for Admin", async () => {
  const anonymous = await call("adminSetMemberActive", { uid: "parent1", isActive: false }, null);
  assert.equal(anonymous.body.error?.status, "UNAUTHENTICATED");

  const wrongRole = await call("adminSetMemberActive", { uid: "parent1", isActive: false }, parentToken);
  assert.equal(wrongRole.body.error?.status, "PERMISSION_DENIED");
  assert.equal((await db.doc("users/parent1").get()).data().isActive, true);

  const allowed = await call("adminSetMemberActive", { uid: "parent1", isActive: false }, adminToken);
  assert.equal(allowed.status, 200, JSON.stringify(allowed.body));
  assert.equal((await db.doc("users/parent1").get()).data().isActive, false);
  // This callable revokes refresh tokens; Auth.disabled is managed by the
  // staff lifecycle path and is intentionally unchanged here.
  assert.equal((await admin.auth().getUser("parent1")).disabled, false);
});
