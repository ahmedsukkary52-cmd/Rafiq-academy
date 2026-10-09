// Demo dataset v1 for the emulator seeder: accounts plus the documents
// adminProvisionUser writes for them (users, userPrivate, role profiles).
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
  { uid: "demo-admin-01", email: "admin@rafiq.demo", name: "خالد عبدالرحمن", role: "admin", phone: "0500000101" },
  { uid: "demo-supervisor-01", email: "supervisor1@rafiq.demo", name: "فهد السبيعي", role: "supervisor", phone: "0500000201" },
  { uid: "demo-teacher-01", email: "teacher@rafiq.demo", name: "عبدالله الحربي", role: "teacher", phone: "0500000301" },
  { uid: "demo-parent-01", email: "parent@rafiq.demo", name: "محمد العتيبي", role: "parent", phone: "0500000401" },
  { uid: "demo-student-01", email: "student01@rafiq.demo", name: "أحمد محمد", role: "student", phone: "0500000501" },
  { uid: "demo-student-02", email: "student02@rafiq.demo", name: "سارة علي", role: "student", phone: "0500000502" },
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
    documents.push({
      collection: "userPrivate",
      id: account.uid,
      data: { phone: account.phone, updatedAt: SERVER_TIMESTAMP },
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
          `${SEED_META.collection}/${SEED_META.id} is "in_progress": an earlier seed stopped part-way. ` +
          "Restart the emulators (npm run serve keeps data in memory only) and seed again.",
      };
    }
    if (meta.status === "complete") {
      return { ok: false, reason: `The emulator is already seeded (dataset v${meta.version}).` };
    }
    return { ok: false, reason: `${SEED_META.collection}/${SEED_META.id} has unknown status ${JSON.stringify(meta.status)}.` };
  }
  if (collectionIds.length > 0 || userCount > 0) {
    return {
      ok: false,
      reason:
        `The emulator already holds data (${userCount} Auth user(s); collections: ` +
        `${collectionIds.slice(0, 10).join(", ") || "none"}). Seeding needs an empty emulator.`,
    };
  }
  return { ok: true };
}

/** Phase of the first write; nothing else has been attempted when it fails. */
export const SEED_MARKER_PHASE = "seed marker";

export class SeedWriteError extends Error {
  constructor(phase, cause) {
    super(`Seed failed during ${phase}: ${cause?.message ?? cause}`);
    this.phase = phase;
    this.cause = cause;
  }
}

function materialize(data, serverTimestamp) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, value === SERVER_TIMESTAMP ? serverTimestamp() : value]),
  );
}

/**
 * Ordered writes: seed marker "in_progress" -> Auth users -> one batch of
 * documents -> read-back verification -> `beforeComplete` -> marker
 * "complete". Throws SeedWriteError on the first failure and leaves
 * everything as written.
 */
export async function writeDemoDataset({
  dataset,
  auth,
  db,
  serverTimestamp,
  beforeComplete = () => {},
  log = () => {},
}) {
  const metaRef = db.collection(SEED_META.collection).doc(SEED_META.id);
  const step = async (phase, fn) => {
    try {
      return await fn();
    } catch (error) {
      throw new SeedWriteError(phase, error);
    }
  };

  await step(SEED_MARKER_PHASE, () =>
    metaRef.create({ status: "in_progress", version: DEMO_SEED_VERSION, startedAt: serverTimestamp() }),
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

  await step("seed marker completion", () =>
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
