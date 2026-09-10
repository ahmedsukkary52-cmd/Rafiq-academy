/**
 * WA-0 / WA-1 production gate unit tests (no Firebase emulator required).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

test("B-BILLING gate denies production without env flags", () => {
  const prev = {
    PRODUCTION_BACKEND_ENABLED: process.env.PRODUCTION_BACKEND_ENABLED,
    FUNCTIONS_EMULATOR: process.env.FUNCTIONS_EMULATOR,
    ALLOW_EMULATOR_BACKEND: process.env.ALLOW_EMULATOR_BACKEND,
  };
  delete process.env.PRODUCTION_BACKEND_ENABLED;
  delete process.env.FUNCTIONS_EMULATOR;
  delete process.env.ALLOW_EMULATOR_BACKEND;

  const resolved = require.resolve("../lib/productionGate.js");
  delete require.cache[resolved];
  const gate = require("../lib/productionGate.js");

  assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));

  // ALLOW_EMULATOR_BACKEND must NOT open the gate (deploy accident risk).
  process.env.ALLOW_EMULATOR_BACKEND = "true";
  assert.throws(() => gate.assertBackendAllowed("adminProvisionUser"));

  // Only the Functions emulator flag opens local backend.
  process.env.FUNCTIONS_EMULATOR = "true";
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
