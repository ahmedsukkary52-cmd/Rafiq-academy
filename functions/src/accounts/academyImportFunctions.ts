/**
 * Academy bulk import — one validated row per call, idempotent and
 * resumable.
 *
 * The client parses and validates the documented CSV template, then sends
 * rows in dependency order (staff and parents → halaqat → students). Rows
 * reference each other by the roster's own `ref` codes (e.g. T001), never by
 * Firebase ids. The ledger `importRows/{ref}` is academy-wide, so a corrected
 * or extended file re-sent later cannot duplicate anything:
 *
 * - a finished row replays as `existing` (no second account, no new
 *   password; recovery goes through `adminResetMemberPassword`), and its
 *   content can no longer change under the same ref;
 * - a failed row without a created record may be corrected and retried;
 * - an account created before a failure is finished on retry and its
 *   password is reissued so credentials can still be delivered;
 * - halaqat use a deterministic `requestId` (adminCreateHalaqaCore), and
 *   students a deterministic onboarding `requestId`, so those cores dedupe
 *   too.
 *
 * Temporary passwords are only returned in the response, never stored.
 */

import { createHash, randomUUID } from "node:crypto";

import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, writeAuditLog } from "../audit/auditLogWrite";
import { loadCallerRole, optionalText, requireCallerUid, requireText } from "../authority/callerContext";
import { adminCreateHalaqaCore } from "../halaqa/halaqaScheduleFunctions";
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";
import { adminSetHalaqaAssistantCore } from "../staff/halaqaAssistantFunctions";
import { MemberRole } from "./academyCredentials";
import { academyRefCounterRef, academyRefNumber, manualEntryMatches } from "./academyRefs";
import {
  adminOnboardStudentCore,
  adminResetMemberPasswordCore,
  createMemberAccount,
  OnboardingDeps,
} from "./onboardingFunctions";

export const IMPORT_ROWS_COLLECTION = "importRows";
const IMPORT_ID_PATTERN = /^imp_[a-f0-9]{16,48}$/;
/**
 * A row claim outlives the callable (60 s default timeout), so a live
 * attempt is never overtaken; after it, a crashed attempt is taken over.
 */
export const IMPORT_LEASE_MS = 2 * 60 * 1000;
const REF_PATTERN = /^[A-Za-z0-9_-]{1,40}$/;

type AccountKind = "teacher" | "supervisor" | "parent" | "assistant";
type ImportKind = AccountKind | "halaqa" | "student";

const ACCOUNT_ROLE: Record<AccountKind, MemberRole> = {
  teacher: "teacher",
  supervisor: "supervisor",
  parent: "parent",
  assistant: "assistant_teacher",
};

export type ImportCredential = { username: string; temporaryPassword: string };
export type ImportRowResult = {
  ref: string;
  kind: ImportKind;
  status: "created" | "existing" | "failed";
  message: string;
  credential?: ImportCredential;
  retryable: boolean;
};

function hash(parts: unknown[]): string {
  return createHash("sha256").update(JSON.stringify(parts)).digest("hex");
}

function requireName(raw: unknown, label: string): string {
  const name = requireText(raw, label, 60).replace(/\s+/g, " ");
  if (name.length < 2) throw new HttpsError("invalid-argument", `${label} قصير جداً`);
  const violation = contactInfoViolation(name);
  if (violation) throw new HttpsError("invalid-argument", violation);
  return name;
}

function requireRef(raw: unknown, label: string): string {
  const ref = typeof raw === "string" ? raw.trim() : "";
  if (!REF_PATTERN.test(ref)) throw new HttpsError("invalid-argument", `${label} غير صالح`);
  return ref;
}

function parseKind(raw: unknown): ImportKind {
  if (
    raw === "teacher" || raw === "supervisor" || raw === "parent" || raw === "assistant" ||
    raw === "halaqa" || raw === "student"
  ) {
    return raw;
  }
  throw new HttpsError("invalid-argument", "نوع السجل غير صالح");
}

/** Canonical row content; part of the fingerprint so a ref cannot change meaning. */
function canonicalRow(kind: ImportKind, row: Record<string, unknown>): Record<string, unknown> {
  switch (kind) {
    case "teacher":
    case "supervisor":
    case "parent":
    case "assistant":
      return { name: requireName(row.name, "الاسم") };
    case "halaqa":
      return {
        name: requireText(row.name, "اسم الحلقة", 80),
        teacherRef: requireRef(row.teacherRef, "مرجع المعلم"),
        supervisorRef: row.supervisorRef ? requireRef(row.supervisorRef, "مرجع المشرف") : "",
        schedule: Array.isArray(row.schedule) ? row.schedule : [],
        meetingLink: optionalText(row.meetingLink, 500),
        // Only present when used, so fingerprints of earlier imports still match.
        ...(row.assistantRef ? { assistantRef: requireRef(row.assistantRef, "مرجع المساعد") } : {}),
      };
    case "student":
      return {
        name: requireName(row.name, "اسم الطالب"),
        parentRef: requireRef(row.parentRef, "مرجع ولي الأمر"),
        halaqaRef: row.halaqaRef ? requireRef(row.halaqaRef, "مرجع الحلقة") : "",
      };
  }
}

