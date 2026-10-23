// One-off backfill: copies each Firebase Auth email into userPrivate/{uid}.
//
//   node scripts/migrate-email-backfill.mjs --project <id>            (dry run)
//   node scripts/migrate-email-backfill.mjs --project <id> --apply \
//     --confirm email-backfill:<id>
//
// Firebase Auth is the only email source; users/{uid}.email is compared for
// the report but never copied, changed or deleted. Only accounts with a
// users/{uid} profile are backfilled. Writes are limited to
// { email, emailSource: "auth", emailUpdatedAt } and happen only when
// userPrivate/{uid} is missing or has no `email` key:
//   - missing doc      -> create() (fails if it appeared meanwhile)
//   - doc without email -> update() with a lastUpdateTime precondition
// A differing or malformed private email is a conflict and is left alone, as
// is any doc still carrying a contact field (run the contact cleanup first).
// Output is counts plus capped UID lists; emails are never printed.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { CONTACT_FIELD_KEYS } from "./migrate-contact-fields.mjs";
import {
  bump,
  checkMigrationTarget,
  createIdList,
  credentialFileProjectId,
  parseMigrationArgs,
  safeErrorCode,
} from "./migrate-guards.mjs";

export const SCRIPT_ID = "email-backfill";

export const OUTCOME = Object.freeze({
  noAppProfile: "skippedNoAppProfile",
  missingAuthEmail: "missingAuthEmail",
  blockedByContactField: "blockedByContactField",
  alreadyCurrent: "alreadyCurrent",
  conflictDiffers: "conflictPrivateEmailDiffers",
  conflictInvalid: "conflictPrivateEmailInvalid",
  create: "createPrivateDoc",
  addEmail: "addEmailToPrivateDoc",
});

const REVIEW_OUTCOMES = [
  OUTCOME.missingAuthEmail,
  OUTCOME.blockedByContactField,
  OUTCOME.conflictDiffers,
  OUTCOME.conflictInvalid,
];

const hasOwn = (data, key) => Object.prototype.hasOwnProperty.call(data, key);

/** Trimmed non-empty string, else null. */
export function normalizeEmail(raw) {
  if (typeof raw !== "string") return null;
  const value = raw.trim();
  return value.length > 0 ? value : null;
}

const sameEmail = (a, b) => a.toLowerCase() === b.toLowerCase();

/** Decides what to do for one Auth account. Pure. */
export function classifyAccount({ authEmail, userExists, privateExists, privateData }) {
  if (!userExists) return OUTCOME.noAppProfile;
  const email = normalizeEmail(authEmail);
  if (email === null) return OUTCOME.missingAuthEmail;
  if (privateExists) {
    const data = privateData ?? {};
    if (CONTACT_FIELD_KEYS.some((key) => hasOwn(data, key))) return OUTCOME.blockedByContactField;
    if (hasOwn(data, "email")) {
      const existing = normalizeEmail(data.email);
      if (existing === null) return OUTCOME.conflictInvalid;
      return sameEmail(existing, email) ? OUTCOME.alreadyCurrent : OUTCOME.conflictDiffers;
    }
    return OUTCOME.addEmail;
  }
  return OUTCOME.create;
}

/**
 * listAuthUsers: async iterable of { uid, email }. In "apply" mode only
 * create/addEmail outcomes write, and only to userPrivate/{uid}.
 */
