// Demo dataset v1 for the emulator seeder: accounts plus the documents
// adminProvisionUser writes for them (users, role profiles). No personal
// phone numbers are seeded anywhere.
// Pure data and write orchestration; firebase-admin handles are injected.
//
// Writes use create() only, so nothing that already exists is overwritten,
// and nothing is ever deleted.

export const DEMO_SEED_VERSION = 1;
export const SEED_META = { collection: "_seedMeta", id: "demo" };

// Emulator-only password shared by every demo account.
export const DEMO_PASSWORD = "SeedDemo123!";

/** Placeholder replaced by FieldValue.serverTimestamp() at write time. */
export const SERVER_TIMESTAMP = Object.freeze({ serverTimestamp: true });

export const DEMO_ACCOUNTS = Object.freeze([
  { uid: "demo-admin-01", email: "admin@rafiq.demo", name: "خالد عبدالرحمن", role: "admin" },
  { uid: "demo-supervisor-01", email: "supervisor1@rafiq.demo", name: "فهد السبيعي", role: "supervisor" },
  { uid: "demo-teacher-01", email: "teacher@rafiq.demo", name: "عبدالله الحربي", role: "teacher" },
  { uid: "demo-parent-01", email: "parent@rafiq.demo", name: "محمد العتيبي", role: "parent" },
  { uid: "demo-student-01", email: "student01@rafiq.demo", name: "أحمد محمد", role: "student" },
  { uid: "demo-student-02", email: "student02@rafiq.demo", name: "سارة علي", role: "student" },
].map((a) => Object.freeze(a)));

/** Same field set as adminProvisionUser's writeRoleProfile. */
function roleProfile(account) {
  const { uid, name, role } = account;
  switch (role) {
    case "student":
      return {
        collection: "studentProfiles",
        data: {
          uid,
          name,
          avatarId: "fox",
          level: 1,
          coins: 0,
          totalStars: 0,
          streakDays: 0,
          halaqaId: null,
          halaqaName: null,
          currentPlanName: null,
          overallProgressPercent: 0,
          totalVersesMemorized: 0,
          completedJuz: 0,
          completedSurahs: 0,
          createdAt: SERVER_TIMESTAMP,
        },
      };
    case "parent":
      return { collection: "parentProfiles", data: { uid, childrenIds: [], createdAt: SERVER_TIMESTAMP } };
    case "teacher":
      return {
        collection: "teacherProfiles",
        data: { uid, halaqatIds: [], weeklyQuota: 0, createdAt: SERVER_TIMESTAMP },
      };
    default:
      return null;
  }
}

export function buildDemoDataset(accounts = DEMO_ACCOUNTS) {
  const authUsers = [];
  const documents = [];
  for (const account of accounts) {
    authUsers.push({
      uid: account.uid,
      email: account.email,
      password: DEMO_PASSWORD,
      displayName: account.name,
      disabled: false,
    });
    documents.push({
      collection: "users",
      id: account.uid,
      data: {
        name: account.name,
        role: account.role,
        email: account.email,
        isActive: true,
        createdAt: SERVER_TIMESTAMP,
      },
    });
    const profile = roleProfile(account);
    if (profile !== null) documents.push({ ...profile, id: account.uid });
  }
  return { authUsers, documents };
}

/**
 * Decides whether seeding may start. Only an empty emulator is accepted;
 * a leftover seed marker or any other data is refused.
 */