function message(e: unknown): string {
  return e instanceof HttpsError ? e.message : "تعذر معالجة السجل";
}

function retryableError(e: unknown): boolean {
  if (!(e instanceof HttpsError)) return true;
  return ["unavailable", "internal", "aborted", "deadline-exceeded", "resource-exhausted"].includes(e.code);
}

export async function adminImportAcademyRowCore(
  deps: OnboardingDeps,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<ImportRowResult> {
  const { db } = deps;
  const adminUid = requireCallerUid(callerUid);
  if ((await loadCallerRole(db, adminUid)) !== "admin") {
    throw new HttpsError("permission-denied", "الاستيراد متاح للمسؤول فقط");
  }
  const importId = typeof data.importId === "string" ? data.importId : "";
  if (!IMPORT_ID_PATTERN.test(importId)) throw new HttpsError("invalid-argument", "معرّف الاستيراد غير صالح");
  const raw = (data.row ?? {}) as Record<string, unknown>;
  const kind = parseKind(raw.kind);
  const ref = requireRef(raw.ref, "المرجع");
  const row = canonicalRow(kind, raw);
  const fingerprint = hash([kind, row]);

  const ledger = db.collection(IMPORT_ROWS_COLLECTION);
  const rowRef = ledger.doc(ref);
  const attemptId = randomUUID();
  // A roster code in the app format of its kind (S-500) moves the counter
  // past it, so codes created in the app continue after the roster's
  // highest code instead of probing through every imported one.
  const refNumber = academyRefNumber(kind, ref);
  const counterRef = academyRefCounterRef(db, kind);
  const prev = await db.runTransaction(async (tx) => {
    const snap = await tx.get(rowRef);
    const counter = refNumber === null ? null : await tx.get(counterRef);
    const p = snap.data() ?? {};
    const committed = p.status === "done" || typeof p.id === "string";
    if (snap.exists && manualEntryMatches(p, kind, String(row.name))) return { ...p, adopted: true };
    if (snap.exists && committed && p.fingerprint !== fingerprint) {
      throw new HttpsError(
        "already-exists",
        `المرجع ${ref} استُخدم لسجل آخر سبق استيراده؛ استخدم مرجعاً جديداً`,
      );
    }
    if (snap.exists && p.status === "done") return p;
    // One live attempt per row, whoever started it (a double submit by the
    // same Admin included). Rows claimed before leases existed fall back to
    // updatedAt.
    const leaseUntilMs =
      p.leaseUntil?.toMillis?.() ?? (p.updatedAt?.toMillis?.() ?? 0) + IMPORT_LEASE_MS;
    if (p.status === "in_progress" && Date.now() < leaseUntilMs) {
      throw new HttpsError(
        "aborted",
        p.actorId === adminUid
          ? `السجل ${ref} قيد المعالجة؛ انتظر النتيجة قبل إعادة المحاولة`
          : `السجل ${ref} قيد المعالجة من مسؤول آخر`,
      );
    }
    tx.set(
      rowRef,
      {
        kind,
        fingerprint,
        status: "in_progress",
        actorId: adminUid,
        importId,
        attemptId,
        leaseUntil: Timestamp.fromMillis(Date.now() + IMPORT_LEASE_MS),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    const last = counter?.get("last");
    if (refNumber !== null && refNumber > (typeof last === "number" ? last : 0)) {
      tx.set(counterRef, { last: refNumber, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
    return p;
  });
  if (prev.adopted === true) {
    return {
      ref,
      kind,
      status: "existing",
      message: "أُنشئ هذا الشخص سابقاً من التطبيق بالمرجع نفسه",
      retryable: false,
    };
  }
  if (prev.status === "done") {
    return { ref, kind, status: "existing", message: "تم إنشاؤه في استيراد سابق", retryable: false };
  }

  // Ledger writes after the claim only land while this attempt still owns
  // the row; an attempt overtaken after its lease never marks it done.
  const writeOwned = (fields: Record<string, unknown>) =>
    db.runTransaction(async (tx) => {
      const current = await tx.get(rowRef);
      if (current.get("attemptId") !== attemptId) {
        throw new HttpsError("aborted", `السجل ${ref} تولّته محاولة أحدث؛ راجع نتيجتها`);
      }
      tx.set(rowRef, { ...fields, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    });
  const done = async (fields: Record<string, unknown>) =>
    writeOwned({ ...fields, status: "done", message: FieldValue.delete(), leaseUntil: FieldValue.delete() });
  const fail = async (e: unknown): Promise<ImportRowResult> => {
    const text = message(e);
    await writeOwned({ status: "failed", message: text, leaseUntil: FieldValue.delete() }).catch(() => undefined);
    return { ref, kind, status: "failed", message: text, retryable: retryableError(e) };
  };
  const resolve = async (refId: string, expected: ImportKind, label: string): Promise<string> => {
    const dep = await ledger.doc(refId).get();
    if (!dep.exists || dep.get("status") !== "done" || dep.get("kind") !== expected) {
      throw new HttpsError("failed-precondition", `${label} (${refId}) لم يُستورد بنجاح بعد`);
    }
    return String(dep.get("id"));
  };

  try {
    if (kind === "teacher" || kind === "supervisor" || kind === "parent" || kind === "assistant") {
      let credential: ImportCredential;
      let id = typeof prev.id === "string" ? prev.id : "";
      if (id) {
        const reset = await adminResetMemberPasswordCore(deps, adminUid, { userId: id });
        credential = { username: reset.username, temporaryPassword: reset.temporaryPassword };
      } else {
        const issued = await createMemberAccount(deps, {
          role: ACCOUNT_ROLE[kind],
          name: String(row.name),
          ref,
        });
        id = issued.uid;
        await writeOwned({ id });
        credential = { username: issued.username, temporaryPassword: issued.temporaryPassword };
      }
      await done({ id });
      await writeAuditLog({
        actor: adminActor(adminUid),
        action: AUDIT_ACTION.academyImport,
        targetType: AUDIT_TARGET_TYPE.user,
        targetId: id,
        metadata: { role: ACCOUNT_ROLE[kind], requestId: importId, operation: "create_account", academyRef: ref },
        source: "adminImportAcademyRow",
      }, db);
      return { ref, kind, status: "created", message: "تم إنشاء الحساب", credential, retryable: false };
    }

    if (kind === "halaqa") {
      const teacherId = await resolve(String(row.teacherRef), "teacher", "المعلم");
      const supervisorId = row.supervisorRef
        ? await resolve(String(row.supervisorRef), "supervisor", "المشرف")
        : "";
      const result = await adminCreateHalaqaCore(
        db,
        adminUid,
        {
          name: row.name,
          teacherId,
          ...(supervisorId ? { supervisorId } : {}),
          schedule: row.schedule,
          ...(row.meetingLink ? { meetingLink: row.meetingLink } : {}),
          requestId: `imp_${hash(["halaqa", ref]).slice(0, 40)}`,
        },
        undefined,
        { academyRef: ref },
      );
      if (result.alreadyExisted && result.academyRef === "") {
        // A halaqa left without its code by an interrupted earlier import.
        await db.collection("halaqat").doc(result.halaqaId).update({ academyRef: ref });
      }
      if (row.assistantRef) {
        const assistantId = await resolve(String(row.assistantRef), "assistant", "المساعد");
        await adminSetHalaqaAssistantCore(db, adminUid, {
          halaqaId: result.halaqaId,
          assistantId,
          operation: "assign",
        });
      }
      await done({ id: result.halaqaId });
      return {
        ref,
        kind,
        status: result.alreadyExisted ? "existing" : "created",
        message: result.alreadyExisted ? "الحلقة موجودة من محاولة سابقة" : "تم إنشاء الحلقة",
        retryable: false,
      };
    }

    const parentId = await resolve(String(row.parentRef), "parent", "ولي الأمر");
    const halaqaId = row.halaqaRef ? await resolve(String(row.halaqaRef), "halaqa", "الحلقة") : "";
    const result = await adminOnboardStudentCore(
      deps,
      adminUid,
      {
        requestId: `imp_${hash(["student", ref]).slice(0, 40)}`,
        studentName: row.name,
        parent: { mode: "existing", parentId },
        ...(halaqaId ? { halaqaId } : {}),
      },
      { studentRef: ref },
    );
    if (result.status !== "completed") {
      const failed = result.steps.find((s) => s.status === "failed");
      throw new HttpsError("aborted", failed?.message ?? "تعذر إكمال تسجيل الطالب");
    }
    await done({ id: result.studentId });
    const student = result.credentials.find((c) => c.role === "student");
    return {
      ref,
      kind,
      status: result.replayed ? "existing" : "created",
      message: result.replayed ? "الطالب مسجل من محاولة سابقة" : "تم تسجيل الطالب",
      ...(student
        ? { credential: { username: student.username, temporaryPassword: student.temporaryPassword } }
        : {}),
      retryable: false,
    };
  } catch (e) {
    return fail(e);
  }
}

export const adminImportAcademyRow = onCall({ region: "europe-west1" }, async (request) => {
  assertBackendAllowed("adminImportAcademyRow");
  return adminImportAcademyRowCore(
    { db: admin.firestore(), auth: admin.auth() },
    request.auth?.uid,
    (request.data ?? {}) as Record<string, unknown>,
  );
});
