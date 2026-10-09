/**
 * The emulator seeder files are excluded from the Functions upload, using the
 * Firebase CLI's own file walker (lib/fsAsync.js readdirRecursive) with the
 * ignore list from firebase.json, as prepareFunctionsUpload does. Nothing is
 * deployed or packaged.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { basename, dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const firebaseJson = JSON.parse(readFileSync(join(functionsDir, "..", "firebase.json"), "utf8"));
const ignore = firebaseJson.functions[0].ignore;

function firebaseToolsDir() {
  const candidates = [
    process.env.FIREBASE_TOOLS_DIR,
    process.env.APPDATA && join(process.env.APPDATA, "npm", "node_modules", "firebase-tools"),
    join(dirname(process.execPath), "node_modules", "firebase-tools"),
    join(dirname(process.execPath), "..", "lib", "node_modules", "firebase-tools"),
  ].filter(Boolean);
  return candidates.find((dir) => existsSync(join(dir, "lib", "fsAsync.js")));
}

const seederFiles = readdirSync(join(functionsDir, "scripts")).filter((f) => /^seed-emulator.*\.mjs$/.test(f));

test("firebase.json ignores the seeder files by basename", () => {
  assert.ok(ignore.includes("seed-emulator*.mjs"));
  assert.deepEqual(ignore.slice(0, 5), ["node_modules", ".git", "firebase-debug.log", "firebase-debug.*.log", "*.local"]);
  assert.ok(seederFiles.length >= 5, seederFiles.join(","));
});

test("Firebase CLI upload walker excludes the seeder and keeps deploy files", async (t) => {
  const dir = firebaseToolsDir();
  if (!dir) {
    t.skip("firebase-tools not installed; set FIREBASE_TOOLS_DIR to run this check");
    return;
  }
  const { readdirRecursive } = createRequire(import.meta.url)(join(dir, "lib", "fsAsync.js"));
  const files = await readdirRecursive({
    path: functionsDir,
    ignoreStrings: [...ignore, "firebase-debug.log", "firebase-debug.*.log", ".runtimeconfig.json"],
  });
  const uploaded = files.map((f) => relative(functionsDir, f.name).split(sep).join("/"));

  for (const file of seederFiles) {
    assert.ok(!uploaded.includes(`scripts/${file}`), `scripts/${file} would be uploaded`);
  }
  assert.ok(!uploaded.some((f) => /^seed-emulator.*\.mjs$/.test(basename(f))));
  for (const required of ["package.json", "src/index.ts", "scripts/deploy-functions.mjs", "scripts/serve-emulators.mjs"]) {
    assert.ok(uploaded.includes(required), `${required} must still be uploaded`);
  }
  if (existsSync(join(functionsDir, "lib", "index.js"))) {
    assert.ok(uploaded.includes("lib/index.js"));
  }
  assert.ok(!uploaded.some((f) => f.startsWith("node_modules/")));
});
