/**
 * The Functions upload contains production code only: emulator seeders,
 * migration tooling (scripts, tests, emulator tests, fakes, preloads), the
 * whole test/ directory and the local deploy/emulator helpers are excluded.
 * Checked with the Firebase CLI's own file walker and with its real
 * prepareFunctionsUpload, which builds the deploy zip locally from the
 * firebase.json ignore list. Nothing is deployed and nothing connects to
 * Firebase.
 *
 * Written against firebase-tools 15.18.0 internals (lib/fsAsync.js
 * readdirRecursive and lib/deploy/functions/prepareFunctionsUpload.js). The
 * CLI checks skip when firebase-tools is not installed (set
 * FIREBASE_TOOLS_DIR to point at it) and fail with a clear message if a
 * different version no longer exposes these modules.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { builtinModules, createRequire } from "node:module";
import { basename, dirname, join, posix, relative, sep } from "node:path";
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
  return candidates.find((dir) => existsSync(join(dir, "package.json")));
}

const TESTED_CLI_VERSION = "15.18.0";

/** Loads a firebase-tools internal module, or fails naming the CLI version. */
function cliModule(t, dir, ...segments) {
  const version = JSON.parse(readFileSync(join(dir, "package.json"), "utf8")).version;
  if (version !== TESTED_CLI_VERSION) t.diagnostic(`firebase-tools ${version}; written against ${TESTED_CLI_VERSION}`);
  const file = join(dir, "lib", ...segments);
  assert.ok(existsSync(file), `firebase-tools ${version} has no lib/${segments.join("/")} (written against ${TESTED_CLI_VERSION})`);
  return createRequire(import.meta.url)(file);
}

/** Local-only helpers: run on a developer machine, never by the deployed runtime. */
const LOCAL_HELPERS = ["scripts/deploy-functions.mjs", "scripts/serve-emulators.mjs"];

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
  const { readdirRecursive } = cliModule(t, dir, "fsAsync.js");
  const files = await readdirRecursive({
    path: functionsDir,
    ignoreStrings: [...ignore, "firebase-debug.log", "firebase-debug.*.log", ".runtimeconfig.json"],
  });
  const uploaded = files.map((f) => relative(functionsDir, f.name).split(sep).join("/"));

  for (const file of seederFiles) {
    assert.ok(!uploaded.includes(`scripts/${file}`), `scripts/${file} would be uploaded`);
  }
  assert.ok(!uploaded.some((f) => /^seed-emulator.*\.mjs$/.test(basename(f))));
  for (const required of ["package.json", "src/index.ts"]) {
    assert.ok(uploaded.includes(required), `${required} must still be uploaded`);
  }
  for (const helper of LOCAL_HELPERS) assert.ok(!uploaded.includes(helper), `${helper} would be uploaded`);
  if (existsSync(join(functionsDir, "lib", "index.js"))) {
    assert.ok(uploaded.includes("lib/index.js"));
  }
  assert.ok(!uploaded.some((f) => f.startsWith("node_modules/")));
});

// ── migration tooling ──────────────────────────────────────────────────────
const MIGRATION_PATTERNS = ["migrate-*.mjs", "migrate_*.mjs", "migration-*.mjs", "migration_*.mjs",
  "meeting-link-migration-core.mjs", "*.emulator.test.mjs"];
const isMigrationTooling = (name) => /^(migrate|migration)[-_].*\.mjs$/.test(name) ||
  name === "meeting-link-migration-core.mjs" || name.endsWith(".emulator.test.mjs");
const listDir = (sub) => readdirSync(join(functionsDir, sub)).map((f) => `${sub}/${f}`);
const excludedTooling = [...listDir("scripts"), ...listDir("test")].filter((f) => isMigrationTooling(basename(f))).sort();

