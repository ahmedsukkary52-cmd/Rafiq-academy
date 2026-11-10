// Pre-deployment inventory of the shared backend gate: every function
// exported for deployment is gated, FCM is only reachable behind pushGate,
// and the gate opens only on the exact value "true". Source-level plus the
// compiled gate predicates; no network, no emulator.
import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const srcDir = join(functionsDir, "src");
const require = createRequire(import.meta.url);

const GATE_CALLS = [
  /assertBackendAllowed\("/,
  /resolvePushSendMode\(\)/,
  /resolveProjectionRunMode\(\)/,
  /!isProductionBackendEnabled\(\) && !isEmulatorBackendAllowed\(\)/,
  /gateOpen: isProductionBackendEnabled\(\) \|\| isEmulatorBackendAllowed\(\)/,
];

/** [name, module] for every live (not commented-out) export of src/index.ts. */
function deployedExports() {
  const index = readFileSync(join(srcDir, "index.ts"), "utf8")
    .split(/\r?\n/)
    .filter((line) => !line.trim().startsWith("//"))
    .join("\n");
  const out = [];
  for (const m of index.matchAll(/export\s*\{([^}]*)\}\s*from\s*"\.\/([^"]+)"/g)) {
    for (const name of m[1].split(",").map((s) => s.trim()).filter(Boolean)) out.push([name, m[2]]);
  }
  return out;
}

/** Source of `export const <name> = ...` up to the next top-level export. */
function definition(module, name) {
  const source = readFileSync(join(srcDir, `${module}.ts`), "utf8");
  const start = source.indexOf(`export const ${name} =`);
  assert.notEqual(start, -1, `${module}.ts defines ${name}`);
  const next = source.indexOf("\nexport ", start + 1);
  return source.slice(start, next === -1 ? undefined : next);
}

function walk(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const path = join(dir, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

test("every deployed function checks the shared backend gate", () => {
  const exports = deployedExports();
  assert.ok(exports.length >= 30, `found ${exports.length} exports`);
  const ungated = exports.filter(([name, module]) =>
    !GATE_CALLS.some((re) => re.test(definition(module, name))));
  assert.deepEqual(ungated, []);
});

test("the Paymob functions stay out of the deployment", () => {
  const names = deployedExports().map(([name]) => name);
  assert.ok(!names.includes("paymobWebhook"));
  assert.ok(!names.includes("createPaymentIntention"));
});

test("FCM is sent from exactly one place, behind pushGate and the ownership filter", () => {
  const senders = walk(srcDir)
    .filter((p) => p.endsWith(".ts"))
    .filter((p) => /messaging\(\)|getMessaging|firebase-admin\/messaging/.test(readFileSync(p, "utf8")))
    .map((p) => relative(srcDir, p).replace(/\\/g, "/"));
  assert.deepEqual(senders, ["notifications/evaluationNotificationFunctions.ts"]);

  const source = readFileSync(join(srcDir, "notifications", "evaluationNotificationFunctions.ts"), "utf8");
  const trigger = definition("notifications/evaluationNotificationFunctions", "notifyParentsOnEvaluation");
  assert.ok(
    trigger.indexOf('if (mode === "blocked")') < trigger.indexOf("handleRecitationRecordWrite("),
    "gate is checked before any read, write or send",
  );
  assert.match(trigger, /sender: sendPush/);
  // sendPush is only reachable through deliverToParent, after the owner filter.
  const deliver = source.slice(source.indexOf("async function deliverToParent"));
  assert.ok(deliver.indexOf("filterOwnedTokens(") < deliver.indexOf("await sender("));
  assert.ok(deliver.indexOf("selectSendableTokens(") < deliver.indexOf("await sender("));
});

test("the ownership trigger returns on a closed gate without throwing (no retry loop)", () => {
  const ownership = readFileSync(join(srcDir, "notifications", "fcmTokenOwnership.ts"), "utf8");
  const run = ownership.slice(ownership.indexOf("export async function runOwnershipTrigger"));
  assert.match(run, /if \(!params\.gateOpen\) \{[\s\S]*?return "gate_closed";/);
  assert.ok(run.indexOf("gate_closed") < run.indexOf("params.reconcile()"));
});

test("the gate opens only for PRODUCTION_BACKEND_ENABLED exactly \"true\"", () => {
  const gate = require("../lib/productionGate.js");
  const push = require("../lib/notifications/pushGate.js");
  const saved = { p: process.env.PRODUCTION_BACKEND_ENABLED, f: process.env.FUNCTIONS_EMULATOR };
  try {
    delete process.env.FUNCTIONS_EMULATOR;
    for (const value of [undefined, "", "TRUE", "True", "1", "yes", " true", "true ", "false"]) {
      if (value === undefined) delete process.env.PRODUCTION_BACKEND_ENABLED;
      else process.env.PRODUCTION_BACKEND_ENABLED = value;
      assert.equal(gate.isProductionBackendEnabled(), false, JSON.stringify(value));
      assert.equal(push.resolvePushSendMode(), "blocked", JSON.stringify(value));
    }
    process.env.PRODUCTION_BACKEND_ENABLED = "true";
    assert.equal(push.resolvePushSendMode(), "production");
  } finally {
    if (saved.p === undefined) delete process.env.PRODUCTION_BACKEND_ENABLED;
    else process.env.PRODUCTION_BACKEND_ENABLED = saved.p;
    if (saved.f === undefined) delete process.env.FUNCTIONS_EMULATOR;
    else process.env.FUNCTIONS_EMULATOR = saved.f;
  }
});

test("the backfill runner and its tests are excluded from a Functions upload", () => {
  const config = JSON.parse(readFileSync(join(functionsDir, "..", "firebase.json"), "utf8")).functions;
  const codebases = Array.isArray(config) ? config : [config];
  assert.equal(codebases.length, 1);
  assert.equal(codebases[0].source, "functions");
  const { ignore } = codebases[0];
  assert.ok(ignore.includes("migrate-*.mjs"), "scripts/migrate-fcm-token-ownership.mjs");
  assert.ok(ignore.includes("migrate_*.mjs"));
  assert.ok(ignore.includes("test"));
  assert.ok(ignore.includes("*.emulator.test.mjs"));
});
