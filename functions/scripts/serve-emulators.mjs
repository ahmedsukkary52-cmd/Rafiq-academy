// Fixed-argument local Emulator Suite for `npm run serve`.
//
//   npm run serve
//
// npm appends anything after `--` to the script, so this wrapper accepts no
// arguments at all. The project is always the demo project (the emulators
// never reach a real project) and the emulator set is fixed.
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { FUNCTIONS_DIR, REPO_ROOT, spawnStep } from "./deploy-functions.mjs";

export const EMULATOR_PROJECT_ID = "demo-rafiq-rules";
export const EMULATOR_SET = "auth,firestore,functions,storage";

export class ServeRefused extends Error {}

export function assertNoArgs(args) {
  if (args.length !== 0) {
    throw new ServeRefused(
      `npm run serve takes no arguments, got ${JSON.stringify(args)}. ` +
        `The emulators always run with --project ${EMULATOR_PROJECT_ID} ` +
        `--only ${EMULATOR_SET}.`,
    );
  }
}

export function serveSteps() {
  return [
    { label: "build", command: "npm", args: ["run", "build"], cwd: FUNCTIONS_DIR },
    {
      label: "emulators",
      command: "firebase",
      args: ["emulators:start", "--project", EMULATOR_PROJECT_ID, "--only", EMULATOR_SET],
      cwd: REPO_ROOT,
    },
  ];
}

export async function runServe({
  args,
  runStep = spawnStep,
  log = console.log,
  error = console.error,
}) {
  try {
    assertNoArgs(args);
  } catch (e) {
    if (!(e instanceof ServeRefused)) throw e;
    error(`Serve refused: ${e.message}`);
    return 64;
  }

  for (const step of serveSteps()) {
    log(`> ${step.command} ${step.args.join(" ")}`);
    let code;
    try {
      code = await runStep(step);
    } catch (e) {
      error(`${step.label} could not run: ${e.message}`);
      return 1;
    }
    if (code !== 0) {
      error(`${step.label} failed with exit code ${code}; stopping.`);
      return code;
    }
  }
  return 0;
}

function isEntryPoint() {
  if (!process.argv[1]) return false;
  const normalize = (p) => {
    const real = realpathSync(p);
    return process.platform === "win32" ? real.toLowerCase() : real;
  };
  return normalize(fileURLToPath(import.meta.url)) === normalize(process.argv[1]);
}

if (isEntryPoint()) {
  process.exitCode = await runServe({ args: process.argv.slice(2) });
}
