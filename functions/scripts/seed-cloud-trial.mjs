#!/usr/bin/env node
/**
 * Create-only Cloud Trial seeder for Firebase project `rafiq-academy`.
 *
 * - Refuses any project other than rafiq-academy
 * - Refuses emulator hosts
 * - Never deletes / never overwrites existing Auth users or Firestore docs
 * - Writes credentials ONLY under repo `_backups/` (gitignored)
 * - Does NOT deploy Functions/Rules/Indexes and does NOT enable Blaze
 *
 * Usage (from repo root or functions/):
 *   node functions/scripts/seed-cloud-trial.mjs
 *   node functions/scripts/seed-cloud-trial.mjs --dry-run
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash, randomBytes } from "node:crypto";

const TARGET_PROJECT = "rafiq-academy";
const SCRIPT_ID = "seed-cloud-trial-v1";
const SEED_META_COLLECTION = "_seedMeta";
const SEED_META_ID = "cloud_trial_v1";
const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "..", "..");
const BACKUPS = join(REPO_ROOT, "_backups");
const CREDENTIALS_PATH = join(BACKUPS, "ACADEMY_TRIAL_CREDENTIALS.txt");
const REPORT_PATH = join(BACKUPS, "ACADEMY_TRIAL_SEED_REPORT.json");

const dryRun = process.argv.includes("--dry-run");

function fail(msg, code = 64) {
  console.error(msg);
  process.exit(code);
}

function assertNoEmulatorEnv() {
  const banned = [
    "FIRESTORE_EMULATOR_HOST",
    "FIREBASE_AUTH_EMULATOR_HOST",
    "FIREBASE_STORAGE_EMULATOR_HOST",
    "FIREBASE_EMULATOR_HUB",
    "FUNCTIONS_EMULATOR",
  ];
  for (const key of banned) {
    if (process.env[key]) {
      fail(`Refusing to run: ${key} is set. Unset emulator env before cloud seed.`);
    }
  }
}

function loadFirebaseCliToken() {
  const cfgPath = join(homedir(), ".config", "configstore", "firebase-tools.json");
  if (!existsSync(cfgPath)) fail("firebase-tools login config not found. Run: firebase login");
  const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));
  const t = cfg.tokens || {};
  return {
    access: t.access_token || t.accessToken,
    refresh: t.refresh_token || t.refreshToken,
    clientId: t.client_id || t.clientId,
    clientSecret: t.client_secret || t.clientSecret,
  };
}

async function getAccessToken() {
  const t = loadFirebaseCliToken();
  if (!t.access) fail("No Firebase CLI access token");
  const probe = await fetch(
    `https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=${encodeURIComponent(t.access)}`,
  );
  if (probe.ok) return t.access;
  if (!t.refresh || !t.clientId || !t.clientSecret) fail("Access token expired and refresh unavailable");
  const body = new URLSearchParams({
    client_id: t.clientId,
    client_secret: t.clientSecret,
    refresh_token: t.refresh,
    grant_type: "refresh_token",
  });
  const r = await fetch("https://oauth2.googleapis.com/token", { method: "POST", body });
  const j = await r.json();
  if (!r.ok) fail(`Token refresh failed: ${JSON.stringify(j)}`);
  return j.access_token;
}

function strongPassword(label) {
  // Unique, printable, no spaces; not written to git-tracked files by this script.
  const salt = randomBytes(4).toString("base64url");
  return `Basma!${label}!${salt}`;
}

function buildAccounts() {
  return [
    {
      uid: "cloudtrial-admin-01",
      email: "trial.admin@basma.demo",
      name: "مدير تجربة بصمة",
      role: "admin",
      password: strongPassword("Admin"),
    },
    {
      uid: "cloudtrial-supervisor-01",
      email: "trial.supervisor@basma.demo",
      name: "مشرف تجربة بصمة",
      role: "supervisor",
      password: strongPassword("Super"),
    },
    {
      uid: "cloudtrial-teacher-01",
      email: "trial.teacher@basma.demo",
      name: "معلم تجربة بصمة",
      role: "teacher",
      password: strongPassword("Teach"),
    },
    {
      uid: "cloudtrial-parent-01",
      email: "trial.parent@basma.demo",
      name: "ولي تجربة بصمة",
      role: "parent",
      password: strongPassword("Parent"),
    },
    {
      uid: "cloudtrial-student-01",
      email: "trial.student01@basma.demo",
      name: "طالب تجربة أ",
      role: "student",
      password: strongPassword("StudA"),
    },
    {
      uid: "cloudtrial-student-02",
      email: "trial.student02@basma.demo",
      name: "طالبة تجربة ب",
      role: "student",
      password: strongPassword("StudB"),
    },
  ];
}

const HALAQA_ID = "cloudtrial_halaqa_morning";
const CONV_TEACHER_PARENT = "cloudtrial-parent-01_cloudtrial-teacher-01";
const CONV_TEACHER_STUDENT = "cloudtrial-student-01_cloudtrial-teacher-01";
const CONV_SUPER_PARENT = "cloudtrial-parent-01_cloudtrial-supervisor-01";

function arabicWeekday(d = new Date()) {
  return ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"][d.getDay()];
}

function dayStart(offset = 0) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + offset);
  return d;
}

function ymd(d) {
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
}

function firestoreValue(v) {
  if (v === null) return { nullValue: null };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(firestoreValue) } };
  if (v && typeof v === "object") {
    if (v.__serverTimestamp) {
      return { timestampValue: new Date().toISOString() };
    }
    const fields = {};
    for (const [k, val] of Object.entries(v)) fields[k] = firestoreValue(val);
    return { mapValue: { fields } };
  }
  throw new Error(`Unsupported value: ${typeof v}`);
}

function toFirestoreDoc(data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) fields[k] = firestoreValue(v);
  return { fields };
}

function normalizeArabic(name) {
  // Lightweight mirror of common Arabic search normalization for Directory.
  return String(name)
    .trim()
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/\s+/g, " ");
}

function buildDocuments(accounts) {
  const byUid = Object.fromEntries(accounts.map((a) => [a.uid, a]));
  const admin = byUid["cloudtrial-admin-01"];
  const supervisor = byUid["cloudtrial-supervisor-01"];
  const teacher = byUid["cloudtrial-teacher-01"];
  const parent = byUid["cloudtrial-parent-01"];
  const s1 = byUid["cloudtrial-student-01"];
  const s2 = byUid["cloudtrial-student-02"];
  const today = arabicWeekday();
  const docs = [];

  for (const a of accounts) {
    docs.push({
      path: `users/${a.uid}`,
      data: {
        name: a.name,
        role: a.role,
        isActive: true,
        nameNormalized: normalizeArabic(a.name),
        createdAt: { __serverTimestamp: true },
        trialSeed: SCRIPT_ID,
      },
    });
    docs.push({
      path: `userPrivate/${a.uid}`,
      data: {
        email: a.email,
        emailSource: "auth",
        emailUpdatedAt: { __serverTimestamp: true },
        trialSeed: SCRIPT_ID,
      },
    });
  }

  docs.push({
    path: `teacherProfiles/${teacher.uid}`,
    data: {
      uid: teacher.uid,
      halaqatIds: [HALAQA_ID],
      weeklyQuota: 6,
      createdAt: { __serverTimestamp: true },
      trialSeed: SCRIPT_ID,
    },
  });
  docs.push({
    path: `parentProfiles/${parent.uid}`,
    data: {
      uid: parent.uid,
      childrenIds: [s1.uid, s2.uid],
      createdAt: { __serverTimestamp: true },
      trialSeed: SCRIPT_ID,
    },
  });
  for (const s of [s1, s2]) {
    const star = s.uid === s1.uid;
    docs.push({
      path: `studentProfiles/${s.uid}`,
      data: {
        uid: s.uid,
        name: s.name,
        avatarId: star ? "eagle" : "fox",
        level: star ? 4 : 2,
        coins: star ? 80 : 30,
        totalStars: star ? 36 : 10,
        streakDays: star ? 7 : 2,
        halaqaId: HALAQA_ID,
        halaqaName: "حلقة تجربة الفجر",
        currentPlanName: "سورة الملك",
        overallProgressPercent: star ? 55 : 28,
        totalVersesMemorized: star ? 140 : 40,
        completedJuz: star ? 1 : 0,
        completedSurahs: star ? 5 : 1,
        createdAt: { __serverTimestamp: true },
        trialSeed: SCRIPT_ID,
      },
    });
  }

  docs.push({
    path: `halaqat/${HALAQA_ID}`,
    data: {
      name: "حلقة تجربة الفجر",
      teacherId: teacher.uid,
      supervisorId: supervisor.uid,
      studentIds: [s1.uid, s2.uid],
      schedule: [
        { day: today, startTime: "06:30", endTime: "08:00", slotId: "cloudtrial-slot-1" },
        { day: "الأربعاء", startTime: "06:30", endTime: "08:00", slotId: "cloudtrial-slot-2" },
        { day: "السبت", startTime: "06:30", endTime: "08:00", slotId: "cloudtrial-slot-3" },
      ],
      status: "active",
      createdAt: { __serverTimestamp: true },
      trialSeed: SCRIPT_ID,
    },
  });
  // Meeting link intentionally NOT a live joinable URL (product constraint).
  docs.push({
    path: `halaqaMeetingLinks/${HALAQA_ID}`,
    data: {
      meetingLink: "",
      meetingLinkNote: "رابط الاجتماع يُحدد لاحقًا — بيئة تجربة",
      updatedAt: { __serverTimestamp: true },
      updatedBy: admin.uid,
      trialSeed: SCRIPT_ID,
    },
  });

  // Attendance samples (recent meeting weekdays only — synthetic).
  const statuses = ["present", "present", "late", "absent", "present"];
  let idx = 0;
  for (let offset = 0; offset < 14 && idx < 5; offset++) {
    const day = dayStart(-offset);
    const label = arabicWeekday(day);
    if (![today, "الأربعاء", "السبت"].includes(label) && offset !== 0) continue;
    const sessionId = `${HALAQA_ID}_${ymd(day)}`;
    for (const [i, s] of [s1, s2].entries()) {
      docs.push({
        path: `attendanceRecords/${sessionId}_${s.uid}`,
        data: {
          studentId: s.uid,
          studentName: s.name,
          halaqaId: HALAQA_ID,
          date: day,
          status: statuses[(idx + i) % statuses.length],
          recordedBy: teacher.uid,
          sessionId,
          trialSeed: SCRIPT_ID,
        },
      });
    }
    idx += 1;
  }

  for (let i = 0; i < 4; i++) {
    const day = dayStart(-i);
    const s = i % 2 === 0 ? s1 : s2;
    docs.push({
      path: `recitationRecords/cloudtrial_rec_${ymd(day)}_${s.uid}`,
      data: {
        studentId: s.uid,
        studentName: s.name,
        teacherId: teacher.uid,
        halaqaId: HALAQA_ID,
        date: day,
        type: i % 2 === 0 ? "memorization" : "review",
        versesRange: "سورة الملك ١-٨",
        grade: "جيد جداً",
        behaviorGrade: "ممتاز",
        reviewStatus: "reviewed",
        sessionId: `${HALAQA_ID}_${ymd(day)}`,
        trialSeed: SCRIPT_ID,
      },
    });
  }

  docs.push({
    path: `assignments/cloudtrial_hw_${s1.uid}`,
    data: {
      studentId: s1.uid,
      assignedBy: teacher.uid,
      halaqaId: HALAQA_ID,
      title: "واجب تجريبي — سورة الملك ١-١٠",
      newMemorizationRange: "سورة الملك ١-١٠",
      reviewRange: "١-٥",
      dueDate: dayStart(1),
      isSubmitted: false,
      tasks: [
        { id: "t1", title: "قراءة", points: 10, isCompleted: true, kind: "reading" },
        { id: "t2", title: "تسميع", points: 20, isCompleted: false, kind: "recitation" },
      ],
      attachments: [],
      createdAt: { __serverTimestamp: true },
      trialSeed: SCRIPT_ID,
    },
  });

  function conversationDoc(id, a, b, preview, sender) {
    docs.push({
      path: `conversations/${id}`,
      data: {
        kind: "direct",
        participantIds: [a.uid, b.uid].sort(),
        participants: [
          { uid: a.uid, name: a.name, role: a.role },
          { uid: b.uid, name: b.name, role: b.role },
        ],
        lastMessage: preview,
        lastMessageAt: { __serverTimestamp: true },
        lastMessageSenderId: sender,
        unreadCounts: { [a.uid]: 0, [b.uid]: 1 },
        createdAt: { __serverTimestamp: true },
        updatedAt: { __serverTimestamp: true },
        createdBy: a.uid,
        trialSeed: SCRIPT_ID,
      },
    });
    docs.push({
      path: `conversations/${id}/messages/m1`,
      data: {
        senderId: sender,
        type: "text",
        text: preview,
        sentAt: { __serverTimestamp: true },
        deleted: false,
        trialSeed: SCRIPT_ID,
      },
    });
  }
  conversationDoc(
    CONV_TEACHER_PARENT,
    teacher,
    parent,
    "السلام عليكم — متابعة حضور هذا الأسبوع (بيئة تجربة).",
    teacher.uid,
  );
  conversationDoc(
    CONV_TEACHER_STUDENT,
    teacher,
    s1,
    "راجع الآيات المطلوبة قبل الجلسة القادمة.",
    teacher.uid,
  );
  conversationDoc(
    CONV_SUPER_PARENT,
    supervisor,
    parent,
    "نرحب بكم في بيئة تجربة بصمة.",
    supervisor.uid,
  );

  // Synthetic subscription invoices — clearly trial, not real payment confirmation.
  docs.push({
    path: `payments/cloudtrial_pay_s1_due`,
    data: {
      studentId: s1.uid,
      parentId: parent.uid,
      amount: 200,
      currency: "EGP",
      dueDate: dayStart(7),
      status: "due",
      method: null,
      paidAt: null,
      reviewStatus: null,
      periodKey: "trial-2026-11",
      issuedAt: { __serverTimestamp: true },
      createdBy: admin.uid,
      createdAt: { __serverTimestamp: true },
      updatedAt: { __serverTimestamp: true },
      trialSeed: SCRIPT_ID,
      demoNote: "فاتورة تجريبية — ليست دفعة حقيقية",
    },
  });

  docs.push({
    path: `notifications/cloudtrial_notif_welcome`,
    data: {
      audience: "all",
      title: "مرحبًا بكم في تجربة بصمة",
      body: "هذه بيئة سحابية تجريبية بحسابات وعلاقات اصطناعية.",
      type: "system",
      hasAudioAlert: false,
      createdAt: { __serverTimestamp: true },
      readBy: [],
      channel: "in_app",
      trialSeed: SCRIPT_ID,
    },
  });
  docs.push({
    path: `notifications/cloudtrial_notif_parent`,
    data: {
      audience: parent.uid,
      title: "فاتورة تجريبية مستحقة",
      body: "توجد فاتورة تجريبية مرتبطة بالطالب أ — ليست عملية دفع حقيقية.",
      type: "payment",
      hasAudioAlert: false,
      createdAt: { __serverTimestamp: true },
      readBy: [],
      channel: "in_app",
      trialSeed: SCRIPT_ID,
    },
  });

  docs.push({
    path: `academySettings/main`,
    data: {
      academyName: "أكاديمية تجربة بصمة",
      currency: "EGP",
      updatedAt: { __serverTimestamp: true },
      trialSeed: SCRIPT_ID,
    },
    // create-only: if main already exists, skip without overwrite
    skipIfExists: true,
  });

  return docs;
}

async function authCreateUser(accessToken, account) {
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${TARGET_PROJECT}/accounts`;
  const r = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      localId: account.uid,
      email: account.email,
      password: account.password,
      displayName: account.name,
      emailVerified: true,
      disabled: false,
    }),
  });
  const text = await r.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  if (r.ok) return { status: "created" };
  const msg = JSON.stringify(json);
  if (msg.includes("EMAIL_EXISTS") || msg.includes("DUPLICATE_LOCAL_ID") || r.status === 409) {
    return { status: "exists" };
  }
  return { status: "error", detail: msg };
}

async function firestoreCreate(accessToken, path, data, skipIfExists) {
  // path like users/uid or conversations/id/messages/m1
  const parts = path.split("/");
  let collectionId;
  let documentId;
  let parent = `projects/${TARGET_PROJECT}/databases/(default)/documents`;
  if (parts.length === 2) {
    collectionId = parts[0];
    documentId = parts[1];
  } else if (parts.length === 4) {
    parent = `${parent}/${parts[0]}/${parts[1]}`;
    collectionId = parts[2];
    documentId = parts[3];
  } else {
    return { status: "error", detail: `unsupported path ${path}` };
  }
  const url = `https://firestore.googleapis.com/v1/${parent}/${collectionId}?documentId=${encodeURIComponent(documentId)}`;
  if (dryRun) return { status: "dry-run" };
  const r = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(toFirestoreDoc(data)),
  });
  const text = await r.text();
  if (r.ok) return { status: "created" };
  if (r.status === 409 || text.includes("ALREADY_EXISTS")) {
    return { status: skipIfExists || true ? "exists" : "exists" };
  }
  return { status: "error", detail: text.slice(0, 400) };
}

async function lookupProject(accessToken) {
  const r = await fetch(`https://firebase.googleapis.com/v1beta1/projects/${TARGET_PROJECT}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!r.ok) fail(`Cannot read Firebase project ${TARGET_PROJECT}: HTTP ${r.status}`);
  const j = await r.json();
  if (j.projectId !== TARGET_PROJECT) fail(`Unexpected projectId ${j.projectId}`);
  return j;
}

function writeCredentials(accounts) {
  mkdirSync(BACKUPS, { recursive: true });
  const lines = [
    "BASMA Academy Cloud Trial credentials",
    `project: ${TARGET_PROJECT}`,
    `script: ${SCRIPT_ID}`,
    `generated: ${new Date().toISOString()}`,
    "APK: Trial flavor ONLY (no emulator)",
    "WARNING: Passwords are unique; do not commit this file.",
    "",
    "role         | email                        | password",
    ...accounts.map(
      (a) => `${a.role.padEnd(12)} | ${a.email.padEnd(28)} | ${a.password}`,
    ),
    "",
    "What each account can try (subject to Cloud Functions / Blaze availability):",
    "- admin: لوحة الإدارة، الحلقات، الحسابات التجريبية",
    "- supervisor: حلقات ضمن نطاقه، الطلاب، المدفوعات التجريبية",
    "- teacher: الحلقة والطلاب والحضور والتقييم والمحادثات",
    "- parent: الأبناء والجدول والمدفوعات التجريبية والمحادثات",
    "- student: الحلقة والجدول والواجبات",
    "",
  ];
  writeFileSync(CREDENTIALS_PATH, lines.join("\n"), "utf8");
}

async function main() {
  assertNoEmulatorEnv();
  const accessToken = await getAccessToken();
  await lookupProject(accessToken);
  console.log(`Target project verified: ${TARGET_PROJECT}`);
  if (dryRun) console.log("DRY RUN — no writes");

  const accounts = buildAccounts();
  const docs = buildDocuments(accounts);
  const report = {
    script: SCRIPT_ID,
    projectId: TARGET_PROJECT,
    startedAt: new Date().toISOString(),
    dryRun,
    auth: [],
    firestore: [],
    errors: [],
  };

  // Seed marker create-only
  if (!dryRun) {
    const marker = await firestoreCreate(
      accessToken,
      `${SEED_META_COLLECTION}/${SEED_META_ID}`,
      {
        status: "in_progress",
        version: 1,
        script: SCRIPT_ID,
        startedAt: { __serverTimestamp: true },
      },
      true,
    );
    report.firestore.push({ path: `${SEED_META_COLLECTION}/${SEED_META_ID}`, ...marker });
    if (marker.status === "error") {
      report.errors.push(marker.detail);
    }
  }

  for (const account of accounts) {
    if (dryRun) {
      report.auth.push({ email: account.email, uid: account.uid, status: "dry-run" });
      continue;
    }
    const result = await authCreateUser(accessToken, account);
    report.auth.push({ email: account.email, uid: account.uid, status: result.status, detail: result.detail });
    console.log(`Auth ${account.email}: ${result.status}`);
    if (result.status === "error") report.errors.push(`${account.email}: ${result.detail}`);
  }

  for (const doc of docs) {
    const result = await firestoreCreate(accessToken, doc.path, doc.data, doc.skipIfExists);
    report.firestore.push({ path: doc.path, status: result.status, detail: result.detail });
    if (result.status === "error") {
      console.error(`Firestore ${doc.path}: ERROR ${result.detail}`);
      report.errors.push(`${doc.path}: ${result.detail}`);
    } else {
      console.log(`Firestore ${doc.path}: ${result.status}`);
    }
  }

  if (!dryRun) {
    // Best-effort completion marker (create-only alternate id if in_progress exists)
    await firestoreCreate(
      accessToken,
      `${SEED_META_COLLECTION}/${SEED_META_ID}_complete`,
      {
        status: "complete",
        version: 1,
        script: SCRIPT_ID,
        completedAt: { __serverTimestamp: true },
        counts: {
          auth: report.auth.length,
          firestore: report.firestore.filter((x) => x.status === "created").length,
          errors: report.errors.length,
        },
      },
      true,
    );
    writeCredentials(accounts);
    console.log(`Credentials written to ${CREDENTIALS_PATH}`);
  }

  report.finishedAt = new Date().toISOString();
  report.credentialsPath = dryRun ? null : CREDENTIALS_PATH;
  report.fingerprint = createHash("sha256")
    .update(accounts.map((a) => a.email).join(","))
    .digest("hex")
    .slice(0, 16);
  mkdirSync(BACKUPS, { recursive: true });
  writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2), "utf8");
  console.log(`Report: ${REPORT_PATH}`);
  console.log(`Errors: ${report.errors.length}`);
  process.exit(report.errors.length > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
