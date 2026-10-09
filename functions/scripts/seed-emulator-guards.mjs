// Pre-flight checks for `npm run seed:emulator`, evaluated before
// firebase-admin is loaded. Pure: callers pass env, firebase.json and a
// file-existence probe, so every refusal is unit-testable.
//
// The demo- prefix is not treated as a safety guarantee: the project must be
// exactly SEED_PROJECT_ID, and network isolation is enforced separately by
// seed-emulator-egress.mjs.
import { join } from "node:path";

export const SEED_PROJECT_ID = "demo-rafiq-rules";
export const LOOPBACK_HOST = "127.0.0.1";
export const DEFAULT_HUB_PORT = 4400;

// Every env var firebase-admin / @google-cloud/firestore read a project from.
const PROJECT_ENV_KEYS = [
  "GOOGLE_CLOUD_PROJECT",
  "GCLOUD_PROJECT",
  "GCP_PROJECT",
  "CLOUDSDK_CORE_PROJECT",
];

// grpc-js and Node HTTP clients honor these; a proxy would carry traffic off
// the loopback interface.
const PROXY_ENV_KEYS = ["HTTP_PROXY", "HTTPS_PROXY", "GRPC_PROXY", "ALL_PROXY"];

export class SeedGuardError extends Error {}

function isPort(value) {
  return Number.isInteger(value) && value > 0 && value < 65536;
}

/**
 * Reads the emulator ports from firebase.json. Hosts, when present, must be
 * the IPv4 loopback address; auth and firestore ports must be explicit.
 */
export function readEmulatorPorts(firebaseJson) {
  const problems = [];
  const emulators = firebaseJson?.emulators;
  if (emulators === null || typeof emulators !== "object") {
    return { problems: ["firebase.json has no \"emulators\" section."], ports: null };
  }

  const portOf = (name, fallback) => {
    const entry = emulators[name];
    if (entry !== undefined && (entry === null || typeof entry !== "object")) {
      problems.push(`firebase.json emulators.${name} must be an object.`);
      return null;
    }
    if (entry?.host !== undefined && entry.host !== LOOPBACK_HOST) {
      problems.push(
        `firebase.json emulators.${name}.host is ${JSON.stringify(entry.host)}; ` +
          `only ${LOOPBACK_HOST} is allowed.`,
      );
    }
    const port = entry?.port ?? fallback;
    if (!isPort(port)) {
      problems.push(`firebase.json emulators.${name}.port is missing or invalid.`);
      return null;
    }
    return port;
  };

  const ports = {
    auth: portOf("auth"),
    firestore: portOf("firestore"),
    hub: portOf("hub", DEFAULT_HUB_PORT),
  };
  const values = Object.values(ports).filter((p) => p !== null);
  if (new Set(values).size !== values.length) {
    problems.push("firebase.json emulator ports must be distinct.");
  }
  return { problems, ports: problems.length === 0 ? ports : null };
}

/** Path firebase-admin checks for gcloud application default credentials. */
export function gcloudAdcPath(env, platform) {
  if (platform === "win32") {
    return env.get("APPDATA") ? join(env.get("APPDATA"), "gcloud", "application_default_credentials.json") : null;
  }
  return env.get("HOME") ? join(env.get("HOME"), ".config", "gcloud", "application_default_credentials.json") : null;
}

function upperCaseEnv(env) {
  const map = new Map();
  for (const [key, value] of Object.entries(env)) {
    if (value !== undefined) map.set(key.toUpperCase(), value);
  }
  return map;
}

/**
 * Returns { problems, overrides }. `overrides` are the only env values the
 * seeder sets before loading firebase-admin; any pre-existing value must
 * already match them exactly.
 */
export function checkSeedEnvironment({ env, platform, fileExists, ports }) {
  const problems = [];
  const vars = upperCaseEnv(env);

  if (vars.has("GOOGLE_APPLICATION_CREDENTIALS")) {
    problems.push("GOOGLE_APPLICATION_CREDENTIALS is set; the emulator seeder never uses credential files.");
  }
  if (vars.has("CLOUDSDK_CONFIG")) {
    problems.push("CLOUDSDK_CONFIG is set; the emulator seeder never uses gcloud configuration.");
  }
  // google-gax runs the cert_provider_command from ~/.secureConnect when this
  // is "true"; a child process is outside the network allowlist.
  if (vars.has("GOOGLE_API_USE_CLIENT_CERTIFICATE")) {
    problems.push("GOOGLE_API_USE_CLIENT_CERTIFICATE is set; the emulator seeder never uses mTLS client certificates.");
  }
  const adc = gcloudAdcPath(vars, platform);
  if (adc !== null && fileExists(adc)) {
    problems.push(
      `gcloud application default credentials exist at ${adc}; firebase-admin would load them. ` +
        "Run the seeder from an environment without real credentials.",
    );
  }

  for (const key of PROJECT_ENV_KEYS) {
    if (vars.has(key) && vars.get(key) !== SEED_PROJECT_ID) {
      problems.push(`${key} is ${JSON.stringify(vars.get(key))}; expected exactly "${SEED_PROJECT_ID}".`);
    }
  }

  if (vars.has("FIREBASE_CONFIG")) {
    let parsed;
    try {
      parsed = JSON.parse(vars.get("FIREBASE_CONFIG"));
    } catch {
      parsed = undefined;
    }
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      problems.push("FIREBASE_CONFIG is set but is not an inline JSON object.");
    } else if (parsed.projectId !== SEED_PROJECT_ID) {
      problems.push(
        `FIREBASE_CONFIG.projectId is ${JSON.stringify(parsed.projectId)}; expected exactly "${SEED_PROJECT_ID}".`,
      );
    }
  }

  for (const key of PROXY_ENV_KEYS) {
    if (vars.has(key)) problems.push(`${key} is set; proxies are not allowed for the emulator seeder.`);
  }

  if (ports === null || ports === undefined) {
    problems.push("Emulator ports are unknown.");
    return { problems, overrides: null };
  }

  const expected = {
    FIRESTORE_EMULATOR_HOST: `${LOOPBACK_HOST}:${ports.firestore}`,
    FIREBASE_AUTH_EMULATOR_HOST: `${LOOPBACK_HOST}:${ports.auth}`,
    FIREBASE_EMULATOR_HUB: `${LOOPBACK_HOST}:${ports.hub}`,
    // google-gax resolves a universe domain on every Firestore client; without
    // this, gcp-metadata probes the GCE metadata server (169.254.169.254).
    METADATA_SERVER_DETECTION: "none",
  };
  for (const [key, value] of Object.entries(expected)) {
    if (vars.has(key) && vars.get(key) !== value) {
      problems.push(`${key} is ${JSON.stringify(vars.get(key))}; expected exactly "${value}".`);
    }
  }
  for (const [key, value] of vars) {
    if (key in expected || !key.endsWith("_EMULATOR_HOST")) continue;
    if (!value.startsWith(`${LOOPBACK_HOST}:`)) {
      problems.push(`${key} is ${JSON.stringify(value)}; emulator hosts must be ${LOOPBACK_HOST}.`);
    }
  }

  return {
    problems,
    overrides: {
      ...expected,
      GOOGLE_CLOUD_PROJECT: SEED_PROJECT_ID,
      GCLOUD_PROJECT: SEED_PROJECT_ID,
    },
  };
}
