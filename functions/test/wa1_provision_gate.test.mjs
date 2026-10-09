/**
 * WA-0 / WA-1 production gate unit tests (no Firebase emulator required).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

test("B-BILLING gate denies production without env flags", () => {
  const keys = [
    "PRODUCTION_BACKEND_ENABLED",
    "FUNCTIONS_EMULATOR",
    "ALLOW_EMULATOR_BACKEND",
    "GCLOUD_PROJECT",
    "GOOGLE_CLOUD_PROJECT",
    "FIREBASE_CONFIG",
  ];
  const prev = Object.fromEntries(keys.map((k) => [k, process.env[k]]));
  for (const k of keys) delete process.env[k];

  const resolved = require.resolve("../lib/productionGate.js");
  delete require.cache[resolved];
  const gate = require("../lib/productionGate.js");

  assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));

  // ALLOW_EMULATOR_BACKEND must NOT open the gate (deploy accident risk).
  process.env.ALLOW_EMULATOR_BACKEND = "true";
  assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));

  // The Functions emulator flag alone does not open the local backend.
  process.env.FUNCTIONS_EMULATOR = "true";
  assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));

  // Emulator + real project stays closed.
  process.env.GCLOUD_PROJECT = "rafiq-academy";
  assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));

  // Only the Functions emulator flag with a demo-* project opens local backend.
  process.env.GCLOUD_PROJECT = "demo-rafiq-rules";
  assert.doesNotThrow(() => gate.assertBackendAllowed("adminProvisionUser"));

  for (const [k, v] of Object.entries(prev)) {
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
});

test("Paymob callables are not exported from functions index source contract", async () => {
  const { readFileSync } = await import("node:fs");
  const { join, dirname } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const root = join(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "src",
    "index.ts",
  );
  const src = readFileSync(root, "utf8");
  assert.match(src, /adminProvisionUser/);
  assert.doesNotMatch(src, /^export \{ createPaymentIntention/m);
  assert.doesNotMatch(src, /^export \{ paymobWebhook/m);
});