export function classifyEmulatorState({ collectionIds, userCount, meta }) {
  if (meta !== null && meta !== undefined) {
    if (meta.status === "in_progress") {
      return {
        ok: false,
        reason:
          `${SEED_META.collection}/${SEED_META.id} is "in_progress"` +
          (meta.hubPid ? ` (emulator hub pid ${meta.hubPid})` : "") +
          ": an earlier seed stopped part-way in this emulator session. Do not seed this session; start a new " +
          "one with `npm run serve` only (never --import or --export-on-exit) and let the seeder's checks decide.",
      };
    }
    if (meta.status === "complete") {
      return {
        ok: false,
        reason:
          `${SEED_META.collection}/${SEED_META.id} is "complete" (dataset v${meta.version}): the dataset looks ` +
          "complete, but that does not show the run that wrote it succeeded (a run that failed or timed out while " +
          "completing the marker can leave it \"complete\"). Nothing is written to this emulator session.",
      };
    }
    return { ok: false, reason: `${SEED_META.collection}/${SEED_META.id} has unknown status ${JSON.stringify(meta.status)}.` };
  }
  if (collectionIds.length > 0 || userCount > 0) {
    return {
      ok: false,
      reason:
        `The emulator already holds data (${describeUserCount(userCount)}; collections: ` +
        `${collectionIds.slice(0, 10).join(", ") || "none"}). Seeding needs an empty emulator.`,
    };
  }
  return { ok: true };
}

/** Auth users are probed with one listUsers page of this size. */
export const USER_PROBE_PAGE = 10;

const describeUserCount = (count) =>
  count >= USER_PROBE_PAGE ? `at least ${count} Auth users` : `${count} Auth user(s)`;

/** Phase of the first write; nothing else has been attempted when it fails. */
export const SEED_MARKER_PHASE = "seed marker";
/** Phase of the last write; every Auth user and document was verified before it. */
export const SEED_COMPLETION_PHASE = "seed marker completion";

/**
 * Longest wait for one seeding step against the local emulator. Expiry only
 * stops this run from waiting: the firebase-admin request is not cancelled
 * and may still be applied afterwards.
 */
export const SEED_STEP_TIMEOUT_MS = 60000;

export class SeedWriteError extends Error {
  constructor(phase, cause, { timedOut = false } = {}) {
    super(`Seed ${timedOut ? "stopped" : "failed"} during ${phase}: ${cause?.message ?? cause}`);
    this.phase = phase;
    this.cause = cause;
    this.timedOut = timedOut;
  }
}

const TIMED_OUT = Symbol("timed out");

function materialize(data, serverTimestamp) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, value === SERVER_TIMESTAMP ? serverTimestamp() : value]),
  );
}

/**
 * Ordered writes: seed marker "in_progress" -> Auth users -> one batch of
 * documents -> read-back verification -> `beforeComplete` -> marker
 * "complete". Throws SeedWriteError on the first failure or timeout and
 * leaves everything as written; nothing after the failed step is attempted.
 * No step is retried here, though firebase-admin and its client libraries
 * may retry a request internally, and a request already sent may still be
 * applied after the error. `session` (hub pid, CLI version) is recorded on the
 * marker for diagnosis only; it proves nothing about the emulator.
 */
export async function writeDemoDataset({
  dataset,
  auth,
  db,
  serverTimestamp,
  session = {},
  beforeComplete = () => {},
  log = () => {},
  stepTimeoutMs = SEED_STEP_TIMEOUT_MS,
}) {
  const metaRef = db.collection(SEED_META.collection).doc(SEED_META.id);
  const step = async (phase, fn) => {
    const pending = Promise.resolve().then(fn);
    let timer;
    const expired = new Promise((resolve) => {
      timer = setTimeout(() => resolve(TIMED_OUT), stepTimeoutMs);
    });
    try {
      const result = await Promise.race([pending, expired]);
      if (result !== TIMED_OUT) return result;
    } catch (error) {
      throw new SeedWriteError(phase, error);
    } finally {
      clearTimeout(timer);
    }
    // The race only stops the wait. The request keeps running and may still
    // be applied; its late result or error is deliberately ignored.
    pending.catch(() => {});
    throw new SeedWriteError(
      phase,
      new Error(`no answer within ${stepTimeoutMs / 1000} s; the request was not cancelled and may still be applied`),
      { timedOut: true },
    );
  };

  await step(SEED_MARKER_PHASE, () =>
    metaRef.create({
      status: "in_progress",
      version: DEMO_SEED_VERSION,
      startedAt: serverTimestamp(),
      hubPid: session.hubPid ?? null,
      cliVersion: session.cliVersion ?? null,
    }),
  );

  for (const user of dataset.authUsers) {
    await step(`Auth user ${user.email}`, () => auth.createUser(user));
    log(`  created Auth user ${user.email} (${user.uid})`);
  }

  await step("Firestore documents", async () => {
    const batch = db.batch();
    for (const doc of dataset.documents) {
      batch.create(db.collection(doc.collection).doc(doc.id), materialize(doc.data, serverTimestamp));
    }
    await batch.commit();
  });
  log(`  created ${dataset.documents.length} Firestore documents`);

  const problems = await step("verification", () => verifyDemoDataset({ dataset, auth, db }));
  if (problems.length > 0) {
    throw new SeedWriteError("verification", new Error(problems.join(" ")));
  }

  await step("pre-completion check", beforeComplete);

  await step(SEED_COMPLETION_PHASE, () =>
    metaRef.update({
      status: "complete",
      completedAt: serverTimestamp(),
      counts: { authUsers: dataset.authUsers.length, documents: dataset.documents.length },
    }),
  );
}

