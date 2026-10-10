/**
 * Emulator identity check of the seeder (checkEmulatorIdentity in
 * scripts/seed-emulator-readiness.mjs): hub pid, hub locator file, hub
 * emulator listing and the Emulator UI's projectId must all agree. Fakes and
 * local HTTP servers on 127.0.0.1 only; no emulator, no Firebase service.
 * The last tests read the installed Firebase CLI to confirm the evidence the
 * check relies on still exists there.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import http from "node:http";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  checkEmulatorIdentity,
  HUB_LOCATOR_FILE,
  readHubLocatorFile,
} from "../scripts/seed-emulator-readiness.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = join(here, "..");
const PORTS = { auth: 9099, firestore: 8080, hub: 4400, ui: 4000 };

function evidence(ports = PORTS) {
  const entry = (name, port, extra = {}) => ({
    name,
    host: "127.0.0.1",
    port,
    listen: [{ address: "127.0.0.1", family: "IPv4", port }],
    ...extra,
  });
  const origins = [`http://127.0.0.1:${ports.hub}`];
  const listing = {
    hub: entry("hub", ports.hub),
    ui: entry("ui", ports.ui),
    auth: entry("auth", ports.auth),
    firestore: entry("firestore", ports.firestore, { pid: 7777 }),
    functions: entry("functions", 5001),
  };
  return {
    hubRoot: { version: "15.18.0", origins, pid: 4242, host: "127.0.0.1", port: ports.hub },
    locator: { version: "15.18.0", origins: [...origins], pid: 4242 },
    listing,
    uiConfig: { projectId: "demo-rafiq-rules", experiments: [], analytics: {}, ...structuredClone(listing) },
  };
}

async function identify(e, { locatorError } = {}) {
  const requests = [];
  const routes = { [`${PORTS.hub}/`]: "hubRoot", [`${PORTS.hub}/emulators`]: "listing", [`${PORTS.ui}/api/config`]: "uiConfig" };
  const httpGet = async ({ port, path }) => {
    requests.push(`${port}${path}`);
    const body = e[routes[`${port}${path}`]];
    if (body === undefined) throw Object.assign(new Error("connect ECONNREFUSED"), { code: "ECONNREFUSED" });
    if (body !== null && typeof body === "object" && "status" in body && "raw" in body) return { status: body.status, body: body.raw };
    return { status: 200, body: typeof body === "string" ? body : JSON.stringify(body) };
  };
  let locatorReads = 0;
  const readLocator = () => {
    locatorReads += 1;
    if (locatorError) throw locatorError;
    return { path: join("T", HUB_LOCATOR_FILE), text: typeof e.locator === "string" ? e.locator : JSON.stringify(e.locator) };
  };
  const result = await checkEmulatorIdentity({ ports: PORTS, httpGet, readLocator });
  return { ...result, requests, locatorReads };
}

async function assertRefused(e, label, options) {
  const result = await identify(e, options);
  assert.ok(result.problems.length > 0, `${label}: accepted`);
  assert.equal(result.hubPid, null, label);
  assert.equal(result.cliVersion, null, label);
  return result;
}

// ── Accepted evidence ───────────────────────────────────────────────────────

test("consistent hub, locator, listing and UI evidence is accepted", async () => {
  const result = await identify(evidence());
  assert.deepEqual(result.problems, []);
  assert.equal(result.hubPid, 4242);
  assert.equal(result.cliVersion, "15.18.0");
  assert.deepEqual(result.requests, ["4400/", "4400/emulators", "4000/api/config"]);
  assert.equal(result.locatorReads, 1);
});

// ── Hub GET / ───────────────────────────────────────────────────────────────

test("a missing, non-JSON or inconsistent hub root is refused", async () => {
  const cases = {
    unreachable: (e) => delete e.hubRoot,
    notJson: (e) => (e.hubRoot = "<html>"),
    http500: (e) => (e.hubRoot = { status: 500, raw: "{}" }),
    array: (e) => (e.hubRoot = []),
    pidMissing: (e) => delete e.hubRoot.pid,
    pidZero: (e) => (e.hubRoot.pid = 0),
    pidNegative: (e) => (e.hubRoot.pid = -1),
    pidFraction: (e) => (e.hubRoot.pid = 42.5),
    pidString: (e) => (e.hubRoot.pid = "4242"),
    versionMissing: (e) => delete e.hubRoot.version,
    versionEmpty: (e) => (e.hubRoot.version = ""),
    hostLocalhost: (e) => (e.hubRoot.host = "localhost"),
    hostIpv6: (e) => (e.hubRoot.host = "::1"),
    otherPort: (e) => (e.hubRoot.port = 4401),
    originsMissing: (e) => delete e.hubRoot.origins,
    originsOtherHost: (e) => (e.hubRoot.origins = ["http://localhost:4400"]),
  };
  for (const [label, mutate] of Object.entries(cases)) {
    const e = evidence();
    mutate(e);
    const result = await assertRefused(e, label);
    assert.equal(result.locatorReads, 0, `${label}: locator read after a bad hub root`);
  }
});

// ── Hub locator file ────────────────────────────────────────────────────────

test("a missing, unreadable or mismatched hub locator is refused", async () => {
  await assertRefused(evidence(), "missing", {
    locatorError: Object.assign(new Error("ENOENT: no such file"), { code: "ENOENT" }),
  });
  await assertRefused(evidence(), "denied", {
    locatorError: Object.assign(new Error("EACCES: permission denied"), { code: "EACCES" }),
  });
  const cases = {
    notJson: (e) => (e.locator = "not json"),
    nullJson: (e) => (e.locator = "null"),
    array: (e) => (e.locator = "[]"),
    otherPid: (e) => (e.locator.pid = 4243),
    stringPid: (e) => (e.locator.pid = "4242"),
    pidMissing: (e) => delete e.locator.pid,
    otherVersion: (e) => (e.locator.version = "15.17.0"),
    versionMissing: (e) => delete e.locator.version,
    originsMissing: (e) => delete e.locator.origins,
    originsExtra: (e) => e.locator.origins.push("http://[::1]:4400"),
    originsOther: (e) => (e.locator.origins = ["http://127.0.0.1:4401"]),
  };
  for (const [label, mutate] of Object.entries(cases)) {
    const e = evidence();
    mutate(e);
    const result = await assertRefused(e, label);
    assert.ok(!result.requests.includes("4000/api/config"), `${label}: UI queried after a bad locator`);
  }
});

test("a stale locator from a dead hub (pid mismatch) names both pids", async () => {
  const e = evidence();
  e.locator.pid = 1111;
  const { problems } = await identify(e);
  assert.match(problems[0], /names pid 1111/);
  assert.match(problems[0], /pid 4242/);
});

// ── Hub GET /emulators ──────────────────────────────────────────────────────

test("the hub listing must show hub, auth, firestore and ui on 127.0.0.1 and the pinned ports", async () => {
  const cases = {};
  for (const name of ["hub", "auth", "firestore", "ui"]) {
    cases[`${name}Missing`] = (e) => delete e.listing[name];
    cases[`${name}Localhost`] = (e) => (e.listing[name].host = "localhost");
    cases[`${name}Ipv6`] = (e) => (e.listing[name].host = "::1");
    cases[`${name}OtherPort`] = (e) => (e.listing[name].port += 1);
  }
  cases.notJson = (e) => (e.listing = "nope");
  for (const [label, mutate] of Object.entries(cases)) {
    const e = evidence();
    mutate(e);
    const result = await assertRefused(e, label);
    assert.ok(!result.requests.includes("4000/api/config"), `${label}: UI queried after a bad listing`);
  }
});

// ── Emulator UI GET /api/config ─────────────────────────────────────────────

test("the UI projectId must be exactly demo-rafiq-rules", async () => {
  for (const projectId of [
    "demo-no-project",
    "demo-rafiq-rules-x",
    "demo-other",
    "rafiq-academy",
    "rafiq-academy-prod",
    " demo-rafiq-rules",
    "DEMO-RAFIQ-RULES",
    "",
    null,
    undefined,
  ]) {
    const e = evidence();
    if (projectId === undefined) delete e.uiConfig.projectId;
    else e.uiConfig.projectId = projectId;
    const { problems } = await assertRefused(e, JSON.stringify(projectId));
    assert.match(problems[0], /expected exactly "demo-rafiq-rules"/);
  }
});

test("UI emulator entries must equal the hub's (no port forwarding, same pids)", async () => {
  const cases = {
    unreachable: (e) => delete e.uiConfig,
    notJson: (e) => (e.uiConfig = "<html>"),
    http404: (e) => (e.uiConfig = { status: 404, raw: "{}" }),
    authMissing: (e) => delete e.uiConfig.auth,
    firestorePort: (e) => (e.uiConfig.firestore.port = 8081),
    firestorePid: (e) => (e.uiConfig.firestore.pid = 8888),
    forwardedUi: (e) => Object.assign(e.uiConfig.ui, { host: "4000-ws.example.dev", port: 443 }),
    hubHost: (e) => (e.uiConfig.hub.host = "localhost"),
  };
  for (const [label, mutate] of Object.entries(cases)) {
    const e = evidence();
    mutate(e);
    await assertRefused(e, label);
  }
});

// ── Locator file access ─────────────────────────────────────────────────────

test("readHubLocatorFile reads hub-demo-rafiq-rules.json from the given directory only", () => {
  assert.equal(HUB_LOCATOR_FILE, "hub-demo-rafiq-rules.json");
  const dir = mkdtempSync(join(tmpdir(), "seed-identity-"));
  try {
    assert.throws(() => readHubLocatorFile({ dir }), (e) => e.code === "ENOENT");
    writeFileSync(join(dir, HUB_LOCATOR_FILE), '{"pid":1}');
    assert.deepEqual(readHubLocatorFile({ dir }), { path: join(dir, HUB_LOCATOR_FILE), text: '{"pid":1}' });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the readiness module never writes, repairs or removes files", () => {
  const source = readFileSync(join(functionsDir, "scripts", "seed-emulator-readiness.mjs"), "utf8");
  assert.doesNotMatch(
    source,
    /\b(writeFile|writeFileSync|appendFile|appendFileSync|unlink|unlinkSync|rm|rmSync|rmdir|mkdir|mkdirSync|rename|renameSync|copyFile|copyFileSync|createWriteStream|truncate)\b/,
  );
  assert.doesNotMatch(source, /method:\s*["'](POST|PUT|PATCH|DELETE)/i);
});

// ── Real local HTTP (no guard, no emulator) ─────────────────────────────────

async function listen(handler) {
  const server = http.createServer(handler);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return server;
}

test("the check works over real HTTP on 127.0.0.1 and refuses a pid change", async () => {
  let current;
  const hubServer = await listen((req, res) => {
    const body = req.url === "/" ? current.hubRoot : req.url === "/emulators" ? current.listing : undefined;
    res.writeHead(body ? 200 : 404, { "content-type": "application/json" });
    res.end(JSON.stringify(body ?? {}));
  });
  const uiServer = await listen((req, res) => {
    res.writeHead(req.url === "/api/config" ? 200 : 404, { "content-type": "application/json" });
    res.end(JSON.stringify(req.url === "/api/config" ? current.uiConfig : {}));
  });
  const dir = mkdtempSync(join(tmpdir(), "seed-identity-http-"));
  try {
    const ports = { auth: 9099, firestore: 8080, hub: hubServer.address().port, ui: uiServer.address().port };
    current = evidence(ports);
    writeFileSync(join(dir, HUB_LOCATOR_FILE), JSON.stringify(current.locator));
    const readLocator = () => readHubLocatorFile({ dir });

    const ok = await checkEmulatorIdentity({ ports, readLocator });
    assert.deepEqual(ok.problems, []);
    assert.equal(ok.hubPid, 4242);

    current.hubRoot.pid = 5151;
    const refused = await checkEmulatorIdentity({ ports, readLocator });
    assert.ok(refused.problems.length > 0);
    assert.equal(refused.hubPid, null);
  } finally {
    rmSync(dir, { recursive: true, force: true });
    await new Promise((resolve) => hubServer.close(resolve));
    await new Promise((resolve) => uiServer.close(resolve));
  }
});

// ── Installed Firebase CLI still provides the evidence ──────────────────────

function firebaseToolsDir() {
  const candidates = [
    process.env.FIREBASE_TOOLS_DIR,
    process.env.APPDATA && join(process.env.APPDATA, "npm", "node_modules", "firebase-tools"),
    join(dirname(process.execPath), "node_modules", "firebase-tools"),
    join(dirname(process.execPath), "..", "lib", "node_modules", "firebase-tools"),
  ].filter(Boolean);
  return candidates.find((dir) => existsSync(join(dir, "lib", "emulator", "hub.js")));
}

test("installed firebase-tools: locator file, hub root, /emulators and /api/config as relied on", (t) => {
  const dir = firebaseToolsDir();
  if (!dir) {
    t.skip("firebase-tools not installed; set FIREBASE_TOOLS_DIR to run this check");
    return;
  }
  const read = (...p) => readFileSync(join(dir, "lib", "emulator", ...p), "utf8");
  const hub = read("hub.js");
  const ui = read("ui.js");
  const controller = read("controller.js");
  const constants = read("constants.js");

  assert.match(hub, /const dir = os\.tmpdir\(\);/);
  assert.match(hub, /const filename = `hub-\$\{projectId\}\.json`;/);
  assert.match(hub, /return \{\s*version,\s*origins,\s*pid: process\.pid,\s*\};/);
  assert.match(hub, /fs\.writeFileSync\(locatorPath, JSON\.stringify\(this\.buildLocator\(\)\)\)/);
  assert.match(hub, /if \(prevLocator && prevLocator\.pid && isProcessLive\(prevLocator\.pid\)\) \{[\s\S]*?return;/);
  assert.match(hub, /app\.get\("\/", \(req, res\) => \{\s*res\.json\(\{\s*\.\.\.this\.buildLocator\(\),/);
  assert.match(hub, /EmulatorHub\.PATH_EMULATORS = "\/emulators";/);

  assert.match(ui, /app\.get\("\/api\/config"/);
  assert.match(ui, /const json = \{\s*projectId,/);
  assert.match(ui, /hub\.getRunningEmulatorsMapping\(\)/);

  assert.match(controller, /new hub_1\.EmulatorHub\(\{\s*projectId,/);
  assert.match(controller, /new ui_1\.EmulatorUI\(\{\s*projectId,/);
  assert.match(controller, /if \(name === types_1\.Emulators\.HUB\) \{\s*return true;/);

  // Why firebase.json must pin hub and ui: unpinned, the CLI moves them.
  assert.match(constants, /FIND_AVAILBLE_PORT_BY_DEFAULT = \{\s*ui: true,\s*hub: true,/);
});
