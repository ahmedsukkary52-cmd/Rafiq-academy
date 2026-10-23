// Read-only contact-data audit (Stage 1: isolated demo emulator only).
//
//   node scripts/migrate-audit-contact-data.mjs                  (plan only)
//   node scripts/migrate-audit-contact-data.mjs --project demo-rafiq-rules \
//     --scan --confirm contact-data-audit:demo-rafiq-rules
//
// Without --scan it prints the scan plan and never loads firebase-admin or
// opens a connection. A scan is refused for every live project in this
// phase; it needs the demo project, CONTACT_AUDIT_EMULATOR_OPT_IN=1, and
// CONTACT_AUDIT_PINNED_PORTS="<firestore>,<hub>" (non-default ports) matching
// FIRESTORE_EMULATOR_HOST / FIREBASE_EMULATOR_HUB exactly. Before
// firebase-admin loads, an egress guard limits the process to those two
// loopback ports and the hub must report Firestore on the pinned port.
//
// Firestore only: no Auth, no Storage. The scanner sees Firestore through
// readOnlyStore(), which exposes collection names, document pages and
// subcollection names; any other property access throws. Output is
// aggregate counts on stdout with safe collection names and normalized
// field paths; no values, document ids or UIDs. Nothing is written anywhere.
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { CONTACT_FIELD_KEYS, TARGET_COLLECTIONS } from "./migrate-contact-fields.mjs";
import { checkMigrationTarget, confirmationToken, safeErrorCode } from "./migrate-guards.mjs";
import { installEgressGuard } from "./seed-emulator-egress.mjs";

export const SCRIPT_ID = "contact-data-audit";

/** Stage 1: scans run only against this isolated demo emulator project. */
export const AUDIT_EMULATOR_PROJECTS = Object.freeze(["demo-rafiq-rules"]);

const DEFAULT_EMULATOR_PORTS = new Set([4000, 4400, 4500, 5000, 5001, 8080, 8085, 9000, 9099, 9150, 9199, 9299, 9499]);

/** Allowed business data: academySettings/paymentPublic.vodafoneCashDestination. */
export const BUSINESS_DESTINATION = Object.freeze({
  collection: "academySettings",
  docId: "paymentPublic",
  field: "vodafoneCashDestination",
});

export const CATEGORY = Object.freeze({
  approvedKeyInCleanupScope: "approvedKeyInCleanupScope",
  approvedKeyOutsideCleanupScope: "approvedKeyOutsideCleanupScope",
  approvedKeyNested: "approvedKeyNested",
  approvedKeyInArray: "approvedKeyInArray",
  alternativeKeyName: "alternativeKeyName",
  textPhoneNumber: "textPhoneNumber",
  textPhoneLink: "textPhoneLink",
  textWhatsappLink: "textWhatsappLink",
  numericPhoneShaped: "numericPhoneShaped",
  emailField: "emailField",
  emailShapedText: "emailShapedText",
  businessConfigReview: "businessConfigReview",
});

export const METHOD = Object.freeze({
  exactKeyName: "exactKeyName",
  keyNamePattern: "keyNamePattern",
  policyDetector: "policyDetector",
  digitPattern: "digitPattern",
  emailPattern: "emailPattern",
});

export const LIMITATIONS = Object.freeze([
  "Findings are phone- or email-shaped, not proven personal; synthetic or demo data in a project counts the same.",
  "False positives: academy hotlines, reference/transaction numbers, long ids and digit runs in dates.",
  "False negatives: spelled-out or Arabic-word numbers, wider separators, numbers split across fields, other messaging handles, encoded payloads.",
  "Images, PDFs and audio (e.g. payment receipts) are never inspected; Storage is out of scope in this phase.",
  "Firebase Auth records (phoneNumber, email) are not counted in this phase.",
  "Strings are inspected up to 10000 characters; references, bytes, timestamps and geo points are skipped.",
  "Subcollections deeper than --max-depth and values nested deeper than 8 levels are not inspected (counted).",
  "Map keys that may be identifiers are reported as {key}; a real field name can be hidden this way.",
]);

