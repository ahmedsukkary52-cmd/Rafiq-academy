// One-off cleanup: removes legacy personal phone / contact fields.
//
//   node scripts/migrate-contact-fields.mjs --project <id>            (dry run)
//   node scripts/migrate-contact-fields.mjs --project <id> --apply \
//     --confirm contact-field-cleanup:<id>
//
// REMOVE  only the top-level keys in CONTACT_FIELD_KEYS (same list as
//         functions/src/privacy/contactInfoPolicy.ts and contactFieldKeys()
//         in firestore.rules), whatever their value, from TARGET_COLLECTIONS.
// PRESERVE every other field, including email, emailSource, name, role,
//         isActive, timestamps and the retired migration's metadata.
// REVIEW  (counted, never modified) contact keys nested inside maps/arrays,
//         other phone-like key names, and the migratedFromUsers marker.
//
// Never deletes a document or an Auth user and never writes any other field.
// Each update carries a lastUpdateTime precondition, so a document changed
// after it was read is skipped, not overwritten. Output is counts plus capped
// UID-shaped document ids; field values are never read into the report.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import {
  bump,
  checkMigrationTarget,
  createIdList,
  credentialFileProjectId,
  parseMigrationArgs,
  safeErrorCode,
} from "./migrate-guards.mjs";

export const SCRIPT_ID = "contact-field-cleanup";

export const CONTACT_FIELD_KEYS = Object.freeze([
  "phone",
  "phoneNumber",
  "mobile",
  "whatsapp",
  "parentPhone",
  "guardianPhone",
]);

/** Collections that held or could hold identity contact data. */
export const TARGET_COLLECTIONS = Object.freeze([
  "users",
  "userPrivate",
  "parentProfiles",
  "studentProfiles",
  "teacherProfiles",
  "supervisorProfiles",
  "studentSearch",
]);

/** Left by the retired adminMigrateUserPhones; not contact data itself. */
export const REVIEW_MARKER_KEYS = Object.freeze(["migratedFromUsers"]);

const PHONE_LIKE_KEY = /phone|mobile|whatsapp|^tel(?:[A-Z_]|$)|contactnumber/i;
const PRINTABLE_KEY = /^[A-Za-z_]{1,40}$/;
const MAX_NESTED_DEPTH = 6;

const hasOwn = (data, key) => Object.prototype.hasOwnProperty.call(data, key);

function isPlainMap(value) {
  return value !== null && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype;
}

function countNestedContactKeys(value, depth) {
  if (depth > MAX_NESTED_DEPTH) return 0;
  let count = 0;
  if (Array.isArray(value)) {
    for (const item of value) count += countNestedContactKeys(item, depth + 1);
  } else if (isPlainMap(value)) {
    for (const [key, inner] of Object.entries(value)) {
      if (CONTACT_FIELD_KEYS.includes(key)) count += 1;
      count += countNestedContactKeys(inner, depth + 1);
    }
  }
  return count;
}

/** Field names only; values are inspected solely to walk nested maps. */
export function classifyDocument(data) {
  const keys = Object.keys(data ?? {});
  let nestedContactKeys = 0;
  for (const key of keys) nestedContactKeys += countNestedContactKeys(data[key], 1);
  return {
    remove: CONTACT_FIELD_KEYS.filter((key) => hasOwn(data, key)),
    reviewMarkers: REVIEW_MARKER_KEYS.filter((key) => hasOwn(data, key)),
    phoneLikeKeys: keys.filter((key) => !CONTACT_FIELD_KEYS.includes(key) && PHONE_LIKE_KEY.test(key)),
    nestedContactKeys,
  };
}

function emptyCollectionReport() {
  return {
    scanned: 0,
    docsWithContactFields: 0,
    fieldsToRemove: Object.fromEntries(CONTACT_FIELD_KEYS.map((key) => [key, 0])),
    docsUpdated: 0,
    skippedChangedSinceRead: 0,
    errors: {},
    review: {
      docsWithMigratedFromUsersMarker: 0,
      docsWithNestedContactKeys: 0,
      phoneLikeKeyNames: {},
      docIds: createIdList(),
    },
  };
}

/**
 * Scans every target collection in document-id order. In "apply" mode each
 * document with contact keys gets one update deleting exactly those keys.
 */
