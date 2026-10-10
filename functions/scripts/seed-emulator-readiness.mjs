// Read-only readiness and identity probes against the local Emulator Suite,
// run before firebase-admin is loaded. Only 127.0.0.1 is contacted, and the
// hub locator file is only ever read.
import { readFileSync } from "node:fs";
import http from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { LOOPBACK_HOST, SEED_PROJECT_ID } from "./seed-emulator-guards.mjs";

// firebase-tools (lib/emulator/hub.js) writes {version, origins, pid} to
// os.tmpdir()/hub-<projectId>.json when its hub starts, and the hub's GET /
// answers with the same locator from the same process.
export const HUB_LOCATOR_FILE = `hub-${SEED_PROJECT_ID}.json`;

/** GET http://127.0.0.1:<port><path>; resolves { status, body }. */
export function httpGetLocal({ port, path, timeoutMs = 3000 }) {
  return new Promise((resolve, reject) => {
    const req = http.get(
      { host: LOOPBACK_HOST, port, path, agent: false, timeout: timeoutMs },
      (res) => {
        let body = "";
        res.setEncoding("utf8");
        res.on("data", (chunk) => {
          body += chunk;
        });
        res.on("end", () => resolve({ status: res.statusCode, body }));
      },
    );
    req.on("timeout", () => req.destroy(new Error(`timed out after ${timeoutMs} ms`)));
    req.on("error", reject);
  });
}

function parseJson(body) {
  try {
    return JSON.parse(body);
  } catch {
    return undefined;
  }
}

/**
 * Returns the list of readiness problems (empty when ready). The hub must
 * report auth and firestore on the loopback host and the firebase.json ports,
 * and each emulator must answer its own status endpoint.
 */
export async function checkEmulatorReadiness({ ports, httpGet = httpGetLocal }) {
  const problems = [];
  const get = async (label, port, path) => {
    try {
      return await httpGet({ port, path });
    } catch (error) {
      problems.push(`${label} (${LOOPBACK_HOST}:${port}${path}) is not reachable: ${error.message}`);
      return null;
    }
  };

  const hub = await get("Emulator hub", ports.hub, "/emulators");
  if (hub !== null) {
    const listing = hub.status === 200 ? parseJson(hub.body) : undefined;
    if (listing === undefined || listing === null || typeof listing !== "object") {
      problems.push(`Emulator hub returned HTTP ${hub.status} without a JSON emulator list.`);
    } else {
      for (const name of ["auth", "firestore"]) {
        const entry = listing[name];
        if (entry === undefined) {
          problems.push(`Emulator hub does not list the ${name} emulator.`);
        } else if (entry.host !== LOOPBACK_HOST || entry.port !== ports[name]) {
          problems.push(
            `Emulator hub lists ${name} at ${entry.host}:${entry.port}; expected ${LOOPBACK_HOST}:${ports[name]}.`,
          );
        }
      }
    }
  }

  const auth = await get("Auth emulator", ports.auth, "/");
  if (auth !== null) {
    const body = auth.status === 200 ? parseJson(auth.body) : undefined;
    if (body?.authEmulator?.ready !== true) {
      problems.push(`Auth emulator returned HTTP ${auth.status} without "authEmulator.ready": true.`);
    }
  }

  const firestore = await get("Firestore emulator", ports.firestore, "/");
  if (firestore !== null && (firestore.status !== 200 || firestore.body.trim() !== "Ok")) {
    problems.push(`Firestore emulator returned HTTP ${firestore.status} instead of "Ok".`);
  }

  return problems;
}

/** Reads the hub locator for SEED_PROJECT_ID; never creates, repairs or removes it. */
export function readHubLocatorFile({ dir = tmpdir() } = {}) {
  const path = join(dir, HUB_LOCATOR_FILE);
  return { path, text: readFileSync(path, "utf8") };
}

const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isPid = (value) => Number.isInteger(value) && value > 0;
const sameStrings = (a, b) =>
  Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((v, i) => v === b[i]);
const describe = (entry) => (isObject(entry) ? `${entry.host}:${entry.port}` : JSON.stringify(entry));

/**
 * Proves the running suite belongs to SEED_PROJECT_ID. Every piece of
 * evidence must be present and agree, otherwise `problems` is non-empty:
 *  1. hub GET /: locator {version, origins, pid} of the hub process;
 *  2. hub-<project>.json in the temp dir: same pid, version and origins;
 *  3. hub GET /emulators: hub, auth, firestore and ui on 127.0.0.1 and the
 *     firebase.json ports;
 *  4. UI GET /api/config (served by the same process): projectId is exactly
 *     SEED_PROJECT_ID and its emulator entries equal the hub's.
 * Returns { problems, hubPid, cliVersion }.
 */