const ALTERNATIVE_KEY = /phone|mobile|whatsapp|^tel(?:[A-Z_]|$)|contactnumber/i;
const EMAIL_KEY = /^e-?mail$|email$|^email/i;
const EMAIL_SHAPED = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/;
const PHONE_SHAPED_INTEGER = /^(?:0?5\d{8}|9665\d{8}|1[0125]\d{8}|201[0125]\d{8})$/;
const SAFE_NAME = /^[A-Za-z][A-Za-z0-9_]{0,63}$/;
const SAFE_KEY = /^[A-Za-z_][A-Za-z0-9_]{0,39}$/;
const MAX_STRING = 10000;
const MAX_VALUE_DEPTH = 8;

// ── invocation gate (pure) ─────────────────────────────────────────────────

/** Returns { problems, mode: "plan" | "scan" | null, config }. Never echoes values. */
export function checkAuditInvocation({ argv, env }) {
  const problems = [];
  const opts = { project: null, scan: false, confirm: null, maxDepth: 3 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      problems.push(`Unexpected positional argument #${i + 1}.`);
      continue;
    }
    const eq = arg.indexOf("=");
    const flag = eq === -1 ? arg : arg.slice(0, eq);
    const inline = eq === -1 ? undefined : arg.slice(eq + 1);
    const value = () => {
      if (inline !== undefined) return inline;
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) return null;
      i += 1;
      return next;
    };
    switch (flag) {
      case "--project":
        opts.project = value();
        if (opts.project === null) problems.push("--project needs a value.");
        break;
      case "--confirm":
        opts.confirm = value();
        if (opts.confirm === null) problems.push("--confirm needs a value.");
        break;
      case "--scan":
        if (inline !== undefined) problems.push("--scan takes no value.");
        opts.scan = true;
        break;
      case "--max-depth": {
        const n = Number(value());
        if (!Number.isInteger(n) || n < 1 || n > 5) problems.push("--max-depth must be an integer from 1 to 5.");
        else opts.maxDepth = n;
        break;
      }
      case "--apply":
      case "--dry-run":
        problems.push(`${flag} does not exist: the audit is read-only.`);
        break;
      case "--auth":
      case "--storage":
        problems.push(`${flag} is not approved in this phase.`);
        break;
      default:
        problems.push(/^--[a-z-]{1,30}$/.test(flag) ? `Unknown flag ${flag}.` : "Unknown flag.");
    }
  }

  if (!opts.scan) {
    if (opts.confirm !== null) problems.push("--confirm is only accepted together with --scan.");
    return { problems, mode: problems.length ? null : "plan", config: opts };
  }

  const project = opts.project;
  if (!project) {
    problems.push("--scan needs --project.");
  } else if (!AUDIT_EMULATOR_PROJECTS.includes(project)) {
    problems.push(
      /^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(project) && !project.startsWith("demo-")
        ? "Live Firebase projects are refused in this phase; only the isolated demo emulator may be scanned."
        : "--project is not an approved isolated emulator project.",
    );
  }
  if (project && opts.confirm !== confirmationToken(SCRIPT_ID, project)) {
    problems.push(`--scan needs --confirm ${confirmationToken(SCRIPT_ID, project)}`);
  }

  // Shared guards: env/FIREBASE_CONFIG/credential project mismatch, emulator/live mixing.
  if (project) {
    const shared = checkMigrationTarget({
      scriptId: SCRIPT_ID,
      args: { project, apply: false, dryRun: false, confirm: null, problems: [] },
      env,
      credentialProjectId: null,
      needsAuth: false,
    });
    problems.push(...shared.problems);
  }

  if (env.GOOGLE_APPLICATION_CREDENTIALS) {
    problems.push("GOOGLE_APPLICATION_CREDENTIALS must be unset; the emulator audit never uses credentials.");
  }
  if (env.CONTACT_AUDIT_EMULATOR_OPT_IN !== "1") {
    problems.push("CONTACT_AUDIT_EMULATOR_OPT_IN=1 is required for an emulator scan.");
  }
  const pins = String(env.CONTACT_AUDIT_PINNED_PORTS ?? "").split(",").map(Number);
  const portsValid = pins.length === 2 && pins.every((p) => Number.isInteger(p) && p >= 1024 && p <= 65535);
  if (!portsValid) {
    problems.push("CONTACT_AUDIT_PINNED_PORTS must be \"<firestorePort>,<hubPort>\".");
  } else {
    const [firestorePort, hubPort] = pins;
    if (pins.some((p) => DEFAULT_EMULATOR_PORTS.has(p))) {
      problems.push("Pinned ports must not be default emulator ports (possibly shared).");
    }
    if (firestorePort === hubPort) problems.push("Pinned ports must be distinct.");
    if (env.FIRESTORE_EMULATOR_HOST !== `127.0.0.1:${firestorePort}`) {
      problems.push("FIRESTORE_EMULATOR_HOST does not match the pinned Firestore port on 127.0.0.1.");
    }
    if (env.FIREBASE_EMULATOR_HUB !== `127.0.0.1:${hubPort}`) {
      problems.push("FIREBASE_EMULATOR_HUB does not match the pinned hub port on 127.0.0.1.");
    }
    opts.firestorePort = firestorePort;
    opts.hubPort = hubPort;
  }

  return { problems, mode: problems.length ? null : "scan", config: opts };
}

