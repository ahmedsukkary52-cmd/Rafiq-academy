// Child process for seed_emulator_egress.test.mjs:
//   node seed_emulator_egress_probe.mjs <scenario>
// Tripwires are installed *underneath* the egress guard: anything that gets
// past the guard is recorded and destroyed before reaching the network, so a
// broken guard fails the test without contacting any real service. Only
// 127.0.0.1:PROBE_LOCAL_PORT (a server owned by the parent test) passes.
import dns from "node:dns";
import http2 from "node:http2";
import https from "node:https";
import { syncBuiltinESMExports } from "node:module";
import net from "node:net";
import tls from "node:tls";
import { promisify } from "node:util";

import { connectTarget, installEgressGuard } from "../../scripts/seed-emulator-egress.mjs";

const scenario = process.argv[2];
const localPort = Number(process.env.PROBE_LOCAL_PORT || 0);
const tripwire = [];

const realConnect = net.Socket.prototype.connect;
net.Socket.prototype.connect = function tripwireConnect(...args) {
  const target = connectTarget(args);
  if (localPort && target.host === "127.0.0.1" && target.port === localPort) {
    return realConnect.apply(this, args);
  }
  tripwire.push({ kind: "tcp", host: target.host, port: target.port, path: target.path });
  process.nextTick(() => this.destroy(new Error("TRIPWIRE")));
  return this;
};
const dnsTripwire = (method) =>
  function tripwireDns(hostname, ...rest) {
    tripwire.push({ kind: "dns", method, host: hostname });
    const cb = rest.reverse().find((v) => typeof v === "function");
    if (cb) process.nextTick(() => cb(new Error("TRIPWIRE")));
  };
const dnsPromiseTripwire = (method) =>
  async function tripwireDns(hostname) {
    tripwire.push({ kind: "dns", method, host: hostname });
    throw new Error("TRIPWIRE");
  };
for (const method of ["lookup", "resolve", "resolve4", "resolve6", "resolveAny", "resolveSrv", "resolveTxt"]) {
  dns[method] = dnsTripwire(method);
  dns.promises[method] = dnsPromiseTripwire(method);
  if (method !== "lookup") {
    dns.Resolver.prototype[method] = dnsTripwire(method);
    dns.promises.Resolver.prototype[method] = dnsPromiseTripwire(method);
  }
}
dns.lookup[promisify.custom] = dnsPromiseTripwire("lookup");
syncBuiltinESMExports();

const guard = installEgressGuard({ allowedPorts: [localPort || 1] });

const settle = (promise, ms = 5000) =>
  Promise.race([
    promise.then(
      (value) => ({ outcome: "resolved", value }),
      (error) => ({ outcome: "rejected", code: error?.code ?? error?.cause?.code ?? null, message: String(error?.message ?? error) }),
    ),
    new Promise((resolve) => setTimeout(() => resolve({ outcome: "timeout" }), ms)),
  ]);

const socketOutcome = (socket) =>
  settle(
    new Promise((resolve, reject) => {
      socket.once("connect", () => {
        socket.destroy();
        resolve("connected");
      });
      socket.once("secureConnect", () => {
        socket.destroy();
        resolve("connected");
      });
      socket.once("error", reject);
    }),
  );

