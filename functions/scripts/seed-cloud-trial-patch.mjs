#!/usr/bin/env node
/**
 * Create-only patch for the BASMA cloud trial on `rafiq-academy`.
 *
 * Adds (never updates, never deletes):
 * - payments/cloudtrial_pay_s1_2026-11  periodKey 2026-11
 * - assignments/cloudtrial_hw_cloudtrial-student-02
 *
 * Refuses any other project, emulator hosts, and any path that is not one of
 * the two trial ids above. Does not deploy Functions, Rules, or Indexes.
 *
 * Usage:
 *   node functions/scripts/seed-cloud-trial-patch.mjs
 *   node functions/scripts/seed-cloud-trial-patch.mjs --dry-run
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const TARGET_PROJECT = "rafiq-academy";
const SCRIPT_ID = "seed-cloud-trial-patch-v1";
const SOURCE_SEED = "seed-cloud-trial-v1";
const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "..", "..");
const BACKUPS = join(REPO_ROOT, "_backups");
const REPORT_PATH = join(BACKUPS, "ACADEMY_TRIAL_SEED_PATCH_REPORT.json");

const PARENT_ID = "cloudtrial-parent-01";
const STUDENT_1 = "cloudtrial-student-01";
const STUDENT_2 = "cloudtrial-student-02";
const TEACHER_ID = "cloudtrial-teacher-01";
const ADMIN_ID = "cloudtrial-admin-01";
const HALAQA_ID = "cloudtrial_halaqa_morning";
const SOURCE_PAYMENT = "payments/cloudtrial_pay_s1_due";
const NEW_PAYMENT = "payments/cloudtrial_pay_s1_2026-11";
const NEW_ASSIGNMENT = "assignments/cloudtrial_hw_cloudtrial-student-02";
const PERIOD_KEY = "2026-11";

const dryRun = process.argv.includes("--dry-run");
const ALLOWED_CREATES = new Set([NEW_PAYMENT, NEW_ASSIGNMENT]);
// Public OAuth client shipped with firebase-tools. The CLI configstore keeps
// the refresh token but not this client id/secret.
const FIREBASE_TOOLS_CLIENT_ID =
  "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_TOOLS_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi";

function fail(msg) {
  throw new Error(msg);
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
  if (!t.refresh) fail("Access token expired and refresh unavailable");
  const body = new URLSearchParams({
    client_id: t.clientId || FIREBASE_TOOLS_CLIENT_ID,
    client_secret: t.clientSecret || FIREBASE_TOOLS_CLIENT_SECRET,
    refresh_token: t.refresh,
    grant_type: "refresh_token",
  });
  const r = await fetch("https://oauth2.googleapis.com/token", { method: "POST", body });
  const j = await r.json();
  if (!r.ok) fail(`Token refresh failed: ${JSON.stringify(j)}`);
  return j.access_token;
}

async function lookupProject(accessToken) {
  const r = await fetch(`https://firebase.googleapis.com/v1beta1/projects/${TARGET_PROJECT}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!r.ok) fail(`Cannot read Firebase project ${TARGET_PROJECT}: HTTP ${r.status}`);
  const j = await r.json();
  if (j.projectId !== TARGET_PROJECT) fail(`Unexpected projectId ${j.projectId}`);
  return j.projectId;
}

function docUrl(path) {
  const parts = path.split("/");
  if (parts.length !== 2) fail(`unsupported path ${path}`);
  return `https://firestore.googleapis.com/v1/projects/${TARGET_PROJECT}/databases/(default)/documents/${parts[0]}/${encodeURIComponent(parts[1])}`;
}

function strField(doc, name) {
  const v = doc?.fields?.[name];
  if (!v) return null;
  if (v.stringValue != null) return v.stringValue;
  return null;
}

async function firestoreGet(accessToken, path) {
  const r = await fetch(docUrl(path), {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const text = await r.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text.slice(0, 300) };
  }
  return { status: r.status, ok: r.ok, json };
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

async function firestoreCreate(accessToken, path, data) {
  if (!ALLOWED_CREATES.has(path)) {
    return { status: "refused", detail: `path not in create allow-list: ${path}` };
  }
  const parts = path.split("/");
  const url = `https://firestore.googleapis.com/v1/projects/${TARGET_PROJECT}/databases/(default)/documents/${parts[0]}?documentId=${encodeURIComponent(parts[1])}`;
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
  if (r.status === 409 || text.includes("ALREADY_EXISTS")) return { status: "exists" };
  return { status: "error", detail: text.slice(0, 400) };
}

async function queryByField(accessToken, collectionId, field, value, limit = 10) {
  const url = `https://firestore.googleapis.com/v1/projects/${TARGET_PROJECT}/databases/(default)/documents:runQuery`;
  const r = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: {
          fieldFilter: {
            field: { fieldPath: field },
            op: "EQUAL",
            value: { stringValue: value },
          },
        },
        limit,
      },
    }),
  });
  const text = await r.text();
  if (!r.ok) return { ok: false, status: r.status, detail: text.slice(0, 400), docs: [] };
  const rows = JSON.parse(text);
  const docs = [];
  for (const row of rows) {
    if (row.document?.name) docs.push(row.document);
  }
  return { ok: true, status: r.status, docs };
}

function docIdFromName(name) {
  if (!name) return null;
  const parts = name.split("/");
  return parts[parts.length - 1];
}

function tomorrowNoonUtc() {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  d.setUTCHours(10, 0, 0, 0);
  return d;
}

async function main() {
  assertNoEmulatorEnv();
  const accessToken = await getAccessToken();
  const projectId = await lookupProject(accessToken);
  console.log(`Target project verified: ${projectId}`);

  const report = {
    script: SCRIPT_ID,
    projectId,
    mode: "create-only",
    dryRun,
    startedAt: new Date().toISOString(),
    emulatorEnvPresent: false,
    created: [],
    skipped: [],
    untouched: [SOURCE_PAYMENT],
    errors: [],
    preflight: {},
  };

  const sourcePay = await firestoreGet(accessToken, SOURCE_PAYMENT);
  const sourceSummary = {
    status: sourcePay.status,
    trialSeed: strField(sourcePay.json, "trialSeed"),
    parentId: strField(sourcePay.json, "parentId"),
    studentId: strField(sourcePay.json, "studentId"),
    periodKey: strField(sourcePay.json, "periodKey"),
    paymentStatus: strField(sourcePay.json, "status"),
  };
  report.preflight.sourcePayment = sourceSummary;

  const sourceOwned =
    sourcePay.ok &&
    sourceSummary.trialSeed === SOURCE_SEED &&
    sourceSummary.parentId === PARENT_ID &&
    sourceSummary.studentId === STUDENT_1 &&
    sourceSummary.periodKey === "trial-2026-11";

  const existingNewPay = await firestoreGet(accessToken, NEW_PAYMENT);
  report.preflight.newPaymentExists = existingNewPay.ok;

  const parentPayments = await queryByField(accessToken, "payments", "parentId", PARENT_ID, 20);
  const siblingKeys = [];
  if (parentPayments.ok) {
    for (const doc of parentPayments.docs) {
      const id = docIdFromName(doc.name);
      const key = strField(doc, "periodKey");
      const studentId = strField(doc, "studentId");
      const seed = strField(doc, "trialSeed");
      siblingKeys.push({ id, periodKey: key, studentId, trialSeed: seed });
    }
  }
  report.preflight.parentPayments = {
    queryStatus: parentPayments.status,
    docs: siblingKeys,
  };

  const alreadyCorrect = siblingKeys.some(
    (d) =>
      d.studentId === STUDENT_1 &&
      d.periodKey === PERIOD_KEY &&
      (d.trialSeed === SOURCE_SEED || d.trialSeed === SCRIPT_ID || d.id === "cloudtrial_pay_s1_2026-11"),
  );

  if (!sourceOwned) {
    const reason = "source payment is missing or not an exclusive cloud-trial doc; no payment created";
    report.skipped.push({ path: NEW_PAYMENT, reason });
    report.errors.push(reason);
    console.error(reason);
  } else if (existingNewPay.ok || alreadyCorrect) {
    report.skipped.push({
      path: NEW_PAYMENT,
      reason: "corrected periodKey payment already exists",
    });
    console.log(`${NEW_PAYMENT}: exists`);
  } else {
    const created = await firestoreCreate(accessToken, NEW_PAYMENT, {
      studentId: STUDENT_1,
      parentId: PARENT_ID,
      amount: 200,
      currency: "EGP",
      dueDate: new Date("2026-11-20T10:00:00.000Z"),
      status: "due",
      method: null,
      paidAt: null,
      reviewStatus: null,
      periodKey: PERIOD_KEY,
      issuedAt: new Date(),
      createdBy: ADMIN_ID,
      createdAt: new Date(),
      updatedAt: new Date(),
      trialSeed: SCRIPT_ID,
      correctsPeriodKeyOf: SOURCE_PAYMENT,
      demoNote: "فاتورة تجريبية بمفتاح 2026-11 — ليست دفعة حقيقية. المستند الأصلي لم يُعدَّل.",
    });
    if (created.status === "created" || created.status === "dry-run") {
      report.created.push({ path: NEW_PAYMENT, status: created.status });
      console.log(`${NEW_PAYMENT}: ${created.status}`);
    } else if (created.status === "exists") {
      report.skipped.push({ path: NEW_PAYMENT, reason: "ALREADY_EXISTS" });
      console.log(`${NEW_PAYMENT}: exists`);
    } else {
      report.errors.push(`${NEW_PAYMENT}: ${created.detail || created.status}`);
      console.error(`${NEW_PAYMENT}: ${created.status} ${created.detail || ""}`);
    }
  }

  const student2 = await firestoreGet(accessToken, `studentProfiles/${STUDENT_2}`);
  const teacher = await firestoreGet(accessToken, `users/${TEACHER_ID}`);
  const halaqa = await firestoreGet(accessToken, `halaqat/${HALAQA_ID}`);
  report.preflight.student2 = {
    status: student2.status,
    trialSeed: strField(student2.json, "trialSeed"),
    halaqaId: strField(student2.json, "halaqaId"),
    uid: strField(student2.json, "uid"),
  };
  report.preflight.teacher = {
    status: teacher.status,
    role: strField(teacher.json, "role"),
    trialSeed: strField(teacher.json, "trialSeed"),
  };
  report.preflight.halaqa = {
    status: halaqa.status,
    trialSeed: strField(halaqa.json, "trialSeed"),
    teacherId: strField(halaqa.json, "teacherId"),
  };

  const assignmentQuery = await queryByField(
    accessToken,
    "assignments",
    "studentId",
    STUDENT_2,
    10,
  );
  const existingAssignmentIds = assignmentQuery.ok
    ? assignmentQuery.docs.map((d) => docIdFromName(d.name))
    : [];
  report.preflight.student2Assignments = {
    queryStatus: assignmentQuery.status,
    ids: existingAssignmentIds,
  };

  const namedAssignment = await firestoreGet(accessToken, NEW_ASSIGNMENT);
  const studentOwned =
    student2.ok &&
    strField(student2.json, "trialSeed") === SOURCE_SEED &&
    strField(student2.json, "halaqaId") === HALAQA_ID &&
    strField(student2.json, "uid") === STUDENT_2 &&
    teacher.ok &&
    strField(teacher.json, "role") === "teacher" &&
    strField(teacher.json, "trialSeed") === SOURCE_SEED &&
    halaqa.ok &&
    strField(halaqa.json, "trialSeed") === SOURCE_SEED &&
    strField(halaqa.json, "teacherId") === TEACHER_ID;

  if (!assignmentQuery.ok) {
    const reason = `assignment query failed HTTP ${assignmentQuery.status}; no assignment created`;
    report.skipped.push({ path: NEW_ASSIGNMENT, reason });
    report.errors.push(reason);
  } else if (namedAssignment.ok || existingAssignmentIds.length > 0) {
    report.skipped.push({
      path: NEW_ASSIGNMENT,
      reason: "student02 already has an assignment",
      ids: existingAssignmentIds,
    });
    console.log(`${NEW_ASSIGNMENT}: exists`);
  } else if (!studentOwned) {
    const reason = "student02 / teacher / halaqa is not an exclusive cloud-trial chain; no assignment created";
    report.skipped.push({ path: NEW_ASSIGNMENT, reason });
    report.errors.push(reason);
    console.error(reason);
  } else {
    const created = await firestoreCreate(accessToken, NEW_ASSIGNMENT, {
      studentId: STUDENT_2,
      assignedBy: TEACHER_ID,
      halaqaId: HALAQA_ID,
      title: "واجب تجريبي — سورة الملك ١-٥",
      newMemorizationRange: "سورة الملك ١-٥",
      reviewRange: "١-٣",
      dueDate: tomorrowNoonUtc(),
      isSubmitted: false,
      tasks: [
        { id: "t1", title: "قراءة", points: 10, isCompleted: true, kind: "reading" },
        { id: "t2", title: "تسميع", points: 20, isCompleted: false, kind: "recitation" },
      ],
      attachments: [],
      createdAt: new Date(),
      trialSeed: SCRIPT_ID,
    });
    if (created.status === "created" || created.status === "dry-run") {
      report.created.push({ path: NEW_ASSIGNMENT, status: created.status });
      console.log(`${NEW_ASSIGNMENT}: ${created.status}`);
    } else if (created.status === "exists") {
      report.skipped.push({ path: NEW_ASSIGNMENT, reason: "ALREADY_EXISTS" });
    } else {
      report.errors.push(`${NEW_ASSIGNMENT}: ${created.detail || created.status}`);
      console.error(`${NEW_ASSIGNMENT}: ${created.status} ${created.detail || ""}`);
    }
  }

  if (!dryRun && report.created.some((c) => c.path === NEW_PAYMENT && c.status === "created")) {
    const check = await firestoreGet(accessToken, NEW_PAYMENT);
    report.readBack = {
      path: NEW_PAYMENT,
      status: check.status,
      periodKey: strField(check.json, "periodKey"),
      parentId: strField(check.json, "parentId"),
      studentId: strField(check.json, "studentId"),
      trialSeed: strField(check.json, "trialSeed"),
    };
    const original = await firestoreGet(accessToken, SOURCE_PAYMENT);
    report.originalUntouched = {
      path: SOURCE_PAYMENT,
      periodKey: strField(original.json, "periodKey"),
      trialSeed: strField(original.json, "trialSeed"),
    };
  }
  if (!dryRun && report.created.some((c) => c.path === NEW_ASSIGNMENT && c.status === "created")) {
    const check = await firestoreGet(accessToken, NEW_ASSIGNMENT);
    report.assignmentReadBack = {
      path: NEW_ASSIGNMENT,
      status: check.status,
      studentId: strField(check.json, "studentId"),
      halaqaId: strField(check.json, "halaqaId"),
      assignedBy: strField(check.json, "assignedBy"),
      title: strField(check.json, "title"),
      trialSeed: strField(check.json, "trialSeed"),
    };
  }

  report.finishedAt = new Date().toISOString();
  mkdirSync(BACKUPS, { recursive: true });
  writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2), "utf8");
  console.log(`Report: ${REPORT_PATH}`);
  console.log(`Created: ${report.created.length}  Errors: ${report.errors.length}`);
  if (report.errors.length > 0) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