export function buildPlan(config) {
  return {
    script: SCRIPT_ID,
    mode: "plan",
    connects: false,
    project: config.project && AUDIT_EMULATOR_PROJECTS.includes(config.project) ? config.project : null,
    scope: {
      firestore: `every top-level collection and subcollections up to depth ${config.maxDepth}`,
      auth: "disabled (not approved)",
      storage: "disabled (not approved)",
      writes: "none (read-only store; output to stdout only)",
    },
    categories: Object.values(CATEGORY),
    methods: Object.values(METHOD),
    cleanupScope: { keys: [...CONTACT_FIELD_KEYS], collections: [...TARGET_COLLECTIONS] },
    businessDestination: `${BUSINESS_DESTINATION.collection}/${BUSINESS_DESTINATION.docId}.${BUSINESS_DESTINATION.field} is counted as allowed, never as personal`,
    estimatedReads: "one read per document plus one subcollection listing per document (unknown until scanned)",
    requiredForScan: [
      `--project (one of: ${AUDIT_EMULATOR_PROJECTS.join(", ")})`,
      "--scan",
      "--confirm contact-data-audit:<project>",
      "CONTACT_AUDIT_EMULATOR_OPT_IN=1",
      "CONTACT_AUDIT_PINNED_PORTS=<firestore>,<hub> matching FIRESTORE_EMULATOR_HOST and FIREBASE_EMULATOR_HUB",
    ],
    limitations: [...LIMITATIONS],
  };
}

// ── read-only store ────────────────────────────────────────────────────────

export class ReadOnlyViolation extends Error {
  constructor(what) {
    super(`${what} is not available to the read-only audit.`);
    this.code = "read-only-violation";
  }
}

function locked(target, label) {
  const frozen = Object.freeze(target);
  return new Proxy(frozen, {
    get(t, prop) {
      if (typeof prop === "symbol" || prop === "then") return undefined;
      if (!Object.prototype.hasOwnProperty.call(t, prop)) throw new ReadOnlyViolation(`${label}.${prop}`);
      return t[prop];
    },
    set(_t, prop) {
      throw new ReadOnlyViolation(`assigning ${label}.${String(prop)}`);
    },
    defineProperty(_t, prop) {
      throw new ReadOnlyViolation(`defining ${label}.${String(prop)}`);
    },
    deleteProperty(_t, prop) {
      throw new ReadOnlyViolation(`deleting ${label}.${String(prop)}`);
    },
    setPrototypeOf() {
      throw new ReadOnlyViolation(`re-prototyping ${label}`);
    },
  });
}

