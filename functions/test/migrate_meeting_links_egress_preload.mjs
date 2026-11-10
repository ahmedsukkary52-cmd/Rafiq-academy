// Preloaded (`node --import`) into migrate-meeting-links.mjs CLI runs started
// by the B14 migration tests. Independent of seed-emulator-egress.mjs (the
// script installs that one itself), so a CLI child has two separate network
// barriers:
//  - every TCP connect must target 127.0.0.1 / ::1 on a port listed in
//    B14_MIGRATION_PRELOAD_PORTS, otherwise the socket is destroyed before it
//    connects; non-loopback DNS lookups are refused;
//  - with B14_MIGRATION_PRELOAD_NO_ADMIN=1, loading firebase-admin or any
//    Google Cloud client module throws before resolution, both through
//    CommonJS require (Module._load) and ESM import (module.register resolve
//    hook, Node >= 20.6), proving a run never reached the SDK.
// On exit it reports the number of refused attempts on stderr (never targets).
// Works on Node 20.6 and later, including the Node 22 runtime in
// functions/package.json engines; it refuses to
// run rather than start without a barrier.
import dns from "node:dns";
import fs from "node:fs";
import net from "node:net";
import Module, { syncBuiltinESMExports } from "node:module";

const LOOPBACK = new Set(["127.0.0.1", "::1"]);
const ports = new Set(
  (process.env.B14_MIGRATION_PRELOAD_PORTS ?? "")
    .split(",")
    .filter(Boolean)
    .map(Number),
);
let blocked = 0;

const refusal = () => Object.assign(new Error("B14 preload refused a non-emulator connection."), { code: "B14_PRELOAD_BLOCKED" });

const originalConnect = net.Socket.prototype.connect;
net.Socket.prototype.connect = function preloadConnect(...args) {
  let first = Array.isArray(args[0]) ? args[0][0] : args[0];
  let host;
  let port;
  if (first !== null && typeof first === "object") {
    if (first.path) host = null;
    else {
      host = first.host ?? "localhost";
      port = Number(first.port);
    }
  } else if (typeof first === "number" || (typeof first === "string" && /^\d+$/.test(first))) {
    host = typeof args[1] === "string" ? args[1] : "localhost";
    port = Number(first);
  } else {
    host = null;
  }
  if (host === null || !LOOPBACK.has(host) || !ports.has(port)) {
    blocked += 1;
    process.nextTick(() => this.destroy(refusal()));
    return this;
  }
  return originalConnect.apply(this, args);
};

const originalLookup = dns.lookup;
dns.lookup = function preloadLookup(hostname, options, callback) {
  const cb = typeof options === "function" ? options : callback;
  if (LOOPBACK.has(hostname)) return originalLookup.apply(dns, arguments);
  blocked += 1;
  process.nextTick(() => cb(refusal()));
  return undefined;
};
const originalPromisesLookup = dns.promises.lookup;
dns.promises.lookup = async function preloadPromisesLookup(hostname, options) {
  if (LOOPBACK.has(hostname)) return originalPromisesLookup.call(dns.promises, hostname, options);
  blocked += 1;
  throw refusal();
};
syncBuiltinESMExports();

const SDK_SPECIFIER = "^(firebase-admin|firebase-functions|@google-cloud\\/|google-gax|google-auth-library)";
const ATTEMPTED = "preload: firebase-admin load attempted\n";
const REFUSED = "firebase-admin must not be loaded in this run";

if (process.env.B14_MIGRATION_PRELOAD_NO_ADMIN === "1") {
  if (typeof Module._load !== "function" || typeof Module.register !== "function") {
    throw new Error("B14 preload: this Node version cannot block SDK loading; refusing to run.");
  }
  const sdk = new RegExp(SDK_SPECIFIER);
  const originalLoad = Module._load;
  Module._load = function preloadLoad(request, ...rest) {
    if (typeof request === "string" && sdk.test(request)) {
      fs.writeSync(2, ATTEMPTED);
      throw new Error(REFUSED);
    }
    return originalLoad.call(this, request, ...rest);
  };
  // Runs on the loader hooks thread; writeSync(2) reaches stderr from there.
  const hooks = `
    import { writeSync } from "node:fs";
    const sdk = new RegExp(${JSON.stringify(SDK_SPECIFIER)});
    export async function resolve(specifier, context, nextResolve) {
      if (sdk.test(specifier)) {
        writeSync(2, ${JSON.stringify(ATTEMPTED)});
        throw new Error(${JSON.stringify(REFUSED)});
      }
      return nextResolve(specifier, context);
    }
  `;
  Module.register(`data:text/javascript,${encodeURIComponent(hooks)}`, import.meta.url);
}

process.on("exit", () => {
  if (blocked > 0) console.error(`preload: egress blocked ${blocked} attempt(s)`);
});
