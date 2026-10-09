/**
 * Behavior of scripts/serve-emulators.mjs. No real build, Firebase CLI,
 * emulator, or network: in-process runs use a recording fake runner;
 * end-to-end runs put fake `npm` / `firebase` shims first (and alone) on PATH.
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

import { FUNCTIONS_DIR, REPO_ROOT } from "../scripts/deploy-functions.mjs";
import { runServe } from "../scripts/serve-emulators.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const wrapper = join(here, "..", "scripts", "serve-emulators.mjs");

const EXPECTED_EMULATOR_ARGS = [
  "emulators:start",
  "--project",
  "demo-rafiq-rules",
  "--only",
  "auth,firestore,functions,storage",
];

async function serveWith({ args = [], exitCodes = {}, throwOn } = {}) {
  const steps = [];
  const errors = [];
  const code = await runServe({
    args,
    runStep: async (step) => {
      steps.push(step);
      if (throwOn === step.label) throw new Error("spawn failed");
      return exitCodes[step.label] ?? 0;
    },
    log: () => {},
    error: (line) => errors.push(line),
  });
  return { code, steps, errors };
}

// ── In-process ──────────────────────────────────────────────────────────────

test("no arguments: builds, then starts the fixed emulator set on the demo project", async () => {
  const { code, steps } = await serveWith();
  assert.equal(code, 0);
  assert.deepEqual(
    steps.map(({ command, args, cwd }) => ({ command, args, cwd })),
    [
      { command: "npm", args: ["run", "build"], cwd: FUNCTIONS_DIR },
      { command: "firebase", args: EXPECTED_EMULATOR_ARGS, cwd: REPO_ROOT },
    ],
  );
});

test("any caller argument is refused before any subprocess", async () => {
  for (const args of [
    ["--project", "rafiq-academy"],
    ["-P", "rafiq-academy-prod"],
    ["--project=rafiq-academy"],
    ["--only", "functions"],
    ["--import", "./data"],
    ["dev"],
    [""],
  ]) {
    const { code, steps } = await serveWith({ args });
    assert.equal(code, 64, JSON.stringify(args));
    assert.deepEqual(steps, [], JSON.stringify(args));
  }
});

test("a failed build never starts the emulators", async () => {
  const { code, steps } = await serveWith({ exitCodes: { build: 2 } });
  assert.equal(code, 2);
  assert.deepEqual(steps.map((s) => s.label), ["build"]);
});

test("an emulator failure propagates its exit code", async () => {
  const { code, steps } = await serveWith({ exitCodes: { emulators: 9 } });
  assert.equal(code, 9);
  assert.deepEqual(steps.map((s) => s.label), ["build", "emulators"]);
});

test("a runner that throws is reported as failure", async () => {
  assert.equal((await serveWith({ throwOn: "build" })).code, 1);
  const { code, steps } = await serveWith({ throwOn: "emulators" });
  assert.equal(code, 1);
  assert.deepEqual(steps.map((s) => s.label), ["build", "emulators"]);
});

// ── End-to-end through the real entry point with fake npm / firebase ────────

function withTempDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), "serve-wrapper-"));
  try {
    return fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

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
    Object.entries(process.env).filter(([k]) => !/^path$/i.test(k)),
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

test("CLI: caller arguments never reach npm or firebase", () => {
  withTempDir((dir) => {
    writeShims(dir);
    for (const args of [
      ["--project", "rafiq-academy"],
      ["-P", "rafiq-academy-prod"],
      ["--only", "functions"],
      ["--project=rafiq-academy"],
    ]) {
      const { status, calls } = runWrapperCli(dir, args);
      assert.equal(status, 64, JSON.stringify(args));
      assert.deepEqual(calls, [], JSON.stringify(args));
    }
  });
});

test("CLI: runs the fixed build and emulator commands", () => {
  withTempDir((dir) => {
    writeShims(dir);
    const { status, calls, stderr } = runWrapperCli(dir, []);
    assert.equal(status, 0, stderr);
    assert.deepEqual(calls, [
      "npm run build",
      `firebase ${EXPECTED_EMULATOR_ARGS.join(" ")}`,
    ]);
  });
});

test("CLI: build failure skips firebase; firebase failure is propagated", () => {
  withTempDir((dir) => {
    writeShims(dir);
    const buildFail = runWrapperCli(dir, [], { FAKE_NPM_EXIT: "3" });
    assert.equal(buildFail.status, 3);
    assert.deepEqual(buildFail.calls, ["npm run build"]);
  });
  withTempDir((dir) => {
    writeShims(dir);
    const emuFail = runWrapperCli(dir, [], { FAKE_FIREBASE_EXIT: "7" });
    assert.equal(emuFail.status, 7);
    assert.deepEqual(emuFail.calls, [
      "npm run build",
      `firebase ${EXPECTED_EMULATOR_ARGS.join(" ")}`,
    ]);
  });
});