export async function checkEmulatorIdentity({ ports, httpGet = httpGetLocal, readLocator = readHubLocatorFile }) {
  const problems = [];
  const fail = (message) => {
    problems.push(message);
    return { problems, hubPid: null, cliVersion: null };
  };
  const getJson = async (label, port, path) => {
    let response;
    try {
      response = await httpGet({ port, path });
    } catch (error) {
      return { error: `${label} (${LOOPBACK_HOST}:${port}${path}) is not reachable: ${error.message}` };
    }
    const body = response.status === 200 ? parseJson(response.body) : undefined;
    if (!isObject(body)) return { error: `${label} returned HTTP ${response.status} without a JSON object.` };
    return { body };
  };

  const hubOrigin = `http://${LOOPBACK_HOST}:${ports.hub}`;
  const root = await getJson("Emulator hub", ports.hub, "/");
  if (root.error) return fail(root.error);
  const hub = root.body;
  if (!isPid(hub.pid)) return fail(`Emulator hub reported pid ${JSON.stringify(hub.pid)}.`);
  if (typeof hub.version !== "string" || hub.version === "") {
    return fail(`Emulator hub reported version ${JSON.stringify(hub.version)}.`);
  }
  if (hub.host !== LOOPBACK_HOST || hub.port !== ports.hub || !Array.isArray(hub.origins) || !hub.origins.includes(hubOrigin)) {
    return fail(`Emulator hub reported ${describe(hub)} with origins ${JSON.stringify(hub.origins)}; expected ${hubOrigin}.`);
  }

  let locatorPath = HUB_LOCATOR_FILE;
  let locator;
  try {
    const read = readLocator();
    locatorPath = read.path;
    locator = parseJson(read.text);
  } catch (error) {
    return fail(
      `Hub locator ${locatorPath} for "${SEED_PROJECT_ID}" could not be read (${error.code ?? error.message}); ` +
        `the running emulators were not started for "${SEED_PROJECT_ID}" from this user's temp directory.`,
    );
  }
  if (!isObject(locator)) return fail(`Hub locator ${locatorPath} is not a JSON object.`);
  if (locator.pid !== hub.pid) {
    return fail(
      `Hub locator ${locatorPath} names pid ${JSON.stringify(locator.pid)}, but the hub on port ${ports.hub} is pid ${hub.pid}; ` +
        `the hub does not belong to "${SEED_PROJECT_ID}" or the locator is stale.`,
    );
  }
  if (locator.version !== hub.version) {
    return fail(`Hub locator version ${JSON.stringify(locator.version)} differs from the hub's ${JSON.stringify(hub.version)}.`);
  }
  if (!sameStrings(locator.origins, hub.origins)) {
    return fail(`Hub locator origins ${JSON.stringify(locator.origins)} differ from the hub's ${JSON.stringify(hub.origins)}.`);
  }

  const listed = await getJson("Emulator hub", ports.hub, "/emulators");
  if (listed.error) return fail(listed.error);
  const listing = listed.body;
  for (const name of ["hub", "auth", "firestore", "ui"]) {
    const entry = listing[name];
    if (!isObject(entry)) {
      problems.push(`Emulator hub does not list the ${name} emulator.`);
    } else if (entry.host !== LOOPBACK_HOST || entry.port !== ports[name]) {
      problems.push(`Emulator hub lists ${name} at ${describe(entry)}; expected ${LOOPBACK_HOST}:${ports[name]}.`);
    }
  }
  if (problems.length > 0) return { problems, hubPid: null, cliVersion: null };

  const ui = await getJson("Emulator UI", ports.ui, "/api/config");
  if (ui.error) return fail(ui.error);
  const config = ui.body;
  if (config.projectId !== SEED_PROJECT_ID) {
    return fail(`Emulator UI reports project ${JSON.stringify(config.projectId)}; expected exactly "${SEED_PROJECT_ID}".`);
  }
  for (const name of ["hub", "auth", "firestore", "ui"]) {
    const fromUi = config[name];
    const fromHub = listing[name];
    if (!isObject(fromUi) || fromUi.host !== fromHub.host || fromUi.port !== fromHub.port || fromUi.pid !== fromHub.pid) {
      problems.push(`Emulator UI lists ${name} at ${describe(fromUi)}; the hub lists ${describe(fromHub)}.`);
    }
  }
  if (problems.length > 0) return { problems, hubPid: null, cliVersion: null };

  return { problems, hubPid: hub.pid, cliVersion: hub.version };
}
