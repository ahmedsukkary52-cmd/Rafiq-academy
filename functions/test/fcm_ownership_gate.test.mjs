// H2 ownership gate vs push gate: FCM_OWNERSHIP_ENABLED lets ownership
// reconciliation run while every push stays blocked. Compiled modules and
// sources only; no network, no emulator.
import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const srcDir = join(here, "..", "src");

const ownershipGate = require("../lib/notifications/ownershipGate.js");
const pushGate = require("../lib/notifications/pushGate.js");
const productionGate = require("../lib/productionGate.js");
const ownership = require("../lib/notifications/fcmTokenOwnership.js");

const KEYS = ["FCM_OWNERSHIP_ENABLED", "PRODUCTION_BACKEND_ENABLED", "FUNCTIONS_EMULATOR"];

function withEnv(values, fn) {
  const saved = Object.fromEntries(KEYS.map((k) => [k, process.env[k]]));
  try {
    for (const k of KEYS) delete process.env[k];
    for (const [k, v] of Object.entries(values)) if (v !== undefined) process.env[k] = v;
    return fn();
  } finally {
    for (const k of KEYS) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

test("the ownership gate opens only on FCM_OWNERSHIP_ENABLED exactly \"true\"", () => {
  assert.equal(ownershipGate.OWNERSHIP_GATE_ENV, "FCM_OWNERSHIP_ENABLED");
  for (const value of [undefined, "", "TRUE", "True", "1", "yes", " true", "true ", "false"]) {
    withEnv({ FCM_OWNERSHIP_ENABLED: value }, () => {
      assert.equal(ownershipGate.isOwnershipReconcileEnabled(), false, JSON.stringify(value));
    });
  }
  withEnv({ FCM_OWNERSHIP_ENABLED: "true" }, () => {
    assert.equal(ownershipGate.isOwnershipReconcileEnabled(), true);
  });
});

test("opening the ownership gate never opens push or the shared backend gate", () => {
  for (const value of [undefined, "true", "TRUE", "1"]) {
    withEnv({ FCM_OWNERSHIP_ENABLED: value }, () => {
      assert.equal(productionGate.isProductionBackendEnabled(), false);
      assert.equal(pushGate.resolvePushSendMode(), "blocked", JSON.stringify(value));
      assert.equal(pushGate.isPushSendAllowed(pushGate.resolvePushSendMode()), false);
    });
  }
});

test("the ownership gate is never narrower than the shared gate", () => {
  withEnv({ PRODUCTION_BACKEND_ENABLED: "true" }, () => {
    assert.equal(ownershipGate.isOwnershipReconcileEnabled(), true);
    assert.equal(pushGate.resolvePushSendMode(), "production");
  });
});

test("the trigger body reconciles only through the ownership gate", async () => {
  let calls = 0;
  const reconcile = async () => {
    calls += 1;
    return "claimed";
  };
  const closed = await withEnv({}, () =>
    ownership.runOwnershipTrigger({ gateOpen: ownershipGate.isOwnershipReconcileEnabled(), eventTime: undefined, reconcile }));
  assert.equal(closed, "gate_closed");
  assert.equal(calls, 0);
  const open = await withEnv({ FCM_OWNERSHIP_ENABLED: "true" }, () =>
    ownership.runOwnershipTrigger({ gateOpen: ownershipGate.isOwnershipReconcileEnabled(), eventTime: undefined, reconcile }));
  assert.equal(open, "claimed");
  assert.equal(calls, 1);
});

function walk(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const path = join(dir, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

test("only the ownership trigger reads the ownership gate, and it cannot send", () => {
  const sources = walk(srcDir).filter((p) => p.endsWith(".ts"));
  const readers = sources
    .filter((p) => !p.endsWith("ownershipGate.ts"))
    .filter((p) => /ownershipGate|isOwnershipReconcileEnabled|FCM_OWNERSHIP_ENABLED/.test(readFileSync(p, "utf8")))
    .map((p) => relative(srcDir, p).replace(/\\/g, "/"));
  assert.deepEqual(readers, ["notifications/fcmTokenOwnership.ts"]);

  for (const file of ["notifications/ownershipGate.ts", "notifications/fcmTokenOwnership.ts"]) {
    const source = readFileSync(join(srcDir, file), "utf8");
    assert.doesNotMatch(source, /messaging|sendEach|sendMulticast/, `${file} must not send`);
  }
  const trigger = readFileSync(join(srcDir, "notifications/fcmTokenOwnership.ts"), "utf8");
  assert.match(trigger.slice(trigger.indexOf("export const reconcileFcmTokenOwnership")),
    /gateOpen: isOwnershipReconcileEnabled\(\)/);
  const sender = readFileSync(join(srcDir, "notifications/evaluationNotificationFunctions.ts"), "utf8");
  assert.match(sender, /const mode = resolvePushSendMode\(\);\s*if \(mode === "blocked"\)/);
});
