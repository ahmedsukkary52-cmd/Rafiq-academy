import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
export const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
export const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
export const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
export const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";
if (!FIRESTORE || !AUTH || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("HTTP callable tests require Auth/Firestore/Functions emulators and a demo project");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;
export const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID });
export const db = admin.firestore();
const password = "Synthetic-Pass-42";

export async function clearEmulatorData() {
  for (const url of [
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
  ]) {
    const response = await fetch(url, { method: "DELETE" });
    assert.equal(response.ok, true, `could not clear emulator fixture: ${url}`);
  }
}

export async function createIdentity(uid, role, extra = {}) {
  await admin.auth().createUser({ uid, email: `${uid}@example.test`, password });
  const response = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: `${uid}@example.test`, password, returnSecureToken: true }),
    },
  );
  const body = await response.json();
  assert.ok(body.idToken, `Auth Emulator sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  await db.doc(`users/${uid}`).set({ role, name: uid, isActive: true, ...extra });
  return body.idToken;
}

export async function call(name, data, token) {
  const response = await fetch(`http://${FUNCTIONS}/${PROJECT_ID}/europe-west1/${name}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = { raw: text }; }
  return { status: response.status, body };
}

export async function expectCallableError(name, data, token, status) {
  const result = await call(name, data, token);
  assert.equal(result.body.error?.status, status, `${name}: ${JSON.stringify(result.body)}`);
  return result;
}

export async function closeAdminApp() {
  const app = admin.app();
  if (app) await app.delete();
}