/**
 * The only Firestore surface the scanner ever receives. Document views expose
 * id (internal, never reported), data() and subcollections(); no references.
 */
export function readOnlyStore(db, documentId) {
  const cursors = new WeakMap();
  const view = (snap) =>
    locked(
      {
        id: snap.id,
        data: () => snap.data(),
        subcollections: async () => (await snap.ref.listCollections()).map((c) => c.id),
      },
      "document",
    );
  return locked(
    {
      collectionNames: async () => (await db.listCollections()).map((c) => c.id),
      page: async (path, cursor, pageSize) => {
        let query = db.collection(path).orderBy(documentId).limit(pageSize);
        if (cursor) query = query.startAfter(cursors.get(cursor));
        const snap = await query.get();
        const last = snap.docs[snap.docs.length - 1];
        let next = null;
        if (last && snap.docs.length === pageSize) {
          next = Object.freeze({});
          cursors.set(next, last);
        }
        return locked({ docs: snap.docs.map(view), next }, "page");
      },
    },
    "store",
  );
}

// ── analysis (pure) ────────────────────────────────────────────────────────

const isPlainMap = (v) => v !== null && typeof v === "object" && Object.getPrototypeOf(v) === Object.prototype;

export function safeCollectionName(name) {
  return SAFE_NAME.test(name) ? name : "<unprintable>";
}

/** A map key, or {key} when it could be an identifier or carry contact data. */
export function safeKey(key, { knownIds, detect }) {
  if (!SAFE_KEY.test(key)) return "{key}";
  if (/\d{4,}/.test(key)) return "{key}";
  if (key.length >= 16 && /\d/.test(key) && /[A-Z]/.test(key) && /[a-z]/.test(key)) return "{key}";
  if (knownIds.has(key)) return "{key}";
  if (EMAIL_SHAPED.test(key) || detect(key) !== null) return "{key}";
  return key;
}

export function isPhoneShapedInteger(n) {
  return Number.isSafeInteger(n) && n > 0 && PHONE_SHAPED_INTEGER.test(String(n));
}

/**
 * Findings for one document. Returns { findings: [{fieldPath, category, method}],
 * businessDestinations, stringsTruncated, depthLimitHits }.
 */
