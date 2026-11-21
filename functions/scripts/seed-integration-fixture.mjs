#!/usr/bin/env node
/**
 * Minimal Admin-SDK seed for Flutter ↔ Emulator integration_test.
 *
 * Intended for a **fresh** Emulator Suite session (`firebase emulators:exec`
 * or a newly started `npm run serve`). Project must be `demo-rafiq-rules`.
 *
 * Reuses the canonical DEMO dataset writers — no Production credentials,
 * no Cloud writes, no Rules weakening.
 *
 * Usage (emulators already up, empty):
 *   node functions/scripts/seed-integration-fixture.mjs
 *
 * Or under emulators:exec (hosts injected by the CLI):
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only auth,firestore,functions,storage \
 *     "node functions/scripts/seed-integration-fixture.mjs"
 */
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

import {
  buildDemoDataset,
  DEMO_ACCOUNTS,
  writeDemoDataset,
} from "./seed-emulator-dataset.mjs";

const PROJECT = "demo-rafiq-rules";

function requireEmulatorHosts() {
  const required = [
    "FIRESTORE_EMULATOR_HOST",
    "FIREBASE_AUTH_EMULATOR_HOST",
    "FIREBASE_STORAGE_EMULATOR_HOST",
  ];
  const missing = required.filter((k) => !process.env[k]);
  // Functions host is optional for Auth/Firestore-only journeys but preferred.
  if (missing.length > 0) {
    console.error(
      `seed-integration-fixture refused: missing ${missing.join(", ")}. ` +
        "Start the Emulator Suite first (npm --prefix functions run serve) " +
        "or run under firebase emulators:exec.",
    );
    process.exit(64);
  }
  if ((process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT) &&
      (process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT) !== PROJECT) {
    console.error(
      `seed-integration-fixture refused: project must be ${PROJECT}.`,
    );
    process.exit(64);
  }
  process.env.GCLOUD_PROJECT = PROJECT;
  process.env.GOOGLE_CLOUD_PROJECT = PROJECT;
}

async function main() {
  requireEmulatorHosts();
  const app = initializeApp({ projectId: PROJECT }, "seed-integration-fixture");
  const auth = getAuth(app);
  const db = getFirestore(app);
  try {
    const existing = await auth.listUsers(1);
    if (existing.users.length > 0) {
      console.error(
        "seed-integration-fixture refused: Auth Emulator is not empty. " +
          "Use a fresh emulator session (restart serve / emulators:exec).",
      );
      process.exit(64);
    }
    const dataset = buildDemoDataset(DEMO_ACCOUNTS);
    await writeDemoDataset({
      dataset,
      auth,
      db,
      serverTimestamp: () => FieldValue.serverTimestamp(),
      log: (line) => console.log(line),
    });
    console.log(
      `seed-integration-fixture: wrote ${dataset.authUsers.length} Auth users ` +
        `and ${dataset.documents.length} Firestore docs for ${PROJECT}.`,
    );
  } finally {
    await deleteApp(app);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