test("firebase.json ignores migration scripts, tests, emulator tests, fakes and preloads by basename", () => {
  assert.ok(ignore.includes("test"), "the whole test directory is excluded");
  for (const pattern of MIGRATION_PATTERNS) assert.ok(ignore.includes(pattern), pattern);
  // Basename-only patterns: the CLI matches them with matchBase, in any folder.
  for (const pattern of MIGRATION_PATTERNS) assert.ok(!pattern.includes("/"), pattern);
  for (const expected of [
    "scripts/migrate-audit-contact-data.mjs",
    "scripts/migrate-contact-fields.mjs",
    "scripts/migrate-email-backfill.mjs",
    "scripts/migrate-guards.mjs",
    "scripts/meeting-link-migration-core.mjs",
    "scripts/migrate-meeting-links.mjs",
    "test/migrate-egress-preload.mjs",
    "test/migrate-no-admin-preload.mjs",
    "test/migrate_audit_contact_data.emulator.test.mjs",
    "test/migrate_audit_contact_data.test.mjs",
    "test/migrate_contact_fields.test.mjs",
    "test/migrate_email_backfill.test.mjs",
    "test/migrate_guards.test.mjs",
    "test/migrate_scripts.emulator.test.mjs",
    "test/migration_fakes.mjs",
    "test/payment_proof_cycle.emulator.test.mjs",
  ]) {
    assert.ok(excludedTooling.includes(expected), `${expected} must be covered`);
  }
});

