// Process-wide network allowlist for the emulator seeder. Installed before
// firebase-admin is loaded:
//  - every TCP connect (net, tls, http, https, http2, fetch/undici, grpc-js
//    all reach net.Socket.prototype.connect) must target 127.0.0.1 or ::1 on
//    an emulator port, otherwise the socket is destroyed before any lookup or
//    connection happens;
//  - DNS lookups / queries through node:dns are refused for anything but
//    loopback literals.
// Scope is this process's net and dns modules only. Not covered: UDP
// (dgram), native addons, raw process.binding handles, worker threads (their
// built-ins are separate instances), child processes, and code preloaded
// before this module (NODE_OPTIONS=--require / --import). The real-library
// tests in seed_emulator_egress.test.mjs exercise the net/dns paths. The two
// child-process paths in google-auth-library / google-gax stay unreachable
// because seed-emulator-guards.mjs pins GOOGLE_CLOUD_PROJECT (no
// `gcloud config config-helper`) and refuses
// GOOGLE_API_USE_CLIENT_CERTIFICATE (no cert_provider_command).
import dns from "node:dns";
import net from "node:net";
import { syncBuiltinESMExports } from "node:module";
import { promisify } from "node:util";

export const EGRESS_BLOCKED = "SEED_EGRESS_BLOCKED";
export const LOOPBACK_ADDRESSES = new Set(["127.0.0.1", "::1"]);

// Reserved TEST-NET-1 address (RFC 5737); used only for the self-test, which
// is refused before any packet is sent.
const SELF_TEST_TARGET = { host: "192.0.2.1", port: 9 };

const RESOLVE_METHODS = [
  "resolve",
  "resolve4",
  "resolve6",
  "resolveAny",
  "resolveCaa",
  "resolveCname",
  "resolveMx",
  "resolveNaptr",
  "resolveNs",
  "resolvePtr",
  "resolveSoa",
  "resolveSrv",
  "resolveTxt",
  "reverse",
  "lookupService",
];

export class EgressBlockedError extends Error {
  constructor(target) {
    super(`Blocked non-emulator network access: ${describeTarget(target)}.`);
    this.code = EGRESS_BLOCKED;
    this.target = target;
  }
}

function describeTarget(target) {
  if (target.kind === "dns") return `DNS ${target.method}(${JSON.stringify(target.host)})`;
  if (target.path !== undefined) return `socket path ${JSON.stringify(target.path)}`;
  return `TCP ${JSON.stringify(target.host)}:${target.port}`;
}

/** Mirrors net.Socket#connect argument forms (incl. Node's normalized array). */
export function connectTarget(args) {
  let first = args[0];
  if (Array.isArray(first)) first = first[0];
  if (first !== null && typeof first === "object") {
    // Same test as net.Socket#connect: a truthy `path` means a pipe/socket path.
    if (first.path) return { kind: "tcp", path: String(first.path) };
    return { kind: "tcp", host: first.host ?? "localhost", port: Number(first.port) };
  }
  if (typeof first === "number" || (typeof first === "string" && /^\d+$/.test(first))) {
    return {
      kind: "tcp",
      host: typeof args[1] === "string" ? args[1] : "localhost",
      port: Number(first),
    };
  }
  return { kind: "tcp", path: String(first) };
}

/** null when allowed, otherwise the refusal reason. */
export function connectVerdict(target, allowedPorts) {
  if (target.path !== undefined) return "socket paths are not allowed";
  if (!LOOPBACK_ADDRESSES.has(target.host)) return "host is not a loopback address literal";
  if (!allowedPorts.has(target.port)) return "port is not an emulator port";
  return null;
}

let installed = null;

/**
 * Installs the allowlist once per process. Returns a handle exposing the
 * recorded refusals and a self-test proving the hooks are active.
 */
