// Fixed-argument Functions deploy for `npm run deploy:<target>`.
//
//   npm run deploy:dev
//   npm run deploy:staging
//   CONFIRM_PROD_DEPLOY=rafiq-academy-prod npm run deploy:prod
//
// npm appends anything after `--` to the script, so this wrapper accepts
// exactly one positional target and refuses everything else. The project
// alias and the deploy scope are never taken from the caller.
import { spawn } from "node:child_process";
import { readFileSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const EXPECTED_PROJECTS = Object.freeze({
  dev: "rafiq-academy",
  staging: "rafiq-academy-staging",
  prod: "rafiq-academy-prod",
});
export const PROD_CONFIRMATION = EXPECTED_PROJECTS.prod;

const here = dirname(fileURLToPath(import.meta.url));
export const FUNCTIONS_DIR = resolve(here, "..");
export const REPO_ROOT = resolve(FUNCTIONS_DIR, "..");
export const FIREBASERC_PATH = join(REPO_ROOT, ".firebaserc");

export class DeployRefused extends Error {}

const SAFE_ARG = /^[A-Za-z0-9:._-]+$/;

export function parseTarget(args) {
  if (args.length !== 1) {
    throw new DeployRefused(
      `Expected exactly one target (${Object.keys(EXPECTED_PROJECTS).join(" | ")}), ` +
        `got ${args.length} argument(s): ${JSON.stringify(args)}. ` +
        "Extra arguments are never forwarded to the Firebase CLI.",
    );
  }
  const [target] = args;
  if (!Object.hasOwn(EXPECTED_PROJECTS, target)) {
    throw new DeployRefused(
      `Unknown deploy target ${JSON.stringify(target)}. ` +
        `Allowed: ${Object.keys(EXPECTED_PROJECTS).join(" | ")}.`,
    );
  }
  return target;
}

export function assertAliasMapping(target, firebasercPath) {
  let raw;
  try {
    raw = readFileSync(firebasercPath, "utf8");
  } catch (e) {
    throw new DeployRefused(`Cannot read ${firebasercPath}: ${e.message}`);
  }
  let rc;
  try {
    rc = JSON.parse(raw);
  } catch (e) {
    throw new DeployRefused(`${firebasercPath} is not valid JSON: ${e.message}`);
  }
  const projects = rc?.projects;
  if (projects === null || typeof projects !== "object" || Array.isArray(projects)) {
    throw new DeployRefused(`${firebasercPath} has no "projects" map.`);
  }
  const expected = EXPECTED_PROJECTS[target];
  const actual = projects[target];
  if (actual !== expected) {
    throw new DeployRefused(
      `.firebaserc alias "${target}" is ${JSON.stringify(actual)}, ` +
        `expected "${expected}".`,
    );
  }
  if (projects.prod !== EXPECTED_PROJECTS.prod) {
    throw new DeployRefused(
      `.firebaserc alias "prod" is ${JSON.stringify(projects.prod)}, ` +
        `expected "${EXPECTED_PROJECTS.prod}".`,
    );
  }
  return expected;
}

export function assertProdConfirmed(target, env) {
  if (target !== "prod") return;
  if (env.CONFIRM_PROD_DEPLOY !== PROD_CONFIRMATION) {
    throw new DeployRefused(
      "Refusing production deploy without explicit confirmation.\n" +
        `Re-run with CONFIRM_PROD_DEPLOY=${PROD_CONFIRMATION} only after ` +
        "B-BILLING is Verified and staging has been validated.",
    );
  }
}

export function deploySteps(target) {
  return [
    { label: "build", command: "npm", args: ["run", "build"], cwd: FUNCTIONS_DIR },
    {
      label: "deploy",
      command: "firebase",
      args: ["deploy", "--only", "functions", "--project", target],
      cwd: REPO_ROOT,
    },
  ];
}

export function spawnStep({ command, args, cwd }) {
  for (const a of [command, ...args]) {
    if (!SAFE_ARG.test(a)) {
      return Promise.reject(new DeployRefused(`Unsafe subprocess argument: ${a}`));
    }
  }
  // npm and firebase are .cmd shims on Windows, which cannot be spawned
  // directly; every argument has passed SAFE_ARG, so cmd.exe sees no
  // metacharacters.
  const isWindows = process.platform === "win32";
  const file = isWindows ? process.env.ComSpec || "cmd.exe" : command;
  const argv = isWindows ? ["/d", "/s", "/c", `${command}.cmd`, ...args] : args;
  return new Promise((done) => {
    const child = spawn(file, argv, { cwd, stdio: "inherit" });
    child.on("error", (e) => {
      console.error(`Failed to start ${command}: ${e.message}`);
      done(1);
    });
    child.on("close", (code) => done(code ?? 1));
  });
}

export async function runDeploy({
  args,
  env = process.env,
  firebasercPath = FIREBASERC_PATH,
  runStep = spawnStep,
  log = console.log,
  error = console.error,
}) {
  let target;
  let projectId;
  try {
    target = parseTarget(args);
    projectId = assertAliasMapping(target, firebasercPath);
    assertProdConfirmed(target, env);
  } catch (e) {
    if (!(e instanceof DeployRefused)) throw e;
    error(`Deploy refused: ${e.message}`);
    return 64;
  }

  log(`Target: ${target}`);
  log(`Project: ${projectId}`);
  for (const step of deploySteps(target)) {
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
  process.exitCode = await runDeploy({ args: process.argv.slice(2) });
}
