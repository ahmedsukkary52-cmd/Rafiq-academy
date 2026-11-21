// Demo dataset v4 for the emulator seeder: provision-shaped accounts with
// UNIQUE per-account passwords, plus an interconnected academy graph
// (halaqa, roster, attendance, recitations, homework, chats, payments,
// notifications) so every role can walk primary workflows. No personal
// phone numbers. No audit log entries. Pure data + write orchestration;
// firebase-admin handles are injected.
//
// nameNormalized comes from the compiled Functions normalizer. `npm run serve`
// rebuilds lib/ from src/ before the emulators start; without lib/ this
// module fails to load, before any check or write.
//
// Writes use create() only, so nothing that already exists is overwritten,
// and nothing is ever deleted. Passwords never appear in Firestore documents.
import { normalizeArabicSearchText } from "../lib/search/arabicNormalization.js";

export const DEMO_SEED_VERSION = 4;
export const SEED_META = { collection: "_seedMeta", id: "demo" };

/** Fixed halaqa id for the trial graph (teacher + supervisor both see it). */
export const DEMO_HALAQA_MORNING_ID = "demo_halaqa_morning";

/**
 * @deprecated v3 shared password — kept only so older contract strings that
 * mention it still compile. v4 accounts each carry their own `password`.
 */
export const DEMO_PASSWORD = "SeedDemo123!";

/** Placeholder replaced by FieldValue.serverTimestamp() at write time. */
export const SERVER_TIMESTAMP = Object.freeze({ serverTimestamp: true });

export const DEMO_ACCOUNTS = Object.freeze([
  {
    uid: "demo-admin-01",
    email: "admin@rafiq.demo",
    name: "خالد عبدالرحمن",
    role: "admin",
    password: "Admin!Rafiq2026a",
  },
  {
    uid: "demo-supervisor-01",
    email: "supervisor1@rafiq.demo",
    name: "فهد السبيعي",
    role: "supervisor",
    password: "Super!Rafiq2026b",
  },
  {
    uid: "demo-teacher-01",
    email: "teacher@rafiq.demo",
    name: "عبدالله الحربي",
    role: "teacher",
    password: "Teach!Rafiq2026c",
  },
  {
    uid: "demo-parent-01",
    email: "parent@rafiq.demo",
    name: "محمد العتيبي",
    role: "parent",
    password: "Parent!Rafiq2026d",
  },
  {
    uid: "demo-student-01",
    email: "student01@rafiq.demo",
    name: "أحمد محمد",
    role: "student",
    password: "Stud01!Rafiq2026e",
  },
  {
    uid: "demo-student-02",
    email: "student02@rafiq.demo",
    name: "سارة علي",
    role: "student",
    password: "Stud02!Rafiq2026f",
  },
].map((a) => Object.freeze(a)));

/** Deterministic 1:1 conversation id — mirrors functions/src/chat/chatRelationship.ts */
export function demoDirectConversationId(uidA, uidB) {
  return [uidA, uidB].sort().join("_");
}

const ARABIC_WEEKDAY = Object.freeze({
  0: "الأحد",
  1: "الاثنين",
  2: "الثلاثاء",
  3: "الأربعاء",
  4: "الخميس",
  5: "الجمعة",
  6: "السبت",
});

function dayStart(d = new Date()) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function daysAgo(n) {
  const d = dayStart();
  d.setDate(d.getDate() - n);
  return d;
}

