/**
 * Callable region contract (post-merge audit B-1).
 *
 * Reads the deploy manifest of the compiled exports (`__endpoint`, the same
 * metadata `firebase deploy` uses) and checks it against what the Flutter
 * client actually calls: every callable name in `lib/**` must be exported,
 * be a callable trigger, and be deployed in the client's region.
 *
 * Run after `npm --prefix functions run build`.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
const flutterLib = join(repoRoot, "lib");

process.env.GCLOUD_PROJECT ??= "demo-rafiq-rules";

function dartFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...dartFiles(full));
    else if (name.endsWith(".dart")) out.push(full);
  }
  return out;
}

function clientRegion() {
  const appFirebase = readFileSync(
    join(flutterLib, "core", "firebase", "app_firebase.dart"),
    "utf8",
  );
  const regionConst = appFirebase.match(
    /const\s+String\s+functionsRegion\s*=\s*'([^']+)'/,
  );
  assert.ok(regionConst, "functionsRegion must be declared in app_firebase.dart");
  const declaredRegion = regionConst[1];

  const di = readFileSync(join(flutterLib, "core", "di", "di_module.dart"), "utf8");
  // Accept either a string literal or the shared `functionsRegion` constant.
  const literalRegions = [...di.matchAll(/FirebaseFunctions\.instanceFor\(\s*region:\s*'([^']+)'/g)]
    .map((m) => m[1]);
  const constRegions = [...di.matchAll(/FirebaseFunctions\.instanceFor\([\s\S]*?region:\s*functionsRegion/g)]
    .map(() => declaredRegion);
  const regions = [...literalRegions, ...constRegions];
  assert.ok(regions.length >= 1, "exactly one FirebaseFunctions instance must be configured");
  assert.ok(
    regions.every((r) => r === declaredRegion),
    `DI regions must all be ${declaredRegion}, got ${JSON.stringify(regions)}`,
  );
  return declaredRegion;
}

function clientCallableNames() {
  const names = new Set();
  const patterns = [
    /httpsCallable\(\s*'([A-Za-z0-9_]+)'/g,
    /_call\(\s*'([A-Za-z0-9_]+)'/g,
    // Names held in constants, e.g. `const String kParentChildHalaqatCallable = '...'`
    // or `static const String submitCallable = '...'`, passed to httpsCallable.
    /const\s+String\s+\w*Callable\s*=\s*'([A-Za-z0-9_]+)'/g,
  ];
  for (const file of dartFiles(flutterLib)) {
    const src = readFileSync(file, "utf8");
    for (const re of patterns) for (const m of src.matchAll(re)) names.add(m[1]);
  }
  return [...names].sort();
}

let cachedEndpoints;
function deployedEndpoints() {
  if (cachedEndpoints) return cachedEndpoints;
  const exportsMap = require("../lib/index.js");
  cachedEndpoints = new Map();
  for (const [name, fn] of Object.entries(exportsMap)) {
    if (fn && typeof fn === "function" && fn.__endpoint) cachedEndpoints.set(name, fn.__endpoint);
  }
  return cachedEndpoints;
}

test("the client uses one FirebaseFunctions region and no default (us-central1) instance", () => {
  clientRegion();
  for (const file of dartFiles(flutterLib)) {
    const src = readFileSync(file, "utf8");
    assert.doesNotMatch(
      src,
      /FirebaseFunctions\.instance\b(?!For)/,
      `${file} must use the DI-provided regional FirebaseFunctions`,
    );
  }
});

test("every callable invoked by the client is exported, callable, and in the client region", () => {
  const region = clientRegion();
  const endpoints = deployedEndpoints();
  const names = clientCallableNames();
  assert.ok(names.length >= 15, `expected the full client callable set, got ${names.length}`);

  const problems = [];
  for (const name of names) {
    const endpoint = endpoints.get(name);
    if (!endpoint) {
      problems.push(`${name}: not exported from functions/src/index.ts`);
      continue;
    }
    if (!endpoint.callableTrigger) problems.push(`${name}: not an onCall trigger`);
    const regions = endpoint.region ?? [];
    if (regions.length !== 1 || regions[0] !== region) {
      problems.push(`${name}: deployed in [${regions.join(", ")}], client calls ${region}`);
    }
  }
  assert.deepEqual(problems, []);
});

test("callable names held in Dart constants are part of the checked client set", () => {
  const names = clientCallableNames();
  for (const name of [
    "getParentChildHalaqat",
    "getParentChildSchedule",
    "submitPaymentProof",
    "materializeSession",
  ]) {
    assert.ok(names.includes(name), `${name} missing from the client callable set`);
  }
});

test("admin billing callables (invoice + reinstatement) are reachable from the client region", () => {
  const region = clientRegion();
  const endpoints = deployedEndpoints();
  for (const name of ["adminGenerateInvoice", "adminReinstatePaymentAccess"]) {
    assert.deepEqual(endpoints.get(name)?.region, [region], name);
  }
});
