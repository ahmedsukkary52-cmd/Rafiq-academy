/**
 * WA-17 / Wave A prerequisite indexes contract (no Firebase network/emulator).
 *
 * Authority: docs/production/WAVE_A_IMPLEMENTATION_SPEC.md § WA-17
 * (+ WA-14 studentSearch composites already frozen).
 *
 * Does not invent indexes — only asserts the required Wave A composites.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..", "..");

/**
 * @typedef {{ fieldPath: string, order?: string, arrayConfig?: string }} IndexField
 * @typedef {{ collectionGroup: string, fields: IndexField[] }} FirestoreIndex
 */

/**
 * Deterministic fingerprint: collection|field:ORDER_OR_CONTAINS[+…]
 * @param {FirestoreIndex} index
 */
function indexFingerprint(index) {
  const fields = index.fields.map((f) => {
    if (f.arrayConfig) {
      return `${f.fieldPath}:CONTAINS`;
    }
    return `${f.fieldPath}:${f.order ?? "ASCENDING"}`;
  });
  return `${index.collectionGroup}|${fields.join("+")}`;
}

/**
 * @param {FirestoreIndex[]} indexes
 * @returns {Set<string>}
 */
function fingerprintSet(indexes) {
  return new Set(indexes.map(indexFingerprint));
}

/**
 * Required Wave A composites from WA-17 table + WA-14 studentSearch.
 * paymentAccess status index is optional in WA-17 — not asserted.
 *
 * Sessions: WA-17 lists halaqaId+date / teacherId+startAt; repo composites
 * include startAt as the third field (WA-8/WA-9 query shape).
 */
const REQUIRED = [
  {
    label: "recitationRecords halaqaId ASC + date ASC (AUD-032)",
    collectionGroup: "recitationRecords",
    fields: [
      { fieldPath: "halaqaId", order: "ASCENDING" },
      { fieldPath: "date", order: "ASCENDING" },
    ],
  },
  {
    label: "payments parentId ASC + dueDate DESC (AUD-033)",
    collectionGroup: "payments",
    fields: [
      { fieldPath: "parentId", order: "ASCENDING" },
      { fieldPath: "dueDate", order: "DESCENDING" },
    ],
  },
  {
    label: "sessions halaqaId ASC + date ASC + startAt ASC (WA-8/WA-17)",
    collectionGroup: "sessions",
    fields: [
      { fieldPath: "halaqaId", order: "ASCENDING" },
      { fieldPath: "date", order: "ASCENDING" },
      { fieldPath: "startAt", order: "ASCENDING" },
    ],
  },
  {
    label: "sessions teacherId ASC + date ASC + startAt ASC (WA-8/WA-9/WA-17)",
    collectionGroup: "sessions",
    fields: [
      { fieldPath: "teacherId", order: "ASCENDING" },
      { fieldPath: "date", order: "ASCENDING" },
      { fieldPath: "startAt", order: "ASCENDING" },
    ],
  },
  {
    label: "studentSearch visibleTo CONTAINS + fullNameNormalized ASC (WA-14)",
    collectionGroup: "studentSearch",
    fields: [
      { fieldPath: "visibleTo", arrayConfig: "CONTAINS" },
      { fieldPath: "fullNameNormalized", order: "ASCENDING" },
    ],
  },
  {
    label: "studentSearch halaqaIds CONTAINS + fullNameNormalized ASC (WA-14)",
    collectionGroup: "studentSearch",
    fields: [
      { fieldPath: "halaqaIds", arrayConfig: "CONTAINS" },
      { fieldPath: "fullNameNormalized", order: "ASCENDING" },
    ],
  },
];

test("WA-17 firestore.indexes.json contains every required Wave A composite", () => {
  const raw = JSON.parse(
    readFileSync(join(repoRoot, "firestore.indexes.json"), "utf8"),
  );
  assert.ok(Array.isArray(raw.indexes), "indexes array missing");

  const present = fingerprintSet(raw.indexes);
  const missing = [];

  for (const req of REQUIRED) {
    const fp = indexFingerprint(req);
    if (!present.has(fp)) {
      missing.push(`${req.label} → expected fingerprint: ${fp}`);
    }
  }

  assert.equal(
    missing.length,
    0,
    `WA-17 required composite index(es) missing from firestore.indexes.json:\n${missing.join("\n")}`,
  );
});

test("WA-17 required set is exactly the frozen Wave A contract (no silent shrink)", () => {
  // Guard: if someone edits REQUIRED carelessly, keep the count aligned with
  // WA-17 table mandatory rows + two studentSearch composites.
  assert.equal(
    REQUIRED.length,
    6,
    "REQUIRED list drifted — update only with frozen WA-17/WA-14 authority",
  );
});
