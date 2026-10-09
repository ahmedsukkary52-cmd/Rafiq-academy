/**
 * Pre-SDK guards of the emulator seeder (scripts/seed-emulator-guards.mjs).
 * Pure: no emulator, no network, no firebase-admin.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  checkSeedEnvironment,
  readEmulatorPorts,
  SEED_PROJECT_ID,
} from "../scripts/seed-emulator-guards.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoFirebaseJson = JSON.parse(readFileSync(join(here, "..", "..", "firebase.json"), "utf8"));
const PORTS = { auth: 9099, firestore: 8080, hub: 4400 };

const check = (env, { platform = "win32", files = [] } = {}) =>
  checkSeedEnvironment({
    env,
    platform,
    fileExists: (p) => files.includes(p),
    ports: PORTS,
  });

test("the seed project is exactly demo-rafiq-rules", () => {
  assert.equal(SEED_PROJECT_ID, "demo-rafiq-rules");
});

test("repo firebase.json yields the documented emulator ports", () => {
  const { problems, ports } = readEmulatorPorts(repoFirebaseJson);
  assert.deepEqual(problems, []);
  assert.deepEqual(ports, PORTS);
});

test("missing or invalid emulator configuration is refused", () => {
  const cases = [
    {},
    { emulators: null },
    { emulators: { firestore: { port: 8080 } } },
    { emulators: { auth: { port: 9099 } } },
    { emulators: { auth: { port: "9099" }, firestore: { port: 8080 } } },
    { emulators: { auth: { port: 0 }, firestore: { port: 8080 } } },
    { emulators: { auth: { port: 70000 }, firestore: { port: 8080 } } },
    { emulators: { auth: 9099, firestore: { port: 8080 } } },
    { emulators: { auth: { port: 8080 }, firestore: { port: 8080 } } },
    { emulators: { auth: { port: 9099 }, firestore: { port: 8080 }, hub: { port: 9099 } } },
  ];
  for (const json of cases) {
    const { problems, ports } = readEmulatorPorts(json);
    assert.ok(problems.length > 0, JSON.stringify(json));
    assert.equal(ports, null, JSON.stringify(json));
  }
});

test("non-loopback emulator hosts in firebase.json are refused", () => {
  for (const host of ["0.0.0.0", "localhost", "::1", "10.0.0.5", "firestore.googleapis.com"]) {
    for (const name of ["auth", "firestore", "hub"]) {
      const json = structuredClone(repoFirebaseJson);
      json.emulators[name] = { ...(json.emulators[name] ?? { port: 4400 }), host };
      assert.ok(readEmulatorPorts(json).problems.length > 0, `${name} ${host}`);
    }
  }
});

test("a clean environment passes and yields exact loopback overrides", () => {
  const { problems, overrides } = check({ APPDATA: "C:\\Users\\x\\AppData\\Roaming" });
  assert.deepEqual(problems, []);
  assert.deepEqual(overrides, {
    FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
    FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
    FIREBASE_EMULATOR_HUB: "127.0.0.1:4400",
    METADATA_SERVER_DETECTION: "none",
    GOOGLE_CLOUD_PROJECT: "demo-rafiq-rules",
    GCLOUD_PROJECT: "demo-rafiq-rules",
  });
});

test("GOOGLE_APPLICATION_CREDENTIALS is refused whatever its value or casing", () => {
  for (const env of [
    { GOOGLE_APPLICATION_CREDENTIALS: "C:\\keys\\sa.json" },
    { GOOGLE_APPLICATION_CREDENTIALS: "" },
    { google_application_credentials: "/tmp/sa.json" },
  ]) {
    assert.ok(check(env).problems.some((p) => p.includes("GOOGLE_APPLICATION_CREDENTIALS")), JSON.stringify(env));
  }
});

test("gcloud application default credentials on disk are refused", () => {
  const win = check(
    { APPDATA: "C:\\AppData" },
    { files: [join("C:\\AppData", "gcloud", "application_default_credentials.json")] },
  );
  assert.ok(win.problems.some((p) => p.includes("application default credentials")));

  const posix = check(
    { HOME: "/home/u" },
    { platform: "linux", files: [join("/home/u", ".config", "gcloud", "application_default_credentials.json")] },
  );
  assert.ok(posix.problems.some((p) => p.includes("application default credentials")));

  assert.ok(check({ CLOUDSDK_CONFIG: "C:\\gcloud" }).problems.some((p) => p.includes("CLOUDSDK_CONFIG")));
  for (const value of ["true", "false"]) {
    const mtls = check({ GOOGLE_API_USE_CLIENT_CERTIFICATE: value });
    assert.ok(mtls.problems.some((p) => p.includes("GOOGLE_API_USE_CLIENT_CERTIFICATE")), value);
  }
});

test("conflicting or invalid project sources are refused (no demo- prefix trust)", () => {
  const bad = [
    "rafiq-academy",
    "rafiq-academy-staging",
    "rafiq-academy-prod",
    "demo-other",
    "demo-rafiq-rules-x",
    " demo-rafiq-rules",
    "DEMO-RAFIQ-RULES",
    "",
  ];
  for (const key of ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT", "GCP_PROJECT", "CLOUDSDK_CORE_PROJECT"]) {
    for (const value of bad) {
      assert.ok(check({ [key]: value }).problems.length > 0, `${key}=${JSON.stringify(value)}`);
    }
    assert.deepEqual(check({ [key]: SEED_PROJECT_ID }).problems, [], key);
  }
  const mixed = check({ GCLOUD_PROJECT: SEED_PROJECT_ID, GOOGLE_CLOUD_PROJECT: "rafiq-academy" });
  assert.equal(mixed.problems.length, 1);
});

test("FIREBASE_CONFIG must be inline JSON naming exactly the seed project", () => {
  for (const value of [
    "not json",
    "/path/to/config.json",
    "null",
    "[]",
    "{}",
    JSON.stringify({ projectId: "rafiq-academy" }),
    JSON.stringify({ projectId: "demo-other" }),
  ]) {
    assert.ok(check({ FIREBASE_CONFIG: value }).problems.length > 0, value);
  }
  assert.deepEqual(check({ FIREBASE_CONFIG: JSON.stringify({ projectId: SEED_PROJECT_ID }) }).problems, []);
});

test("pre-set emulator hosts must match firebase.json exactly", () => {
  const bad = {
    FIRESTORE_EMULATOR_HOST: ["localhost:8080", "127.0.0.1:8081", "[::1]:8080", "firestore.googleapis.com:443", ""],
    FIREBASE_AUTH_EMULATOR_HOST: ["localhost:9099", "127.0.0.1:9098", "0.0.0.0:9099"],
    FIREBASE_EMULATOR_HUB: ["localhost:4400", "127.0.0.1:4401"],
    METADATA_SERVER_DETECTION: ["assume-present", "ping-only", "bios-only", ""],
  };
  for (const [key, values] of Object.entries(bad)) {
    for (const value of values) {
      assert.ok(check({ [key]: value }).problems.some((p) => p.startsWith(key)), `${key}=${value}`);
    }
  }
  assert.deepEqual(
    check({
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
      FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
      FIREBASE_EMULATOR_HUB: "127.0.0.1:4400",
    }).problems,
    [],
  );
});

test("other emulator host variables must stay on the loopback address", () => {
  assert.ok(check({ FIREBASE_STORAGE_EMULATOR_HOST: "storage.example.com:9199" }).problems.length > 0);
  assert.ok(check({ PUBSUB_EMULATOR_HOST: "localhost:8085" }).problems.length > 0);
  assert.deepEqual(check({ FIREBASE_STORAGE_EMULATOR_HOST: "127.0.0.1:9199" }).problems, []);
});

test("proxy variables are refused", () => {
  for (const key of ["HTTP_PROXY", "https_proxy", "grpc_proxy", "ALL_PROXY"]) {
    assert.ok(check({ [key]: "http://127.0.0.1:3128" }).problems.some((p) => p.includes("proxies")), key);
  }
  assert.deepEqual(check({ NO_PROXY: "*" }).problems, []);
});

test("unknown ports refuse the environment", () => {
  const result = checkSeedEnvironment({ env: {}, platform: "win32", fileExists: () => false, ports: null });
  assert.ok(result.problems.length > 0);
  assert.equal(result.overrides, null);
});
