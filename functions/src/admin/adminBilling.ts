import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { AUDIT_ACTION, AUDIT_TARGET_TYPE } from "../audit/auditLogContract";
import { adminActor, writeAuditLog } from "../audit/auditLogWrite";
import { assertBackendAllowed } from "../productionGate";
import { assertCallerIsAdmin } from "./assertAdmin";
import {
  invoiceDocId,
  isValidPaymentAccessStatus,
  periodKeyForDate,
  selectApplicableRule,
  assertPositiveAmount,
  PricingRuleLike,
} from "../billing/paymentHelpers";

interface GenerateInvoiceRequest {
  studentId: string;
  parentId?: string;
  periodKey?: string;
  pricingRuleId?: string;
  dueDateIso?: string;
}

export interface IssueInvoiceResult {
  paymentId: string;
  amount: number;
  currency: string;
  periodKey: string;
  created: boolean;
  pricingRuleId: string;
  pricingRuleVersion: number;
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} مطلوب`);
  }
  return value.trim();
}

async function resolveParentId(
  db: admin.firestore.Firestore,
  studentId: string,
  explicit?: string,
): Promise<string> {
  if (explicit && explicit.trim()) return explicit.trim();
  const snap = await db
    .collection("parentProfiles")
    .where("childrenIds", "array-contains", studentId)
    .limit(1)
    .get();
  if (snap.empty) {
    throw new HttpsError(
      "failed-precondition",
      "لا يوجد ولي أمر مرتبط بهذا الطالب",
    );
  }
  return snap.docs[0].id;
}

async function resolveHalaqaId(
  db: admin.firestore.Firestore,
  studentId: string,
): Promise<string | null> {
  const snap = await db
    .collection("halaqat")
    .where("studentIds", "array-contains", studentId)
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0].id;
}

function mapRuleData(
  id: string,
  d: admin.firestore.DocumentData,
): PricingRuleLike {
  return {
    id,
    scope: d.scope as string | undefined,
    scopeId: (d.scopeId as string | null | undefined) ?? null,
    amount: d.amount as number | undefined,
    currency: d.currency as string | undefined,
    billingPeriod: d.billingPeriod as string | undefined,
    active: d.active as boolean | undefined,
    version: d.version as number | undefined,
    effectiveFrom: d.effectiveFrom?.toDate?.() ?? null,
    effectiveTo: d.effectiveTo?.toDate?.() ?? null,
  };
}

async function loadRules(
  db: admin.firestore.Firestore,
  pricingRuleId?: string,
): Promise<PricingRuleLike[]> {
  if (pricingRuleId) {
    const doc = await db.collection("pricingRules").doc(pricingRuleId).get();
    if (!doc.exists) {
      throw new HttpsError("not-found", "قاعدة التسعير غير موجودة");
    }
    return [mapRuleData(doc.id, doc.data()!)];
  }
  const snap = await db
    .collection("pricingRules")
    .where("active", "==", true)
    .get();
  return snap.docs.map((doc) => mapRuleData(doc.id, doc.data()));
}

async function ensurePaymentAccessOk(
  db: admin.firestore.Firestore,
  parentId: string,
  studentId: string,
  paymentId: string,
): Promise<void> {
  const ref = db.collection("paymentAccess").doc(parentId);
  const snap = await ref.get();
  if (snap.exists) return;
  await ref.set({
    parentId,
    status: "ok",
    reason: "invoice_issued",
    primaryInvoiceId: paymentId,
    affectedStudentIds: [studentId],
    graceEndsAt: null,
    suspendedAt: null,
    warningIssuedAt: null,
    lastReminderAt: null,
    reinstatedAt: null,
    reinstatedBy: null,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function dueDateFromInput(iso: string | undefined, periodKey: string): Date {
  if (iso) {
    const parsed = new Date(iso);
    if (Number.isNaN(parsed.getTime())) {
      throw new HttpsError("invalid-argument", "dueDateIso غير صالح");
    }
    return parsed;
  }
  const [y, m] = periodKey.split("-").map((x) => Number(x));
  return new Date(Date.UTC(y, m, 0, 21, 0, 0));
}

/**
 * D3 / C4 — system-owned invoice issuer.
 *
 * Ownership: pricingRules (Admin) → this issuer → payments snapshot.
 * Never trusts a client-supplied amount. Idempotent per student+periodKey.
 *
 * Automatic scheduled/event triggers (Infrastructure TBD; not WA-6 overdue)
 * must call this same function. Admin callable is ops invoke only.
 */
export async function issueInvoiceFromPricing(params: {
  studentId: string;
  parentId?: string;
  periodKey?: string;
  pricingRuleId?: string;
  dueDateIso?: string;
  /** Audit actor — Admin ops uid, or "system" for automated triggers. */
  issuedBy: string;
}): Promise<IssueInvoiceResult> {
  const db = admin.firestore();
  const studentId = requireString(params.studentId, "studentId");
  const parentId = await resolveParentId(db, studentId, params.parentId);
  const periodKey =
    (typeof params.periodKey === "string" && params.periodKey.trim()) ||
    periodKeyForDate(new Date());
  const paymentId = invoiceDocId(studentId, periodKey);
  const existing = await db.collection("payments").doc(paymentId).get();
  if (existing.exists) {
    const d = existing.data()!;
    return {
      paymentId,
      amount: Number(d.amount),
      currency: String(d.currency ?? "EGP"),
      periodKey: String(d.periodKey ?? periodKey),
      created: false,
      pricingRuleId: String(d.pricingRuleId ?? ""),
      pricingRuleVersion: Number(d.pricingRuleVersion ?? 0),
    };
  }

  const halaqaId = await resolveHalaqaId(db, studentId);
  const rules = await loadRules(db, params.pricingRuleId);
  const rule = selectApplicableRule({ rules, studentId, halaqaId });
  if (!rule) {
    throw new HttpsError(
      "failed-precondition",
      "لا توجد قاعدة تسعير فعّالة — اضبط pricingRules أو pricingDefaults",
    );
  }

  let amount: number;
  try {
    amount = assertPositiveAmount(rule.amount);
  } catch {
    throw new HttpsError("failed-precondition", "مبلغ قاعدة التسعير غير صالح");
  }

  const currency = (rule.currency || "EGP").trim() || "EGP";
  const version = Number.isFinite(rule.version) ? Number(rule.version) : 1;
  const dueDate = dueDateFromInput(params.dueDateIso, periodKey);
  const now = FieldValue.serverTimestamp();

  await db.runTransaction(async (tx) => {
    const ref = db.collection("payments").doc(paymentId);
    const again = await tx.get(ref);
    if (again.exists) return;
    tx.set(ref, {
      studentId,
      parentId,
      amount,
      currency,
      dueDate: Timestamp.fromDate(dueDate),
      status: "due",
      method: null,
      paidAt: null,
      pricingRuleId: rule.id,
      pricingRuleVersion: version,
      issuedAt: now,
      periodKey,
      createdBy: params.issuedBy,
      createdAt: now,
      updatedAt: now,
    });
  });

  await ensurePaymentAccessOk(db, parentId, studentId, paymentId);

  // C16 / WA-16 — audit only newly created invoices (idempotent hits skip).
  const issuedBy = params.issuedBy.trim();
  if (issuedBy.length > 0 && issuedBy !== "system") {
    await writeAuditLog({
      actor: adminActor(issuedBy),
      action: AUDIT_ACTION.invoiceCreate,
      targetType: AUDIT_TARGET_TYPE.invoice,
      targetId: paymentId,
      metadata: {
        paymentId,
        parentId,
        studentId,
        periodKey,
        pricingRuleId: rule.id,
        pricingRuleVersion: version,
        amount,
        currency,
      },
      source: "adminGenerateInvoice",
    });
  }

  return {
    paymentId,
    amount,
    currency,
    periodKey,
    created: true,
    pricingRuleId: rule.id,
    pricingRuleVersion: version,
  };
}

/**
 * WA-5 — Admin ops entry that invokes the system invoice issuer (D3).
 * Does not let Admin set amount; only triggers server-owned generation.
 */
export const adminGenerateInvoice = onCall(
  { region: "europe-west1" },
  async (request): Promise<IssueInvoiceResult> => {
    assertBackendAllowed("adminGenerateInvoice");
    const adminUid = await assertCallerIsAdmin(request.auth?.uid);
    const data = (request.data ?? {}) as GenerateInvoiceRequest;
    return issueInvoiceFromPricing({
      studentId: requireString(data.studentId, "studentId"),
      parentId: data.parentId,
      periodKey: data.periodKey,
      pricingRuleId: data.pricingRuleId,
      dueDateIso: data.dueDateIso,
      issuedBy: adminUid,
    });
  },
);

interface ReinstateRequest {
  parentId: string;
  reason?: string;
}

/**
 * WA-3 — Admin-only reinstatement of paymentAccess (no overdue scheduler).
 */
export const adminReinstatePaymentAccess = onCall(
  { region: "europe-west1" },
  async (request): Promise<{ parentId: string; status: string }> => {
    assertBackendAllowed("adminReinstatePaymentAccess");
    const adminUid = await assertCallerIsAdmin(request.auth?.uid);
    const parentId = requireString(
      (request.data as ReinstateRequest | undefined)?.parentId,
      "parentId",
    );
    const reason =
      typeof (request.data as ReinstateRequest)?.reason === "string"
        ? (request.data as ReinstateRequest).reason!.trim()
        : "admin_reinstate";

    const db = admin.firestore();
    const ref = db.collection("paymentAccess").doc(parentId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "سجل صلاحية الدفع غير موجود");
    }
    const current = snap.data()?.status;
    if (current && !isValidPaymentAccessStatus(current)) {
      throw new HttpsError("failed-precondition", "حالة صلاحية الدفع غير صالحة");
    }

    // Change-only: already ok → succeed without rewriting or auditing.
    if (current === "ok") {
      return { parentId, status: "ok" };
    }

    await ref.set(
      {
        parentId,
        status: "ok",
        reason,
        suspendedAt: null,
        graceEndsAt: null,
        reinstatedAt: FieldValue.serverTimestamp(),
        reinstatedBy: adminUid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await writeAuditLog({
      actor: adminActor(adminUid),
      action: AUDIT_ACTION.paymentReinstate,
      targetType: AUDIT_TARGET_TYPE.paymentAccess,
      targetId: parentId,
      metadata: {
        previousStatus: current ?? null,
        newStatus: "ok",
      },
      source: "adminReinstatePaymentAccess",
    });

    return { parentId, status: "ok" };
  },
);