export async function runEmailBackfill({ db, listAuthUsers, mode, FieldValue, documentId, pageSize = 300 }) {
  if (mode !== "dry-run" && mode !== "apply") throw new Error("mode must be dry-run or apply");
  const counts = Object.fromEntries(Object.values(OUTCOME).map((o) => [o, 0]));
  const written = { created: 0, emailAdded: 0, skippedChangedSinceRead: 0 };
  const errors = {};
  const legacy = { usersEmailPresent: 0, usersEmailDiffersFromAuth: 0, missingAuthEmailButUsersEmailPresent: 0 };
  const review = Object.fromEntries(
    [...REVIEW_OUTCOMES, "skippedChangedSinceRead", "usersEmailDiffersFromAuth", "usersDocsWithoutAuthAccount"]
      .map((key) => [key, createIdList()]),
  );
  const authUids = new Set();
  let authAccounts = 0;

  for await (const account of listAuthUsers()) {
    authAccounts += 1;
    const uid = account.uid;
    authUids.add(uid);
    const userSnap = await db.collection("users").doc(uid).get();
    const privateRef = db.collection("userPrivate").doc(uid);
    const privateSnap = await privateRef.get();
    const outcome = classifyAccount({
      authEmail: account.email,
      userExists: userSnap.exists,
      privateExists: privateSnap.exists,
      privateData: privateSnap.exists ? privateSnap.data() : null,
    });
    counts[outcome] += 1;
    if (review[outcome]) review[outcome].add(uid);

    if (userSnap.exists) {
      const usersEmail = normalizeEmail(userSnap.data()?.email);
      const authEmail = normalizeEmail(account.email);
      if (usersEmail !== null) {
        legacy.usersEmailPresent += 1;
        if (authEmail === null) legacy.missingAuthEmailButUsersEmailPresent += 1;
        else if (!sameEmail(usersEmail, authEmail)) {
          legacy.usersEmailDiffersFromAuth += 1;
          review.usersEmailDiffersFromAuth.add(uid);
        }
      }
    }

    if (mode !== "apply" || (outcome !== OUTCOME.create && outcome !== OUTCOME.addEmail)) continue;
    const fields = {
      email: normalizeEmail(account.email),
      emailSource: "auth",
      emailUpdatedAt: FieldValue.serverTimestamp(),
    };
    try {
      if (outcome === OUTCOME.create) {
        await privateRef.create(fields);
        written.created += 1;
      } else {
        await privateRef.update(fields, { lastUpdateTime: privateSnap.updateTime });
        written.emailAdded += 1;
      }
    } catch (error) {
      const code = safeErrorCode(error);
      if (code === "already-exists" || code === "failed-precondition" || code === "not-found") {
        written.skippedChangedSinceRead += 1;
        review.skippedChangedSinceRead.add(uid);
      } else {
        bump(errors, code);
      }
    }
  }

  let usersDocs = 0;
  let last = null;
  for (;;) {
    let query = db.collection("users").orderBy(documentId).limit(pageSize);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    for (const doc of page.docs) {
      usersDocs += 1;
      if (!authUids.has(doc.id)) review.usersDocsWithoutAuthAccount.add(doc.id);
    }
    if (page.docs.length < pageSize) break;
    last = page.docs[page.docs.length - 1];
  }

  return {
    script: SCRIPT_ID,
    mode,
    authAccounts,
    usersDocs,
    outcomes: counts,
    written,
    errors,
    legacyUsersEmail: legacy,
    review,
  };
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
    needsAuth: true,
  });
  if (credential.problem) problems.push(credential.problem);
  if (problems.length > 0) {
    for (const problem of problems) console.error(`refused: ${problem}`);
    process.exit(2);
  }

  const { initializeApp } = await import("firebase-admin/app");
  const { getAuth } = await import("firebase-admin/auth");
  const { getFirestore, FieldValue, FieldPath } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: args.project });
  if (app.options.projectId !== args.project) {
    console.error("refused: firebase-admin resolved a different project.");
    process.exit(2);
  }
  const auth = getAuth(app);
  async function* listAuthUsers() {
    let pageToken;
    do {
      const page = await auth.listUsers(1000, pageToken);
      for (const user of page.users) yield { uid: user.uid, email: user.email ?? null };
      pageToken = page.pageToken;
    } while (pageToken);
  }
  console.error(`${SCRIPT_ID}: ${mode} on ${args.project}`);
  const report = await runEmailBackfill({
    db: getFirestore(app),
    listAuthUsers,
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
