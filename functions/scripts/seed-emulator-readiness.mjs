// Read-only readiness probes against the local Emulator Suite, run before
// firebase-admin is loaded. Only 127.0.0.1 is contacted.
import http from "node:http";

import { LOOPBACK_HOST } from "./seed-emulator-guards.mjs";

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