export async function runContactFieldCleanup({
  db,
  mode,
  FieldValue,
  documentId,
  collections = TARGET_COLLECTIONS,
  pageSize = 300,
}) {
  if (mode !== "dry-run" && mode !== "apply") throw new Error("mode must be dry-run or apply");
  const report = {
    script: SCRIPT_ID,
    mode,
    classification: {
      remove: [...CONTACT_FIELD_KEYS],
      preserve: "every other field",
      reviewOnly: ["nested contact keys", "other phone-like key names", ...REVIEW_MARKER_KEYS],
    },
    collections: {},
    totals: { scanned: 0, docsWithContactFields: 0, fieldsToRemove: 0, docsUpdated: 0, skippedChangedSinceRead: 0, errors: 0 },
  };

  for (const name of collections) {
    const c = emptyCollectionReport();
    report.collections[name] = c;
    let last = null;
    for (;;) {
      let query = db.collection(name).orderBy(documentId).limit(pageSize);
      if (last) query = query.startAfter(last);
      const page = await query.get();
      for (const doc of page.docs) {
        c.scanned += 1;
        const found = classifyDocument(doc.data());
        const needsReview = found.nestedContactKeys > 0 || found.phoneLikeKeys.length > 0 || found.reviewMarkers.length > 0;
        if (found.reviewMarkers.length > 0) c.review.docsWithMigratedFromUsersMarker += 1;
        if (found.nestedContactKeys > 0) c.review.docsWithNestedContactKeys += 1;
        for (const key of found.phoneLikeKeys) {
          bump(c.review.phoneLikeKeyNames, PRINTABLE_KEY.test(key) ? key : "<unprintable>");
        }
        if (needsReview) c.review.docIds.add(doc.id);
        if (found.remove.length === 0) continue;

        c.docsWithContactFields += 1;
        for (const key of found.remove) c.fieldsToRemove[key] += 1;
        if (mode !== "apply") continue;

        const update = Object.fromEntries(found.remove.map((key) => [key, FieldValue.delete()]));
        try {
          await doc.ref.update(update, { lastUpdateTime: doc.updateTime });
          c.docsUpdated += 1;
        } catch (error) {
          const code = safeErrorCode(error);
          if (code === "failed-precondition" || code === "not-found") c.skippedChangedSinceRead += 1;
          else bump(c.errors, code);
        }
      }
      if (page.docs.length < pageSize) break;
      last = page.docs[page.docs.length - 1];
    }

    const t = report.totals;
    t.scanned += c.scanned;
    t.docsWithContactFields += c.docsWithContactFields;
    t.fieldsToRemove += Object.values(c.fieldsToRemove).reduce((a, b) => a + b, 0);
    t.docsUpdated += c.docsUpdated;
    t.skippedChangedSinceRead += c.skippedChangedSinceRead;
    t.errors += Object.values(c.errors).reduce((a, b) => a + b, 0);
  }
  return report;
}

async function main() {
  const env = process.env;
  const args = parseMigrationArgs(process.argv.slice(2));
  const credential = credentialFileProjectId(env, (path) => readFileSync(path, "utf8"));
  const { problems, mode } = checkMigrationTarget({
    scriptId: SCRIPT_ID,
    args,
    env,
    credentialProjectId: credential.projectId,
    needsAuth: false,
  });
  if (credential.problem) problems.push(credential.problem);
  if (problems.length > 0) {
    for (const problem of problems) console.error(`refused: ${problem}`);
    process.exit(2);
  }

  const { initializeApp } = await import("firebase-admin/app");
  const { getFirestore, FieldValue, FieldPath } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: args.project });
  if (app.options.projectId !== args.project) {
    console.error("refused: firebase-admin resolved a different project.");
    process.exit(2);
  }
  console.error(`${SCRIPT_ID}: ${mode} on ${args.project}`);
  const report = await runContactFieldCleanup({
    db: getFirestore(app),
    mode,
    FieldValue,
    documentId: FieldPath.documentId(),
  });
  console.log(JSON.stringify({ project: args.project, ...report }, null, 2));
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main().catch((error) => {
    console.error(`${SCRIPT_ID} failed: ${safeErrorCode(error)}`);
    process.exit(1);
  });
}
