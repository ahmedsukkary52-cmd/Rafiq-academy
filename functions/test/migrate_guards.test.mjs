/**
 * Shared migration guards: project allowlist, project mismatch, dry-run
 * default and apply confirmation. CLI checks only use configurations that
 * are refused before firebase-admin is loaded, so nothing reaches Firebase.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  ALLOWED_PROJECTS,
  checkMigrationTarget,
  confirmationToken,
  credentialFileProjectId,
  parseMigrationArgs,
  safeErrorCode,
} from "../scripts/migrate-guards.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");

const check = (argv, env = {}, extra = {}) =>
  checkMigrationTarget({
    scriptId: "contact-field-cleanup",
    args: parseMigrationArgs(argv),
    env,
    credentialProjectId: null,
    needsAuth: false,
    ...extra,
  });

test("allowlist is exactly the .firebaserc projects plus the emulator demo project", () => {
  const rc = JSON.parse(readFileSync(join(functionsDir, "..", ".firebaserc"), "utf8"));
  assert.deepEqual([...ALLOWED_PROJECTS].sort(), [...Object.values(rc.projects), "demo-rafiq-rules"].sort());
});

test("dry run is the default; apply needs the exact script:project token", () => {
  assert.deepEqual(check(["--project", "rafiq-academy-staging"]), { problems: [], mode: "dry-run" });
  assert.equal(check(["--project=rafiq-academy-staging", "--dry-run"]).mode, "dry-run");

  const noToken = check(["--project", "rafiq-academy-staging", "--apply"]);
  assert.equal(noToken.mode, null);
  assert.match(noToken.problems.join(), /--confirm contact-field-cleanup:rafiq-academy-staging/);

  for (const wrong of [
    "contact-field-cleanup:rafiq-academy-prod",
    "email-backfill:rafiq-academy-staging",
    "yes",
  ]) {
    assert.equal(check(["--project", "rafiq-academy-staging", "--apply", "--confirm", wrong]).mode, null, wrong);
  }
  const ok = check([
    "--project", "rafiq-academy-staging", "--apply",
    "--confirm", confirmationToken("contact-field-cleanup", "rafiq-academy-staging"),
  ]);
  assert.deepEqual(ok, { problems: [], mode: "apply" });

  assert.equal(check(["--project", "rafiq-academy-staging", "--apply", "--dry-run",
    "--confirm", "contact-field-cleanup:rafiq-academy-staging"]).mode, null);
  assert.equal(check(["--project", "rafiq-academy-staging", "--confirm", "x"]).mode, null);
});

test("project must be given and allowlisted", () => {
  assert.match(check([]).problems.join(), /--project is required/);
  assert.match(check(["--project", "someone-elses-project"]).problems.join(), /not in the migration allowlist/);
  assert.match(check(["--project", "Bad Id!"]).problems.join(), /not a valid project id/);
});

test("project mismatch with env, FIREBASE_CONFIG or credentials is refused", () => {
  const p = ["--project", "rafiq-academy-staging"];
  for (const key of ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT", "GCP_PROJECT", "CLOUDSDK_CORE_PROJECT"]) {
    assert.match(check(p, { [key]: "rafiq-academy-prod" }).problems.join(), new RegExp(key));
    assert.equal(check(p, { [key]: "rafiq-academy-staging" }).mode, "dry-run");
  }
  assert.match(check(p, { FIREBASE_CONFIG: '{"projectId":"rafiq-academy"}' }).problems.join(), /FIREBASE_CONFIG/);
  assert.match(check(p, { FIREBASE_CONFIG: "not json" }).problems.join(), /FIREBASE_CONFIG/);
  assert.match(
    check(p, {}, { credentialProjectId: "rafiq-academy-prod" }).problems.join(),
    /GOOGLE_APPLICATION_CREDENTIALS/,
  );
  assert.equal(check(p, {}, { credentialProjectId: "rafiq-academy-staging" }).mode, "dry-run");
});

test("credential file: only project_id is read; unreadable files are refused without echoing", () => {
  const fake = { "/k.json": JSON.stringify({ project_id: "rafiq-academy", private_key: "SECRET" }) };
  const read = (path) => {
    if (!(path in fake)) throw new Error("ENOENT SECRET-PATH");
    return fake[path];
  };
  assert.deepEqual(credentialFileProjectId({}, read), { projectId: null, problem: null });
  assert.deepEqual(credentialFileProjectId({ GOOGLE_APPLICATION_CREDENTIALS: "/k.json" }, read),
    { projectId: "rafiq-academy", problem: null });
  const bad = credentialFileProjectId({ GOOGLE_APPLICATION_CREDENTIALS: "/missing.json" }, read);
  assert.equal(bad.projectId, null);
  assert.doesNotMatch(bad.problem, /SECRET/);
});

test("emulator and real projects are never mixed", () => {
  assert.match(
    check(["--project", "rafiq-academy"], { FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }).problems.join(),
    /FIRESTORE_EMULATOR_HOST is set while targeting a real project/,
  );
  assert.match(check(["--project", "demo-rafiq-rules"]).problems.join(), /emulator-only/);
  assert.match(
    check(["--project", "demo-rafiq-rules"], { FIRESTORE_EMULATOR_HOST: "10.0.0.5:8080" }).problems.join(),
    /emulator-only/,
  );
  assert.equal(check(["--project", "demo-rafiq-rules"], { FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }).mode, "dry-run");
  // The backfill also needs the Auth emulator for a demo project.
  assert.match(
    check(["--project", "demo-rafiq-rules"], { FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }, { needsAuth: true })
      .problems.join(),
    /FIREBASE_AUTH_EMULATOR_HOST/,
  );
});

test("unknown arguments are refused without echoing their values", () => {
  const { problems } = check(["--project", "rafiq-academy", "synthetic@example.test", "--x=01011112222", "--Weird!"]);
  const text = problems.join(" ");
  assert.equal(problems.length, 3);
  assert.doesNotMatch(text, /@|01011112222|Weird/);
  assert.match(check(["--project"]).problems.join(), /--project needs a value/);
});

test("safeErrorCode never returns an error message", () => {
  assert.equal(safeErrorCode({ code: 9, message: "doc has phone 0101" }), "failed-precondition");
  assert.equal(safeErrorCode({ code: "permission-denied" }), "permission-denied");
  assert.equal(safeErrorCode({ code: "has spaces 0101" }), "unknown");
  assert.equal(safeErrorCode(new Error("synthetic@example.test")), "unknown");
});

const cleanEnv = () => {
  const env = {};
  for (const key of ["PATH", "Path", "SystemRoot", "TEMP", "TMP"]) {
    if (process.env[key] !== undefined) env[key] = process.env[key];
  }
  return env;
};

for (const script of ["migrate-contact-fields.mjs", "migrate-email-backfill.mjs"]) {
  test(`${script} CLI refuses unsafe invocations before loading firebase-admin`, () => {
    const cases = [
      [],
      ["--project", "someone-elses-project"],
      ["--project", "rafiq-academy-staging", "--apply"],
      ["--project", "rafiq-academy-staging", "--apply", "--confirm", "wrong-token"],
    ];
    for (const argv of cases) {
      const r = spawnSync(process.execPath, [join(functionsDir, "scripts", script), ...argv], {
        env: { ...cleanEnv(), GOOGLE_CLOUD_PROJECT: "rafiq-academy-prod" },
        encoding: "utf8",
        timeout: 20000,
      });
      assert.equal(r.status, 2, `${argv.join(" ")} -> ${r.stderr}`);
      assert.match(r.stderr, /refused:/);
      assert.equal(r.stdout, "");
    }
  });
}