export function analyzeDocument({ data, topCollection, isTopLevel, docId, detect, knownIds }) {
  const out = { findings: [], businessDestinations: 0, stringsTruncated: 0, depthLimitHits: 0 };
  const inCleanupScope = isTopLevel && TARGET_COLLECTIONS.includes(topCollection);
  const businessConfig = isTopLevel && topCollection === BUSINESS_DESTINATION.collection;
  const isPaymentPublic = businessConfig && docId === BUSINESS_DESTINATION.docId;
  const record = (path, category, method) =>
    out.findings.push({
      fieldPath: path,
      category: businessConfig ? CATEGORY.businessConfigReview : category,
      method,
    });

  const walk = (value, path, depth, key, inArray) => {
    if (depth > MAX_VALUE_DEPTH) {
      out.depthLimitHits += 1;
      return;
    }
    if (typeof value === "string") {
      if (key !== null && (CONTACT_FIELD_KEYS.includes(key) || ALTERNATIVE_KEY.test(key))) return;
      const text = value.length > MAX_STRING ? value.slice(0, MAX_STRING) : value;
      if (text.length < value.length) out.stringsTruncated += 1;
      const found = detect(text);
      if (found === "phone_number") record(path, CATEGORY.textPhoneNumber, METHOD.policyDetector);
      else if (found === "phone_link") record(path, CATEGORY.textPhoneLink, METHOD.policyDetector);
      else if (found === "whatsapp_link") record(path, CATEGORY.textWhatsappLink, METHOD.policyDetector);
      if (EMAIL_SHAPED.test(text)) {
        if (key !== null && EMAIL_KEY.test(key)) record(path, CATEGORY.emailField, METHOD.exactKeyName);
        else record(path, CATEGORY.emailShapedText, METHOD.emailPattern);
      }
      return;
    }
    if (typeof value === "number") {
      if (key !== null && (CONTACT_FIELD_KEYS.includes(key) || ALTERNATIVE_KEY.test(key))) return;
      if (isPhoneShapedInteger(value)) record(path, CATEGORY.numericPhoneShaped, METHOD.digitPattern);
      return;
    }
    if (Array.isArray(value)) {
      for (const item of value) walk(item, `${path}[]`, depth + 1, null, true);
      return;
    }
    if (!isPlainMap(value)) return;
    for (const [k, inner] of Object.entries(value)) {
      const segment = safeKey(k, { knownIds, detect });
      const childPath = path ? `${path}.${segment}` : segment;
      const topLevelField = depth === 0;
      if (isPaymentPublic && topLevelField && k === BUSINESS_DESTINATION.field) {
        if (typeof inner === "string" && inner.trim() !== "") out.businessDestinations += 1;
        continue;
      }
      if (CONTACT_FIELD_KEYS.includes(k)) {
        const category = topLevelField
          ? inCleanupScope
            ? CATEGORY.approvedKeyInCleanupScope
            : CATEGORY.approvedKeyOutsideCleanupScope
          : inArray || childPath.includes("[]")
            ? CATEGORY.approvedKeyInArray
            : CATEGORY.approvedKeyNested;
        record(childPath, category, METHOD.exactKeyName);
      } else if (ALTERNATIVE_KEY.test(k)) {
        record(childPath, CATEGORY.alternativeKeyName, METHOD.keyNamePattern);
      }
      walk(inner, childPath, depth + 1, k, inArray);
    }
  };
  walk(data ?? {}, "", 0, null, false);
  return out;
}

// ── scan ───────────────────────────────────────────────────────────────────

/** Walks every collection through the read-only store; returns the aggregate report. */
export async function runContactDataAudit({ store, detect, maxDepth = 3, pageSize = 300 }) {
  const counts = {};
  const collections = {};
  const totals = {
    collectionsScanned: 0,
    documentsScanned: 0,
    documentsWithFindings: 0,
    stringsTruncated: 0,
    valueDepthLimitHits: 0,
    documentsAtMaxDepthNotListed: 0,
  };
  let businessDestinations = 0;
  const knownIds = new Set();

  const scanCollection = async (path, pattern, topCollection, depth) => {
    totals.collectionsScanned += 1;
    const c = (collections[pattern] ??= { documentsScanned: 0, documentsWithFindings: 0 });
    let cursor = null;
    do {
      const page = await store.page(path, cursor, pageSize);
      for (const doc of page.docs) knownIds.add(doc.id);
      for (const doc of page.docs) {
        c.documentsScanned += 1;
        totals.documentsScanned += 1;
        const result = analyzeDocument({
          data: doc.data(),
          topCollection,
          isTopLevel: depth === 1,
          docId: doc.id,
          detect,
          knownIds,
        });
        businessDestinations += result.businessDestinations;
        totals.stringsTruncated += result.stringsTruncated;
        totals.valueDepthLimitHits += result.depthLimitHits;
        if (result.findings.length > 0) {
          c.documentsWithFindings += 1;
          totals.documentsWithFindings += 1;
        }
        for (const f of result.findings) {
          const key = JSON.stringify([pattern, f.fieldPath, f.category, f.method]);
          counts[key] = (Object.hasOwn(counts, key) ? counts[key] : 0) + 1;
        }
        if (depth < maxDepth) {
          for (const sub of (await doc.subcollections()).sort()) {
            await scanCollection(`${path}/${doc.id}/${sub}`, `${pattern}/{}/${safeCollectionName(sub)}`, topCollection, depth + 1);
          }
        } else {
          totals.documentsAtMaxDepthNotListed += 1;
        }
      }
      cursor = page.next;
    } while (cursor);
  };

  const names = (await store.collectionNames()).sort((a, b) => (a === "users" ? -1 : b === "users" ? 1 : a.localeCompare(b)));
  for (const name of names) await scanCollection(name, safeCollectionName(name), name, 1);

  const findings = Object.entries(counts)
    .map(([key, count]) => {
      const [collection, fieldPath, category, method] = JSON.parse(key);
      return { collection, fieldPath, category, method, count };
    })
    .sort((a, b) =>
      a.collection.localeCompare(b.collection) || a.fieldPath.localeCompare(b.fieldPath) || a.category.localeCompare(b.category));
  const byCategory = {};
  for (const f of findings) byCategory[f.category] = (byCategory[f.category] ?? 0) + f.count;

  return {
    script: SCRIPT_ID,
    mode: "scan",
    scope: { auth: "disabled (not approved)", storage: "disabled (not approved)", maxDepth },
    totals,
    allowedBusinessDestination: { count: businessDestinations },
    byCategory,
    collections,
    findings,
    limitations: [...LIMITATIONS],
  };
}

