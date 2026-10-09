/**
 * Behavior of scripts/deploy-functions.mjs. No real build, Firebase CLI, or
 * network: in-process runs use a recording fake runner and temporary
 * .firebaserc fixtures; end-to-end runs put fake `npm` / `firebase` shims
 * first (and alone) on PATH.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  FUNCTIONS_DIR,
  REPO_ROOT,
  runDeploy,
} from "../scripts/deploy-functions.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const wrapper = join(here, "..", "scripts", "deploy-functions.mjs");

const GOOD_PROJECTS = {
  dev: "rafiq-academy",
  staging: "rafiq-academy-staging",
  prod: "rafiq-academy-prod",
};
const CONFIRMED = { CONFIRM_PROD_DEPLOY: "rafiq-academy-prod" };

function withTempDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), "deploy-wrapper-"));
  try {
    return fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function writeRc(dir, contents) {
  const path = join(dir, ".firebaserc");
  writeFileSync(
    path,
    typeof contents === "string" ? contents : JSON.stringify(contents),
  );
  return path;
}

async function deployWith({ args, env = {}, rc = { projects: GOOD_PROJECTS }, exitCodes = {} }) {
  const dir = mkdtempSync(join(tmpdir(), "deploy-wrapper-"));
  try {
    const firebasercPath = rc === null ? join(dir, "missing.json") : writeRc(dir, rc);
    const steps = [];
    const errors = [];
    const code = await runDeploy({
      args,
      env,
      firebasercPath,
      runStep: async (step) => {
        steps.push(step);
        return exitCodes[step.label] ?? 0;
      },
      log: () => {},
      error: (line) => errors.push(line),
    });
    return { code, steps, errors };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// ── Valid targets ───────────────────────────────────────────────────────────

for (const target of ["dev", "staging", "prod"]) {
  test(`${target}: builds, then deploys functions only to the fixed alias`, async () => {
    const { code, steps } = await deployWith({
      args: [target],
      env: target === "prod" ? CONFIRMED : {},
    });
    assert.equal(code, 0);
    assert.deepEqual(
      steps.map(({ command, args, cwd }) => ({ command, args, cwd })),
      [
        { command: "npm", args: ["run", "build"], cwd: FUNCTIONS_DIR },
        {
          command: "firebase",
          args: ["deploy", "--only", "functions", "--project", target],
          cwd: REPO_ROOT,
        },
      ],
    );
  });
}

// ── Argument rejection ──────────────────────────────────────────────────────

test("missing or unknown targets are refused before any subprocess", async () => {
  for (const args of [[], [""], ["qa"], ["PROD"], ["production"], ["default"], ["--project=prod"]]) {
    const { code, steps } = await deployWith({ args, env: CONFIRMED });
    assert.equal(code, 64, JSON.stringify(args));
    assert.deepEqual(steps, [], JSON.stringify(args));
  }
});

test("forwarded Firebase CLI arguments are refused before build or deploy", async () => {
  const forwarded = [
    ["dev", "--project", "prod"],
    ["dev", "-P", "rafiq-academy-prod"],
    ["dev", "--only", "firestore"],
    ["dev", "--project=prod"],
    ["staging", "--project", "prod"],
    ["prod", "--project", "dev"],
    ["prod", "--only", "firestore,storage"],
    ["dev", "dev"],
  ];
  for (const args of forwarded) {
    const { code, steps } = await deployWith({ args, env: CONFIRMED });
    assert.equal(code, 64, JSON.stringify(args));
    assert.deepEqual(steps, [], JSON.stringify(args));
  }
});

// ── Production confirmation ─────────────────────────────────────────────────

test("prod requires the exact confirmation value", async () => {
  for (const value of [undefined, "", "yes", "rafiq-academy", " rafiq-academy-prod", "RAFIQ-ACADEMY-PROD"]) {
    const env = value === undefined ? {} : { CONFIRM_PROD_DEPLOY: value };
    const { code, steps } = await deployWith({ args: ["prod"], env });
    assert.equal(code, 64, JSON.stringify(value));
    assert.deepEqual(steps, [], JSON.stringify(value));
  }
});

test("dev and staging do not need the production confirmation", async () => {
  for (const target of ["dev", "staging"]) {
    const { code } = await deployWith({ args: [target], env: {} });
    assert.equal(code, 0, target);
  }
});

// ── .firebaserc mapping ─────────────────────────────────────────────────────

test("missing, malformed or inconsistent .firebaserc fails closed", async () => {
  const cases = {
    missing: null,
    malformed: "{ not json",
    noProjects: { targets: {} },
    projectsArray: { projects: ["rafiq-academy"] },
    devMissing: { projects: { staging: GOOD_PROJECTS.staging, prod: GOOD_PROJECTS.prod } },
    devWrong: { projects: { ...GOOD_PROJECTS, dev: "rafiq-academy-prod" } },
    stagingWrong: { projects: { ...GOOD_PROJECTS, staging: "rafiq-academy" } },
    prodWrong: { projects: { ...GOOD_PROJECTS, prod: "rafiq-academy" } },
    prodMissing: { projects: { dev: GOOD_PROJECTS.dev, staging: GOOD_PROJECTS.staging } },
  };
  for (const [name, rc] of Object.entries(cases)) {
    for (const target of ["dev", "staging", "prod"]) {
      const expectedToPass =
        (name === "devWrong" || name === "devMissing") ? target !== "dev"
        : name === "stagingWrong" ? target !== "staging"
        : false;
      const { code, steps } = await deployWith({ args: [target], env: CONFIRMED, rc });
      if (expectedToPass) {
        assert.equal(code, 0, `${name}/${target}`);
      } else {
        assert.equal(code, 64, `${name}/${target}`);
        assert.deepEqual(steps, [], `${name}/${target}`);
      }
    }
  }
});

// ── Subprocess failures ─────────────────────────────────────────────────────

test("a failed build stops before Firebase is invoked", async () => {
  const { code, steps } = await deployWith({ args: ["dev"], exitCodes: { build: 2 } });
  assert.equal(code, 2);
  assert.deepEqual(steps.map((s) => s.label), ["build"]);
});

test("a failed Firebase deploy propagates its exit code", async () => {
  const { code, steps } = await deployWith({ args: ["staging"], exitCodes: { deploy: 7 } });
  assert.equal(code, 7);
  assert.deepEqual(steps.map((s) => s.label), ["build", "deploy"]);
});

test("a runner that throws is reported as failure, not success", async () => {
  const dir = mkdtempSync(join(tmpdir(), "deploy-wrapper-"));
  try {
    const code = await runDeploy({
      args: ["dev"],
      env: {},
      firebasercPath: writeRc(dir, { projects: GOOD_PROJECTS }),
      runStep: async () => {
        throw new Error("spawn failed");
      },
      log: () => {},
      error: () => {},
    });
    assert.equal(code, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// ── End-to-end through the real entry point with fake npm / firebase ────────

function writeShims(dir) {
  for (const name of ["npm", "firebase"]) {
    const exitVar = `FAKE_${name.toUpperCase()}_EXIT`;
    if (process.platform === "win32") {
      writeFileSync(
        join(dir, `${name}.cmd`),
        `@echo off\r\necho ${name} %*>>"%FAKE_LOG%"\r\nexit /b %${exitVar}%\r\n`,
      );
    } else {
      const shim = join(dir, name);
      writeFileSync(
        shim,
        `#!/bin/sh\necho "${name} $*" >> "$FAKE_LOG"\nexit "\${${exitVar}:-0}"\n`,
      );
      chmodSync(shim, 0o755);
    }
  }
}

function runWrapperCli(dir, args, extraEnv = {}) {
  const base = Object.fromEntries(
    Object.entries(process.env).filter(
      ([k]) => !/^path$/i.test(k) && k !== "CONFIRM_PROD_DEPLOY",
    ),
  );
  const log = join(dir, "calls.log");
  const res = spawnSync(process.execPath, [wrapper, ...args], {
    cwd: dir,
    env: {
      ...base,
      PATH: dir,
      FAKE_LOG: log,
      FAKE_NPM_EXIT: "0",
      FAKE_FIREBASE_EXIT: "0",
      ...extraEnv,
    },
    encoding: "utf8",
  });
  const calls = existsSync(log)
    ? readFileSync(log, "utf8").split(/\r?\n/).map((l) => l.trim()).filter(Boolean)
    : [];
  return { status: res.status, calls, stderr: res.stderr };
}

test("CLI: forwarded arguments never reach npm or firebase", () => {
  withTempDir((dir) => {
    writeShims(dir);
    for (const args of [
      ["dev", "--project", "prod"],
      ["dev", "-P", "rafiq-academy-prod"],
      ["dev", "--only", "firestore"],
      ["dev", "--project=prod"],
      [],
    ]) {
      const { status, calls } = runWrapperCli(dir, args, CONFIRMED);
      assert.equal(status, 64, JSON.stringify(args));
      assert.deepEqual(calls, [], JSON.stringify(args));
    }
  });
});

test("CLI: prod without confirmation never reaches npm or firebase", () => {
  withTempDir((dir) => {
    writeShims(dir);
    const { status, calls } = runWrapperCli(dir, ["prod"]);
    assert.equal(status, 64);
    assert.deepEqual(calls, []);
  });
});

test("CLI: valid target runs the fixed build and deploy commands", () => {
  withTempDir((dir) => {
    writeShims(dir);
    const { status, calls, stderr } = runWrapperCli(dir, ["prod"], CONFIRMED);
    assert.equal(status, 0, stderr);
    assert.deepEqual(calls, [
      "npm run build",
      "firebase deploy --only functions --project prod",
    ]);
  });
});

test("CLI: build failure skips firebase; firebase failure is propagated", () => {
  withTempDir((dir) => {
    writeShims(dir);
    const buildFail = runWrapperCli(dir, ["dev"], { FAKE_NPM_EXIT: "3" });
    assert.equal(buildFail.status, 3);
    assert.deepEqual(buildFail.calls, ["npm run build"]);
  });
  withTempDir((dir) => {
    writeShims(dir);
    const deployFail = runWrapperCli(dir, ["dev"], { FAKE_FIREBASE_EXIT: "7" });
    assert.equal(deployFail.status, 7);
    assert.deepEqual(deployFail.calls, [
      "npm run build",
      "firebase deploy --only functions --project dev",
    ]);
  });
});