export async function verifyDemoDataset({ dataset, auth, db }) {
  const problems = [];
  for (const user of dataset.authUsers) {
    const record = await auth.getUser(user.uid);
    if (record.email !== user.email) problems.push(`Auth user ${user.uid} has email ${record.email}.`);
  }
  for (const doc of dataset.documents) {
    const snap = await db.collection(doc.collection).doc(doc.id).get();
    if (!snap.exists) problems.push(`${doc.collection}/${doc.id} is missing.`);
  }
  return problems;
}

/**
 * Read-only look at an interrupted seed: which of the dataset's fixed Auth
 * UIDs and document IDs exist. Uses getUser() and get() only. Anything that
 * could not be read is reported as unknown, never as absent. Prints UIDs and
 * counts, no emails, names or phone numbers. Returns printable lines.
 */
export async function diagnosePartialSeed({ dataset, auth, db, collectionIds = [], userCount = 0 }) {
  const lines = ["Read-only diagnosis of the interrupted seed (nothing is written, changed or deleted):"];

  const presentUids = [];
  const unknownUids = [];
  for (const user of dataset.authUsers) {
    try {
      await auth.getUser(user.uid);
      presentUids.push(user.uid);
    } catch (e) {
      if (e?.code !== "auth/user-not-found") unknownUids.push(`${user.uid} (${e?.code ?? "read error"})`);
    }
  }
  lines.push(
    `  Auth: ${presentUids.length} of ${dataset.authUsers.length} demo accounts exist` +
      (presentUids.length > 0 ? `: ${presentUids.join(", ")}.` : "."),
  );
  if (unknownUids.length > 0) lines.push(`  Auth: could not check ${unknownUids.join(", ")}.`);
  lines.push(
    userCount >= USER_PROBE_PAGE
      ? `  Auth: the probe listed ${userCount} users (one page); more accounts may exist.`
      : `  Auth: ${userCount} user(s) in total.`,
  );

  const byCollection = {};
  for (const doc of dataset.documents) {
    const entry = (byCollection[doc.collection] ??= { expected: 0, present: 0, unknown: 0 });
    entry.expected += 1;
    try {
      const snap = await db.collection(doc.collection).doc(doc.id).get();
      if (snap.exists) entry.present += 1;
    } catch {
      entry.unknown += 1;
    }
  }
  for (const [collection, { expected, present, unknown }] of Object.entries(byCollection)) {
    lines.push(
      `  Firestore ${collection}: ${present} of ${expected} dataset documents exist` +
        (unknown > 0 ? `; ${unknown} could not be read.` : "."),
    );
  }

  const other = collectionIds.filter((id) => !Object.hasOwn(byCollection, id) && id !== SEED_META.collection);
  if (other.length > 0) {
    lines.push(`  Firestore: other root collections present (not written by the seeder): ${other.join(", ")}.`);
  }
  lines.push(
    "  Only the dataset's fixed IDs were checked; other documents in these collections are not counted. " +
      "This diagnosis never makes the session acceptable for seeding.",
  );
  return lines;
}