export function installEgressGuard({ allowedPorts }) {
  if (installed !== null) throw new Error("Egress guard is already installed.");
  const ports = new Set(allowedPorts);
  for (const port of ports) {
    if (!Number.isInteger(port) || port <= 0 || port >= 65536) {
      throw new Error(`Invalid allowed port ${JSON.stringify(port)}.`);
    }
  }

  const attempts = [];
  let selfTesting = false;
  const block = (target) => {
    attempts.push({ ...target, selfTest: selfTesting });
    return new EgressBlockedError(target);
  };

  const originalConnect = net.Socket.prototype.connect;
  function guardedConnect(...args) {
    const target = connectTarget(args);
    if (connectVerdict(target, ports) !== null) {
      const error = block(target);
      process.nextTick(() => this.destroy(error));
      return this;
    }
    return originalConnect.apply(this, args);
  }
  net.Socket.prototype.connect = guardedConnect;

  const originalLookup = dns.lookup;
  const originalPromisesLookup = dns.promises.lookup;
  function guardedLookup(hostname, options, callback) {
    const cb = typeof options === "function" ? options : callback;
    if (LOOPBACK_ADDRESSES.has(hostname)) return originalLookup.apply(dns, arguments);
    const error = block({ kind: "dns", method: "lookup", host: hostname });
    process.nextTick(() => cb(error));
    return undefined;
  }
  async function guardedPromisesLookup(hostname, options) {
    if (LOOPBACK_ADDRESSES.has(hostname)) return originalPromisesLookup.call(dns.promises, hostname, options);
    throw block({ kind: "dns", method: "lookup", host: hostname });
  }
  guardedLookup[promisify.custom] = guardedPromisesLookup;
  dns.lookup = guardedLookup;
  dns.promises.lookup = guardedPromisesLookup;

  const callbackBlocker = (method) =>
    function blockedResolve(hostname, ...rest) {
      const cb = rest.reverse().find((value) => typeof value === "function");
      const error = block({ kind: "dns", method, host: hostname });
      if (cb) process.nextTick(() => cb(error));
      return undefined;
    };
  const promiseBlocker = (method) =>
    async function blockedResolve(hostname) {
      throw block({ kind: "dns", method, host: hostname });
    };
  for (const method of RESOLVE_METHODS) {
    if (typeof dns[method] === "function") dns[method] = callbackBlocker(method);
    if (typeof dns.Resolver.prototype[method] === "function") {
      dns.Resolver.prototype[method] = callbackBlocker(method);
    }
    if (typeof dns.promises[method] === "function") dns.promises[method] = promiseBlocker(method);
    if (typeof dns.promises.Resolver.prototype[method] === "function") {
      dns.promises.Resolver.prototype[method] = promiseBlocker(method);
    }
  }
  syncBuiltinESMExports();

  const isActive = () =>
    net.Socket.prototype.connect === guardedConnect &&
    dns.lookup === guardedLookup &&
    dns.promises.lookup === guardedPromisesLookup;

  async function selfTest() {
    if (!isActive()) return false;
    selfTesting = true;
    try {
      const socketBlocked = await new Promise((resolve) => {
        const socket = net.connect(SELF_TEST_TARGET);
        const timer = setTimeout(() => {
          socket.destroy();
          resolve(false);
        }, 2000);
        socket.once("connect", () => {
          clearTimeout(timer);
          socket.destroy();
          resolve(false);
        });
        socket.once("error", (error) => {
          clearTimeout(timer);
          resolve(error?.code === EGRESS_BLOCKED);
        });
      });
      let dnsBlocked = false;
      try {
        await dns.promises.lookup("seed-self-test.invalid");
      } catch (error) {
        dnsBlocked = error?.code === EGRESS_BLOCKED;
      }
      return socketBlocked && dnsBlocked;
    } finally {
      selfTesting = false;
    }
  }

  installed = {
    isActive,
    selfTest,
    blockedAttempts: () => attempts.filter((a) => !a.selfTest).map(({ selfTest: _s, ...a }) => a),
  };
  return installed;
}
