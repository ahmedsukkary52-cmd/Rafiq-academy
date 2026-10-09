/**
 * Deploy targeting contract: every Firebase CLI command in the repo names an
 * explicit project, .firebaserc has no implicit default, and deploys go
 * through the fixed-argument wrapper (see deploy_functions_wrapper.test.mjs).
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const repoRoot = join(functionsDir, "..");

const firebaserc = JSON.parse(readFileSync(join(repoRoot, ".firebaserc"), "utf8"));
const pkg = JSON.parse(readFileSync(join(functionsDir, "package.json"), "utf8"));

test(".firebaserc maps dev/staging/prod and has no default alias", () => {
  assert.deepEqual(firebaserc.projects, {
    dev: "rafiq-academy",
    staging: "rafiq-academy-staging",
    prod: "rafiq-academy-prod",
  });
  assert.equal("default" in firebaserc.projects, false);
});

test("every firebase CLI script passes an explicit --project", () => {
  const firebaseScripts = Object.entries(pkg.scripts).filter(([, cmd]) =>
    /\bfirebase\s/.test(cmd),
  );
  assert.ok(firebaseScripts.length > 0);
  for (const [name, cmd] of firebaseScripts) {
    for (const segment of cmd.split("&&")) {
      if (!/\bfirebase\s/.test(segment)) continue;
      assert.match(segment, /--project\s+\S+/, `${name}: ${segment.trim()}`);
    }
  }
});

test("there is no generic deploy script", () => {
  assert.equal(pkg.scripts.deploy, undefined);
  assert.equal(pkg.scripts.logs, undefined);
});

test("deploy scripts call only the fixed-argument wrapper with their own target", () => {
  assert.equal(pkg.scripts["deploy:dev"], "node scripts/deploy-functions.mjs dev");
  assert.equal(pkg.scripts["deploy:staging"], "node scripts/deploy-functions.mjs staging");
  assert.equal(pkg.scripts["deploy:prod"], "node scripts/deploy-functions.mjs prod");
});

test("no npm script invokes firebase deploy outside the wrapper", () => {
  for (const [name, cmd] of Object.entries(pkg.scripts)) {
    assert.doesNotMatch(cmd, /\bfirebase\s+deploy\b/, name);
  }
});

test("serve calls only the fixed-argument emulator wrapper", () => {
  assert.equal(pkg.scripts.serve, "node scripts/serve-emulators.mjs");
});

test("no npm script starts the emulators outside the wrapper", () => {
  for (const [name, cmd] of Object.entries(pkg.scripts)) {
    assert.doesNotMatch(cmd, /\bemulators:(start|exec)\b/, name);
    if (name !== "serve") {
      assert.doesNotMatch(cmd, /serve-emulators\.mjs/, name);
    }
  }
});