/** Entry names of a zip, read from its central directory. */
function zipEntryNames(buffer) {
  let eocd = buffer.length - 22;
  while (eocd >= 0 && buffer.readUInt32LE(eocd) !== 0x06054b50) eocd -= 1;
  assert.ok(eocd >= 0, "zip end-of-central-directory record");
  const count = buffer.readUInt16LE(eocd + 10);
  let offset = buffer.readUInt32LE(eocd + 16);
  const names = [];
  for (let i = 0; i < count; i += 1) {
    assert.equal(buffer.readUInt32LE(offset), 0x02014b50, "central directory entry");
    const nameLength = buffer.readUInt16LE(offset + 28);
    const extraLength = buffer.readUInt16LE(offset + 30);
    const commentLength = buffer.readUInt16LE(offset + 32);
    names.push(buffer.toString("utf8", offset + 46, offset + 46 + nameLength));
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return names;
}

test("the Firebase CLI's real Functions package excludes all migration tooling and keeps production files", async (t) => {
  const dir = firebaseToolsDir();
  if (!dir) {
    t.skip("firebase-tools not installed; set FIREBASE_TOOLS_DIR to run this check");
    return;
  }
  // The same call deploy/functions/prepare.js makes for gcfv1/gcfv2 (zip, no
  // runtime config). It only reads the source tree and writes a local temp zip.
  const { prepareFunctionsUpload } = cliModule(t, dir, "deploy", "functions", "prepareFunctionsUpload.js");
  assert.equal(typeof prepareFunctionsUpload, "function", "prepareFunctionsUpload export");
  const config = { ...firebaseJson.functions[0], ignore: [...ignore] };
  const { pathToSource } = await prepareFunctionsUpload(join(functionsDir, ".."), functionsDir, config, [], undefined,
    { exportType: "zip", executablePaths: [] });
  let packaged;
  try {
    packaged = zipEntryNames(readFileSync(pathToSource));
  } finally {
    rmSync(pathToSource, { force: true });
  }

  for (const file of excludedTooling) assert.ok(!packaged.includes(file), `${file} would be uploaded`);
  assert.deepEqual(packaged.filter((f) => isMigrationTooling(basename(f))), [], "no migration tooling anywhere in the package");
  assert.deepEqual(packaged.filter((f) => f.startsWith("test/") || /\.test\.m?js$/.test(f)), [], "no tests in the package");
  assert.ok(!packaged.includes("lib/admin/adminMigrateUserPhones.js"), "retired phone migration output");
  assert.ok(!packaged.some((f) => /^seed-emulator.*\.mjs$/.test(basename(f))), "no seeder files");
  assert.ok(!packaged.some((f) => f.startsWith("node_modules/")));
  for (const helper of LOCAL_HELPERS) assert.ok(!packaged.includes(helper), `${helper} would be uploaded`);
  assert.deepEqual(packaged.filter((f) => f.startsWith("scripts/")), [], "no local scripts in the package");
  assert.ok(ignore.includes("firestore-debug.log"), "firebase.json ignores the emulator debug log");
  assert.deepEqual(packaged.filter((f) => basename(f) === "firestore-debug.log"), [], "no emulator debug log in the package");

  for (const required of ["package.json", "package-lock.json", "tsconfig.json", "src/index.ts",
    "src/admin/adminMigrateHalaqaSlotIds.ts", "src/halaqa/slotIdMigration.ts", "src/emulatorProjectGuard.ts",
    "src/privacy/contactInfoPolicy.ts"]) {
    assert.ok(packaged.includes(required), `${required} must still be uploaded`);
  }
  // Every production TypeScript source and every compiled output is packaged.
  const walk = (sub) => readdirSync(join(functionsDir, sub), { withFileTypes: true })
    .flatMap((e) => (e.isDirectory() ? walk(`${sub}/${e.name}`) : [`${sub}/${e.name}`]));
  const sources = walk("src");
  assert.deepEqual(sources.filter((f) => !packaged.includes(f)), [], "production sources excluded");
  if (existsSync(join(functionsDir, "lib"))) {
    assert.deepEqual(walk("lib").filter((f) => !packaged.includes(f)), [], "compiled output excluded");
    const expected = sources.flatMap((f) => {
      const base = f.replace(/^src\//, "lib/").replace(/\.ts$/, ".js");
      return [base, `${base}.map`];
    });
    assert.deepEqual(packaged.filter((f) => f.startsWith("lib/")).sort(), expected.sort(),
      "lib/ holds exactly the output of the current sources (no stale files)");
  }

  // Every compiled module the runtime can load resolves inside the package
  // or to a declared dependency / Node built-in.
  const pkg = JSON.parse(readFileSync(join(functionsDir, "package.json"), "utf8"));
  assert.ok(packaged.includes(pkg.main), `${pkg.main} (package main)`);
  const deps = new Set(Object.keys(pkg.dependencies ?? {}));
  const unresolved = [];
  for (const file of packaged.filter((f) => f.startsWith("lib/") && f.endsWith(".js"))) {
    const code = readFileSync(join(functionsDir, file), "utf8");
    for (const [, spec] of code.matchAll(/require\("([^"]+)"\)/g)) {
      if (spec.startsWith(".")) {
        const target = posix.normalize(posix.join(posix.dirname(file), spec));
        if (![`${target}.js`, `${target}/index.js`, target].some((t) => packaged.includes(t))) unresolved.push(`${file} -> ${spec}`);
      } else {
        const name = spec.startsWith("@") ? spec.split("/").slice(0, 2).join("/") : spec.split("/")[0];
        if (!deps.has(name) && !builtinModules.includes(spec.replace(/^node:/, ""))) unresolved.push(`${file} -> ${spec}`);
      }
    }
  }
  assert.deepEqual(unresolved, [], "runtime imports that the package cannot satisfy");
});

// ── build output ───────────────────────────────────────────────────────────
test("build cleans lib/ before compiling, so deleted sources leave no stale output", () => {
  const pkg = JSON.parse(readFileSync(join(functionsDir, "package.json"), "utf8"));
  const tsconfig = JSON.parse(readFileSync(join(functionsDir, "tsconfig.json"), "utf8"));
  assert.equal(pkg.scripts.build, "npm run clean && tsc");
  assert.equal(pkg.scripts.clean, "node -e \"require('node:fs').rmSync('lib', { recursive: true, force: true })\"");
  // lib/ is pure compiler output: nothing handwritten can live there.
  assert.equal(tsconfig.compilerOptions.outDir, "lib");
  assert.equal(tsconfig.compilerOptions.rootDir, "src");
  assert.deepEqual(tsconfig.include, ["src"]);
  assert.equal(tsconfig.compilerOptions.allowJs, undefined);
  assert.equal(pkg.main, "lib/index.js");
  // The clean step needs no file that the upload excludes.
  assert.doesNotMatch(pkg.scripts.clean, /scripts\//);
});