const scenarios = {
  "net-ip": () => socketOutcome(net.connect({ host: "192.0.2.1", port: 443 })),
  "net-port-args": () => socketOutcome(net.connect(443, "192.0.2.1")),
  "net-localhost-name": () => socketOutcome(net.connect({ host: "localhost", port: localPort })),
  "net-loopback-wrong-port": () => socketOutcome(net.connect({ host: "127.0.0.1", port: localPort + 1 })),
  "net-ipv4-mapped": () => socketOutcome(net.connect({ host: "::ffff:127.0.0.1", port: localPort })),
  "tls-hostname": () =>
    socketOutcome(tls.connect({ host: "firestore.googleapis.com", port: 443, servername: "firestore.googleapis.com" })),
  "https-hostname": () =>
    settle(
      new Promise((resolve, reject) => {
        const req = https.get("https://identitytoolkit.googleapis.com/v1/projects", (res) => resolve(res.statusCode));
        req.on("error", reject);
      }),
    ),
  "fetch-hostname": () => settle(fetch("https://firestore.googleapis.com/")),
  "fetch-ip": () => settle(fetch("http://192.0.2.1/")),
  "http2-hostname": () =>
    settle(
      new Promise((resolve, reject) => {
        const session = http2.connect("https://firestore.googleapis.com");
        session.once("connect", () => {
          session.destroy();
          resolve("connected");
        });
        session.once("error", reject);
      }),
    ),
  "dns-apis": async () => {
    const codes = [];
    const capture = async (fn) => {
      try {
        await fn();
        codes.push("resolved");
      } catch (error) {
        codes.push(error?.code ?? "error");
      }
    };
    await capture(() => new Promise((res, rej) => dns.lookup("firestore.googleapis.com", (e, a) => (e ? rej(e) : res(a)))));
    await capture(() => dns.promises.lookup("firestore.googleapis.com", { all: true }));
    await capture(() => promisify(dns.lookup)("identitytoolkit.googleapis.com"));
    await capture(() => new Promise((res, rej) => dns.resolveTxt("_grpc_config.firestore.googleapis.com", (e, a) => (e ? rej(e) : res(a)))));
    await capture(() => dns.promises.resolveTxt("_grpc_config.firestore.googleapis.com"));
    await capture(() => new dns.promises.Resolver().resolve4("firestore.googleapis.com"));
    await capture(() => dns.promises.lookup("localhost"));
    return { outcome: "codes", codes };
  },
  "grpc-hostname": async () => {
    const grpc = await import("@grpc/grpc-js");
    const client = new grpc.Client("firestore.googleapis.com:443", grpc.credentials.createSsl());
    const result = await settle(
      new Promise((resolve, reject) =>
        client.waitForReady(Date.now() + 3000, (error) => (error ? reject(error) : resolve("ready"))),
      ),
      6000,
    );
    client.close();
    return result;
  },
  "grpc-ip": async () => {
    const grpc = await import("@grpc/grpc-js");
    const client = new grpc.Client("192.0.2.1:443", grpc.credentials.createInsecure());
    const result = await settle(
      new Promise((resolve, reject) =>
        client.waitForReady(Date.now() + 3000, (error) => (error ? reject(error) : resolve("ready"))),
      ),
      6000,
    );
    client.close();
    return result;
  },
  "admin-auth-real": async () => {
    const { initializeApp } = await import("firebase-admin/app");
    const { getAuth } = await import("firebase-admin/auth");
    const app = initializeApp({ projectId: "demo-rafiq-rules" }, "probe");
    return settle(getAuth(app).getUser("probe-uid"), 8000);
  },
  "admin-firestore-real": async () => {
    const { initializeApp } = await import("firebase-admin/app");
    const { getFirestore } = await import("firebase-admin/firestore");
    const app = initializeApp({ projectId: "demo-rafiq-rules" }, "probe");
    return settle(getFirestore(app).collection("probe").doc("probe").get(), 8000);
  },
  "allowed-local-tcp": () => socketOutcome(net.connect({ host: "127.0.0.1", port: localPort })),
  "admin-auth-emulator": async () => {
    const { initializeApp } = await import("firebase-admin/app");
    const { getAuth } = await import("firebase-admin/auth");
    const app = initializeApp({ projectId: "demo-rafiq-rules" }, "probe");
    return settle(getAuth(app).getUser("probe-uid"), 8000);
  },
  "admin-firestore-emulator": async () => {
    const { initializeApp } = await import("firebase-admin/app");
    const { getFirestore } = await import("firebase-admin/firestore");
    const app = initializeApp({ projectId: "demo-rafiq-rules" }, "probe");
    return settle(getFirestore(app).collection("probe").doc("probe").get(), 4000);
  },
  "self-test": async () => ({ outcome: (await guard.selfTest()) ? "passed" : "failed", active: guard.isActive() }),
};

const run = scenarios[scenario];
if (!run) {
  console.error(`unknown scenario ${scenario}`);
  process.exit(2);
}
const result = await run();
const { value: _value, ...summary } = result;
process.stdout.write(
  `PROBE_RESULT ${JSON.stringify({ ...summary, blocked: guard.blockedAttempts(), tripwire })}\n`,
);
process.exit(0);
