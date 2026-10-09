/**
 * Network allowlist of the emulator seeder (scripts/seed-emulator-egress.mjs),
 * exercised through the real client libraries in child processes. Every
 * child installs tripwires underneath the guard, so even a broken guard never
 * reaches the network; only servers owned by this test on 127.0.0.1 are
 * contacted. No credentials, no emulator, no real Firebase service.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import http from "node:http";
import net from "node:net";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { connectTarget, connectVerdict, EGRESS_BLOCKED } from "../scripts/seed-emulator-egress.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const probe = join(here, "fixtures", "seed_emulator_egress_probe.mjs");
const emptyHome = mkdtempSync(join(tmpdir(), "seed-egress-home-"));
process.on("exit", () => rmSync(emptyHome, { recursive: true, force: true }));

function childEnv(extra) {
  const env = Object.fromEntries(
    Object.entries(process.env).filter(
      ([k]) =>
        !/^(GOOGLE_APPLICATION_CREDENTIALS|CLOUDSDK_CONFIG|FIREBASE_CONFIG|GCLOUD_PROJECT|GOOGLE_CLOUD_PROJECT|METADATA_SERVER_DETECTION|.*_EMULATOR_HOST|FIREBASE_EMULATOR_HUB|(HTTP|HTTPS|GRPC|ALL)_PROXY)$/i.test(k),
    ),
  );
  return { ...env, APPDATA: emptyHome, HOME: emptyHome, USERPROFILE: emptyHome, ...extra };
}

function runProbe(scenario, extraEnv = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [probe, scenario], {
      cwd: join(here, ".."),
      env: childEnv(extraEnv),
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    const timer = setTimeout(() => child.kill(), 40000);
    child.on("close", (code) => {
      clearTimeout(timer);
      const line = stdout.split(/\r?\n/).find((l) => l.startsWith("PROBE_RESULT "));
      if (!line) return reject(new Error(`${scenario}: no result (exit ${code})\n${stderr}`));
      resolve(JSON.parse(line.slice("PROBE_RESULT ".length)));
    });
  });
}

async function withLocalServer(server, fn) {
  // Children exit abruptly; a reset from them is expected, not a failure.
  server.on("connection", (socket) => socket.on("error", () => {}));
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  try {
    return await fn(server.address().port);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

// ── Pure target parsing ─────────────────────────────────────────────────────

test("connect arguments are parsed for every net.Socket#connect form", () => {
  assert.deepEqual(connectTarget([{ host: "127.0.0.1", port: 8080 }]), { kind: "tcp", host: "127.0.0.1", port: 8080 });
  assert.deepEqual(connectTarget([[{ host: "::1", port: "9099" }, () => {}]]), { kind: "tcp", host: "::1", port: 9099 });
  assert.deepEqual(connectTarget([443, "example.com"]), { kind: "tcp", host: "example.com", port: 443 });
  assert.deepEqual(connectTarget(["443"]), { kind: "tcp", host: "localhost", port: 443 });
  assert.deepEqual(connectTarget([{ port: 80 }]), { kind: "tcp", host: "localhost", port: 80 });
  assert.deepEqual(connectTarget([{ host: "127.0.0.1", port: 8080, path: null }]), {
    kind: "tcp",
    host: "127.0.0.1",
    port: 8080,
  });
  assert.deepEqual(connectTarget([{ path: "/tmp/x.sock", host: "127.0.0.1" }]), { kind: "tcp", path: "/tmp/x.sock" });
  assert.deepEqual(connectTarget(["\\\\.\\pipe\\x"]), { kind: "tcp", path: "\\\\.\\pipe\\x" });
});

test("only loopback literals on allowed ports pass", () => {
  const ports = new Set([8080, 9099, 4400]);
  assert.equal(connectVerdict({ host: "127.0.0.1", port: 8080 }, ports), null);
  assert.equal(connectVerdict({ host: "::1", port: 9099 }, ports), null);
  for (const target of [
    { host: "localhost", port: 8080 },
    { host: "127.0.0.2", port: 8080 },
    { host: "::ffff:127.0.0.1", port: 8080 },
    { host: "0.0.0.0", port: 8080 },
    { host: "127.0.0.1", port: 443 },
    { host: "firestore.googleapis.com", port: 443 },
    { host: "169.254.169.254", port: 80 },
    { path: "\\\\.\\pipe\\x" },
  ]) {
    assert.notEqual(connectVerdict(target, ports), null, JSON.stringify(target));
  }
});

// ── Real libraries, refused before any lookup or connection ─────────────────

function assertRefusedBeforeNetwork(result, scenario) {
  assert.deepEqual(result.tripwire, [], `${scenario}: reached below the guard ${JSON.stringify(result.tripwire)}`);
  assert.ok(result.blocked.length > 0, `${scenario}: guard recorded nothing`);
  for (const attempt of result.blocked) {
    assert.equal(attempt.path, undefined, `${scenario}: blocked as a socket path ${JSON.stringify(attempt)}`);
    assert.equal(typeof attempt.host, "string", `${scenario}: ${JSON.stringify(attempt)}`);
  }
  assert.notEqual(result.outcome, "resolved", scenario);
}

for (const scenario of [
  "net-ip",
  "net-port-args",
  "net-loopback-wrong-port",
  "net-ipv4-mapped",
  "tls-hostname",
  "https-hostname",
  "fetch-hostname",
  "fetch-ip",
  "http2-hostname",
]) {
  test(`node client refused before network: ${scenario}`, async () => {
    const result = await runProbe(scenario, { PROBE_LOCAL_PORT: "40000" });
    assertRefusedBeforeNetwork(result, scenario);
    assert.equal(result.outcome, "rejected", scenario);
    assert.equal(result.code, EGRESS_BLOCKED, `${scenario}: ${result.message}`);
  });
}

test("a hostname that resolves to loopback is still refused (no DNS at all)", async () => {
  await withLocalServer(net.createServer((s) => s.destroy()), async (port) => {
    const result = await runProbe("net-localhost-name", { PROBE_LOCAL_PORT: String(port) });
    assertRefusedBeforeNetwork(result, "net-localhost-name");
    assert.equal(result.code, EGRESS_BLOCKED);
  });
});

test("every DNS entry point is refused, including promisify(dns.lookup)", async () => {
  const result = await runProbe("dns-apis");
  assert.deepEqual(result.tripwire, []);
  assert.deepEqual(result.codes, Array(7).fill(EGRESS_BLOCKED));
});

test("grpc-js (Firestore transport) is refused for hostnames and IPs", async () => {
  for (const scenario of ["grpc-hostname", "grpc-ip"]) {
    const result = await runProbe(scenario);
    assertRefusedBeforeNetwork(result, scenario);
  }
});

test("firebase-admin without emulator hosts cannot reach Google (Auth)", async () => {
  const result = await runProbe("admin-auth-real");
  assertRefusedBeforeNetwork(result, "admin-auth-real");
  assert.equal(result.outcome, "rejected");
});

test("firebase-admin without emulator hosts cannot reach Google (Firestore)", async () => {
  const result = await runProbe("admin-firestore-real");
  assertRefusedBeforeNetwork(result, "admin-firestore-real");
});

test("the runtime self-test passes when the guard is active", async () => {
  const result = await runProbe("self-test");
  assert.equal(result.outcome, "passed");
  assert.equal(result.active, true);
  assert.deepEqual(result.blocked, []);
  assert.deepEqual(result.tripwire, []);
});

// ── Allowed path: loopback emulator ports only ──────────────────────────────

test("a loopback connection on an allowed port goes through", async () => {
  let connections = 0;
  await withLocalServer(
    net.createServer((s) => {
      connections += 1;
      s.destroy();
    }),
    async (port) => {
      const result = await runProbe("allowed-local-tcp", { PROBE_LOCAL_PORT: String(port) });
      assert.equal(result.outcome, "resolved");
      assert.deepEqual(result.blocked, []);
      assert.deepEqual(result.tripwire, []);
    },
  );
  assert.equal(connections, 1);
});

test("firebase-admin Auth uses only the local emulator host with the owner token", async () => {
  const requests = [];
  const server = http.createServer((req, res) => {
    requests.push({ method: req.method, url: req.url, authorization: req.headers.authorization });
    req.resume();
    res.writeHead(400, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: { code: 400, message: "USER_NOT_FOUND" } }));
  });
  await withLocalServer(server, async (port) => {
    const result = await runProbe("admin-auth-emulator", {
      PROBE_LOCAL_PORT: String(port),
      FIREBASE_AUTH_EMULATOR_HOST: `127.0.0.1:${port}`,
    });
    assert.equal(result.outcome, "rejected");
    assert.deepEqual(result.blocked, []);
    assert.deepEqual(result.tripwire, []);
  });
  assert.ok(requests.length > 0);
  for (const r of requests) {
    assert.equal(r.authorization, "Bearer owner");
    assert.match(r.url, /^\/identitytoolkit\.googleapis\.com\/v1\/projects\/demo-rafiq-rules\//);
  }
});

function http2PrefaceServer(prefaces) {
  return net.createServer((socket) => {
    socket.once("data", (chunk) => {
      prefaces.push(chunk.subarray(0, 24).toString("latin1"));
      socket.destroy();
    });
  });
}
const HTTP2_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n";

test("firebase-admin Firestore uses only the local emulator host over cleartext HTTP/2", async () => {
  const prefaces = [];
  await withLocalServer(http2PrefaceServer(prefaces), async (port) => {
    const result = await runProbe("admin-firestore-emulator", {
      PROBE_LOCAL_PORT: String(port),
      FIRESTORE_EMULATOR_HOST: `127.0.0.1:${port}`,
      METADATA_SERVER_DETECTION: "none",
    });
    assert.notEqual(result.outcome, "resolved");
    assert.deepEqual(result.blocked, []);
    assert.deepEqual(result.tripwire, []);
  });
  assert.ok(prefaces.length > 0);
  assert.ok(prefaces.every((p) => p === HTTP2_PREFACE), JSON.stringify(prefaces));
});

test("without METADATA_SERVER_DETECTION=none the Firestore client probes GCE metadata, and the guard blocks it", async () => {
  const prefaces = [];
  await withLocalServer(http2PrefaceServer(prefaces), async (port) => {
    const result = await runProbe("admin-firestore-emulator", {
      PROBE_LOCAL_PORT: String(port),
      FIRESTORE_EMULATOR_HOST: `127.0.0.1:${port}`,
    });
    assert.deepEqual(result.tripwire, []);
    assert.ok(result.blocked.length > 0);
    for (const attempt of result.blocked) {
      assert.ok(["169.254.169.254", "metadata.google.internal.", "metadata.google.internal"].includes(attempt.host), JSON.stringify(attempt));
    }
  });
});