function ymd(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}${m}${day}`;
}

function byUid(accounts, uid) {
  return accounts.find((a) => a.uid === uid);
}

/** Role profiles with trial relationships wired for the default six accounts. */
function roleProfile(account, ctx) {
  const { uid, name, role } = account;
  switch (role) {
    case "student": {
      const inHalaqa = ctx.studentIds.includes(uid);
      const isStar = uid === "demo-student-01";
      return {
        collection: "studentProfiles",
        data: {
          uid,
          name,
          avatarId: isStar ? "eagle" : "fox",
          level: isStar ? 5 : 2,
          coins: isStar ? 120 : 40,
          totalStars: isStar ? 48 : 12,
          streakDays: isStar ? 14 : 3,
          halaqaId: inHalaqa ? ctx.halaqaId : null,
          halaqaName: inHalaqa ? ctx.halaqaName : null,
          currentPlanName: inHalaqa ? "سورة الملك" : null,
          overallProgressPercent: isStar ? 72 : 38,
          totalVersesMemorized: isStar ? 220 : 60,
          completedJuz: isStar ? 2 : 0,
          completedSurahs: isStar ? 8 : 2,
          createdAt: SERVER_TIMESTAMP,
        },
      };
    }
    case "parent":
      return {
        collection: "parentProfiles",
        data: {
          uid,
          childrenIds: uid === "demo-parent-01" ? [...ctx.studentIds] : [],
          createdAt: SERVER_TIMESTAMP,
        },
      };
    case "teacher":
      return {
        collection: "teacherProfiles",
        data: {
          uid,
          halaqatIds: uid === "demo-teacher-01" ? [ctx.halaqaId] : [],
          weeklyQuota: uid === "demo-teacher-01" ? 6 : 0,
          createdAt: SERVER_TIMESTAMP,
        },
      };
    default:
      return null;
  }
}

function buildTrialGraphDocuments(accounts) {
  const teacher = byUid(accounts, "demo-teacher-01");
  const supervisor = byUid(accounts, "demo-supervisor-01");
  const s1 = byUid(accounts, "demo-student-01");
  const s2 = byUid(accounts, "demo-student-02");
  if (!teacher || !supervisor || !s1 || !s2) return [];

  const halaqaId = DEMO_HALAQA_MORNING_ID;
  const halaqaName = "حلقة الفجر";
  const studentIds = [s1.uid, s2.uid];
  const today = dayStart();
  const todayAr = ARABIC_WEEKDAY[today.getDay()];
  const docs = [];

  docs.push({
    collection: "halaqat",
    id: halaqaId,
    data: {
      name: halaqaName,
      teacherId: teacher.uid,
      supervisorId: supervisor.uid,
      studentIds,
      schedule: [
        { day: todayAr, startTime: "06:30", endTime: "08:00" },
        { day: "الأربعاء", startTime: "06:30", endTime: "08:00" },
        { day: "السبت", startTime: "06:30", endTime: "08:00" },
      ],
      status: "active",
      createdAt: SERVER_TIMESTAMP,
    },
  });

  docs.push({
    collection: "halaqaMeetingLinks",
    id: halaqaId,
    data: {
      meetingLink: "https://meet.google.com/demo-rafiq-morning",
      updatedAt: SERVER_TIMESTAMP,
      updatedBy: teacher.uid,
    },
  });

  // Only mark attendance on days the halaqa actually meets (from schedule).
  const sessionWeekdays = new Set(
    [todayAr, "الأربعاء", "السبت"]
      .map((label) => Object.entries(ARABIC_WEEKDAY).find(([, v]) => v === label)?.[0])
      .filter((v) => v !== undefined)
      .map((v) => Number(v)),
  );
  const statuses = ["present", "present", "late", "present", "absent", "present", "present"];
  let sessionMarkIndex = 0;
  for (let offset = 0; offset < 28; offset++) {
    const day = daysAgo(offset);
    if (!sessionWeekdays.has(day.getDay())) continue;
    const sessionId = `${halaqaId}_${ymd(day)}`;
    for (const [i, student] of [s1, s2].entries()) {
      const status = statuses[(sessionMarkIndex + i) % statuses.length];
      const docId = `${sessionId}_${student.uid}`;
      docs.push({
        collection: "attendanceRecords",
        id: docId,
        data: {
          studentId: student.uid,
          studentName: student.name,
          halaqaId,
          date: day,
          status,
          recordedBy: teacher.uid,
          sessionId,
        },
      });
    }
    sessionMarkIndex += 1;
    if (sessionMarkIndex >= 12) break;
  }

  const grades = ["ممتاز", "جيد جداً", "جيد", "ممتاز", "يحتاج تحسين", "جيد جداً"];
  for (let offset = 0; offset < 10; offset++) {
    const day = daysAgo(offset);
    const student = offset % 2 === 0 ? s1 : s2;
    const grade = grades[offset % grades.length];
    docs.push({
      collection: "recitationRecords",
      id: `demo_rec_${ymd(day)}_${student.uid}`,
      data: {
        studentId: student.uid,
        studentName: student.name,
        teacherId: teacher.uid,
        halaqaId,
        date: day,
        type: offset % 3 === 0 ? "review" : "memorization",
        versesRange: offset % 2 === 0 ? "سورة الملك ١-١٠" : "سورة ق ١-٨",
        grade,
        behaviorGrade: grade === "يحتاج تحسين" ? "جيد" : "ممتاز",
        reviewStatus: "reviewed",
        sessionId: `${halaqaId}_${ymd(day)}`,
      },
    });
  }

  docs.push({
    collection: "assignments",
    id: `demo_hw_${halaqaId}_s1`,
    data: {
      studentId: s1.uid,
      assignedBy: teacher.uid,
      halaqaId,
      title: "سورة الملك - الآيات ١-١٦",
      newMemorizationRange: "سورة الملك - الآيات ١-١٦",
      reviewRange: "الآيات ١-٨",
      dueDate: daysAgo(-1),
      isSubmitted: false,
      tasks: [
        { id: "t1", title: "قراءة: سورة الملك ١-١٦", points: 20, isCompleted: true, kind: "reading" },
        { id: "t2", title: "الاستماع للتلاوة كاملة", points: 15, isCompleted: false, kind: "listening" },
        { id: "t3", title: "تسميع: سورة الملك ١-١٦", points: 30, isCompleted: false, kind: "recitation" },
      ],
      attachments: [],
      createdAt: SERVER_TIMESTAMP,
    },
  });
  docs.push({
    collection: "assignments",
    id: `demo_hw_${halaqaId}_s2`,
    data: {
      studentId: s2.uid,
      assignedBy: teacher.uid,
      halaqaId,
      title: "سورة ق - الآيات ١-١٥",
      newMemorizationRange: "سورة ق - الآيات ١-١٥",
      reviewRange: "سورة الملك ١-٥",
      dueDate: daysAgo(1),
      isSubmitted: false,
      tasks: [
        { id: "t1", title: "قراءة: سورة ق ١-١٥", points: 20, isCompleted: false, kind: "reading" },
        { id: "t2", title: "الاستماع للتلاوة كاملة", points: 15, isCompleted: false, kind: "listening" },
        { id: "t3", title: "تسميع: سورة ق ١-١٥", points: 30, isCompleted: false, kind: "recitation" },
      ],
      attachments: [],
      createdAt: SERVER_TIMESTAMP,
    },
  });

  // --- Direct chats + sample messages (teacher↔parent, teacher↔student, parent↔supervisor) ---
  const chatPairs = [
    {
      a: teacher,
      b: byUid(accounts, "demo-parent-01"),
      preview: "السلام عليكم، أحمد منتظم هذا الأسبوع.",
      messages: [
        { from: teacher.uid, text: "السلام عليكم، أحمد منتظم هذا الأسبوع." },
        { from: "demo-parent-01", text: "وعليكم السلام، شكرًا للمتابعة." },
      ],
    },
    {
      a: teacher,
      b: s1,
      preview: "راجع سورة الملك ١-١٦ قبل الغد.",
      messages: [
        { from: teacher.uid, text: "راجع سورة الملك ١-١٦ قبل الغد." },
        { from: s1.uid, text: "حاضر يا أستاذ." },
      ],
    },
    {
      a: supervisor,
      b: byUid(accounts, "demo-parent-01"),
      preview: "نذكّرك بموعد مراجعة الحلقة يوم السبت.",
      messages: [
        { from: supervisor.uid, text: "نذكّرك بموعد مراجعة الحلقة يوم السبت." },
      ],
    },
  ];
  for (const pair of chatPairs) {
    if (!pair.b) continue;
    const conversationId = demoDirectConversationId(pair.a.uid, pair.b.uid);
    const last = pair.messages[pair.messages.length - 1];
    docs.push({
      collection: "conversations",
      id: conversationId,
      data: {
        kind: "direct",
        participantIds: [pair.a.uid, pair.b.uid].sort(),
        participants: [
          { uid: pair.a.uid, name: pair.a.name, role: pair.a.role },
          { uid: pair.b.uid, name: pair.b.name, role: pair.b.role },
        ],
        lastMessage: pair.preview,
        lastMessageAt: SERVER_TIMESTAMP,
        lastMessageSenderId: last.from,
        unreadCounts: { [pair.a.uid]: 0, [pair.b.uid]: 1 },
        createdAt: SERVER_TIMESTAMP,
        updatedAt: SERVER_TIMESTAMP,
        createdBy: pair.a.uid,
      },
    });
    pair.messages.forEach((m, i) => {
      docs.push({
        collection: "conversations",
        id: conversationId,
        subcollection: "messages",
        subId: `demo_msg_${i + 1}`,
        data: {
          senderId: m.from,
          type: "text",
          text: m.text,
          sentAt: SERVER_TIMESTAMP,
          deleted: false,
        },
      });
    });
  }

  // --- Payments (parent invoices for both students) ---
  const parent = byUid(accounts, "demo-parent-01");
  if (parent) {
    docs.push({
      collection: "payments",
      id: "demo_pay_s1_current",
      data: {
        studentId: s1.uid,
        parentId: parent.uid,
        amount: 250,
        currency: "EGP",
        dueDate: daysAgo(-7),
        status: "due",
        method: null,
        paidAt: null,
        reviewStatus: null,
        pricingRuleId: "demo_rule_monthly",
        pricingRuleVersion: 1,
        issuedAt: SERVER_TIMESTAMP,
        periodKey: "2026-11",
        createdBy: "demo-admin-01",
        createdAt: SERVER_TIMESTAMP,
        updatedAt: SERVER_TIMESTAMP,
      },
    });
    docs.push({
      collection: "payments",
      id: "demo_pay_s2_review",
      data: {
        studentId: s2.uid,
        parentId: parent.uid,
        amount: 250,
        currency: "EGP",
        dueDate: daysAgo(3),
        status: "due",
        method: "bank_transfer",
        paidAt: null,
        reviewStatus: "pending_review",
        proofFileName: "receipt_demo.jpg",
        proofStoragePath: `paymentProofs/${parent.uid}/demo_pay_s2_review/receipt_demo.jpg`,
        proofSubmittedAt: SERVER_TIMESTAMP,
        proofSubmittedBy: parent.uid,
        proofCycleId: "cycle_demo_001",
        pricingRuleId: "demo_rule_monthly",
        pricingRuleVersion: 1,
        issuedAt: SERVER_TIMESTAMP,
        periodKey: "2026-10",
        createdBy: "demo-admin-01",
        createdAt: SERVER_TIMESTAMP,
        updatedAt: SERVER_TIMESTAMP,
      },
    });
    docs.push({
      collection: "pricingRules",
      id: "demo_rule_monthly",
      data: {
        name: "اشتراك شهري تجريبي",
        amount: 250,
        currency: "EGP",
        version: 1,
        active: true,
        createdAt: SERVER_TIMESTAMP,
      },
    });
  }

  // --- In-app notifications (audience = uid / role / all) ---
  docs.push({
    collection: "notifications",
    id: "demo_notif_parent_payment",
    data: {
      audience: "demo-parent-01",
      title: "فاتورة مستحقة",
      body: "توجد فاتورة مستحقة لابنك أحمد — يُرجى السداد أو رفع إثبات الدفع.",
      type: "payment",
      hasAudioAlert: false,
      createdAt: SERVER_TIMESTAMP,
      readBy: [],
      channel: "in_app",
    },
  });
  docs.push({
    collection: "notifications",
    id: "demo_notif_teacher_hw",
    data: {
      audience: "demo-teacher-01",
      title: "واجب بانتظار المتابعة",
      body: "أحمد محمد لم يُكمل تسميع سورة الملك بعد.",
      type: "homework",
      hasAudioAlert: false,
      createdAt: SERVER_TIMESTAMP,
      readBy: [],
      channel: "in_app",
    },
  });
  docs.push({
    collection: "notifications",
    id: "demo_notif_all_welcome",
    data: {
      audience: "all",
      title: "مرحبًا بكم في بيئة التجربة",
      body: "هذه بيانات تجريبية مترابطة لاختبار الأدوار والحلقات والمحادثات.",
      type: "system",
      hasAudioAlert: false,
      createdAt: SERVER_TIMESTAMP,
      readBy: [],
      channel: "in_app",
    },
  });

  // Academy settings so branding/homes that read it are not empty.
  docs.push({
    collection: "academySettings",
    id: "main",
    data: {
      academyName: "أكاديمية رفيق (تجربة محاكي)",
      currency: "EGP",
      updatedAt: SERVER_TIMESTAMP,
    },
  });

  return docs;
}

export function buildDemoDataset(accounts = DEMO_ACCOUNTS) {
  const authUsers = [];
  const documents = [];
  const ctx = {
    halaqaId: DEMO_HALAQA_MORNING_ID,
    halaqaName: "حلقة الفجر",
    studentIds: ["demo-student-01", "demo-student-02"],
  };
  for (const account of accounts) {
    const password =
      typeof account.password === "string" && account.password.length >= 8
        ? account.password
        : `Seed!${account.uid}`;
    authUsers.push({
      uid: account.uid,
      email: account.email,
      password,
      displayName: account.name,
      disabled: false,
    });
    // Real Admin provisioning still forces completeFirstLogin. Demo seed
    // accounts skip that gate so academy trial logins reach the role home.
    documents.push({
      collection: "users",
      id: account.uid,
      data: {
        name: account.name,
        role: account.role,
        isActive: true,
        createdAt: SERVER_TIMESTAMP,
        nameNormalized: normalizeArabicSearchText(account.name),
      },
    });
    documents.push({
      collection: "userPrivate",
      id: account.uid,
      data: {
        email: account.email,
        emailSource: "auth",
        emailUpdatedAt: SERVER_TIMESTAMP,
      },
    });
    const profile = roleProfile(account, ctx);
    if (profile !== null) documents.push({ ...profile, id: account.uid });
  }
  // Only attach the trial graph when seeding the canonical six accounts.
  const isCanonical =
    accounts.length === DEMO_ACCOUNTS.length &&
    DEMO_ACCOUNTS.every((a, i) => accounts[i]?.uid === a.uid);
  if (isCanonical) {
    documents.push(...buildTrialGraphDocuments(accounts));
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
    await step(`Auth user ${user.uid}`, () => auth.createUser(user));
    log(`  created Auth user ${user.uid}`);
  }

  await step("Firestore documents", async () => {
    // Firestore batches cap at 500 ops; keep under that for the demo graph.
    const batch = db.batch();
    for (const doc of dataset.documents) {
      const ref =
        doc.subcollection && doc.subId
          ? db.collection(doc.collection).doc(doc.id).collection(doc.subcollection).doc(doc.subId)
          : db.collection(doc.collection).doc(doc.id);
      batch.create(ref, materialize(doc.data, serverTimestamp));
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
    if (record.email !== user.email) problems.push(`Auth user ${user.uid} has a different email.`);
  }
  for (const doc of dataset.documents) {
    const ref =
      doc.subcollection && doc.subId
        ? db.collection(doc.collection).doc(doc.id).collection(doc.subcollection).doc(doc.subId)
        : db.collection(doc.collection).doc(doc.id);
    const snap = await ref.get();
    const label =
      doc.subcollection && doc.subId
        ? `${doc.collection}/${doc.id}/${doc.subcollection}/${doc.subId}`
        : `${doc.collection}/${doc.id}`;
    if (!snap.exists) problems.push(`${label} is missing.`);
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