// ── CLI ────────────────────────────────────────────────────────────────────

async function verifyHub(config) {
  const res = await fetch(`http://127.0.0.1:${config.hubPort}/emulators`);
  if (!res.ok) return "the emulator hub did not answer on the pinned port.";
  const listing = await res.json();
  const fs = listing?.firestore;
  if (!fs || fs.port !== config.firestorePort || !["127.0.0.1", "::1"].includes(fs.host)) {
    return "the emulator hub does not report Firestore on the pinned loopback port.";
  }
  if (listing?.hub?.port !== config.hubPort) return "the emulator hub reports a different hub port.";
  return null;
}

async function main() {
  const { problems, mode, config } = checkAuditInvocation({ argv: process.argv.slice(2), env: process.env });
  if (problems.length > 0) {
    for (const problem of problems) console.error(`refused: ${problem}`);
    process.exit(2);
  }
  if (mode === "plan") {
    console.log(JSON.stringify(buildPlan(config), null, 2));
    return;
  }

  process.env.METADATA_SERVER_DETECTION = "none";
  const guard = installEgressGuard({ allowedPorts: [config.firestorePort, config.hubPort] });
  if (!(await guard.selfTest())) {
    console.error("refused: egress guard is not active.");
    process.exit(2);
  }
  const hubProblem = await verifyHub(config).catch(() => "the emulator hub could not be reached.");
  if (hubProblem) {
    console.error(`refused: ${hubProblem}`);
    process.exit(2);
  }

  const here = dirname(fileURLToPath(import.meta.url));
  const policy = await import(pathToFileURL(join(here, "..", "lib", "privacy", "contactInfoPolicy.js")).href);
  const detect = policy.detectContactInfo ?? policy.default?.detectContactInfo;
  if (typeof detect !== "function") {
    console.error("refused: build functions first (lib/privacy/contactInfoPolicy.js missing).");
    process.exit(2);
  }

  const { initializeApp } = await import("firebase-admin/app");
  const { getFirestore, FieldPath } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: config.project }, SCRIPT_ID);
  if (app.options.projectId !== config.project) {
    console.error("refused: firebase-admin resolved a different project.");
    process.exit(2);
  }
  const store = readOnlyStore(getFirestore(app), FieldPath.documentId());
  const report = await runContactDataAudit({ store, detect, maxDepth: config.maxDepth });

  const blocked = guard.blockedAttempts().length;
  if (blocked > 0) {
    console.error(`${SCRIPT_ID}: ${blocked} non-emulator connection attempt(s) were blocked.`);
    process.exit(3);
  }
  console.log(JSON.stringify({ project: config.project, ...report }, null, 2));
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main().catch((error) => {
    console.error(`${SCRIPT_ID} failed: ${safeErrorCode(error)}`);
    process.exit(1);
  });
}
