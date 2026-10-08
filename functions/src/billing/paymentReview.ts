/**
 * PH-02 / C4 + C16 — server-authoritative payment proof review.
 *
 * The client sends intent only: `{ paymentId, decision, notes?,
 * amountPaidConfirmed? }`. Reviewer identity, review timestamp, `status=paid`,
 * `paidAt` and `remainingAmount` are derived here. The invoice snapshot
 * (`amount`, parent/student identity, due date, pricing) is never written.
 *
 * Reviewer matrix (SECURITY_DATA_CONTRACT_FREEZE §4.7):
 *   Admin      — any payment.
 *   Supervisor — payments of students on a halaqa they supervise (roster SSOT,
 *                selected by the studentProfiles.halaqaId pointer).
 *   Everyone else — denied.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  AUDIT_ACTION,
  AUDIT_LOGS_COLLECTION,
  AUDIT_TARGET_TYPE,
  AuditActor,
} from "../audit/auditLogContract";
import {
  adminActor,
  buildAuditLogEntry,
  supervisorActor,
} from "../audit/auditLogWrite";
import {
  loadCallerRole,
  optionalText,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import { assertBackendAllowed } from "../productionGate";

export const PAYMENT_REVIEW_DECISIONS = ["approve", "reject", "partial"] as const;
export type PaymentReviewDecision = (typeof PAYMENT_REVIEW_DECISIONS)[number];

export const REVIEW_STATUS_PENDING = "pending_review";
export const MAX_REVIEW_NOTES_LENGTH = 500;

const REVIEW_STATUS_BY_DECISION: Record<PaymentReviewDecision, string> = {
  approve: "approved",
  reject: "rejected",
  partial: "partial",
};

export type PaymentReviewPatch = {
  reviewStatus: string;
  status?: "paid";
  amountPaidConfirmed?: number;
  remainingAmount?: number;
};

export type PaymentReviewOutcome =
  | { ok: true; patch: PaymentReviewPatch; previousStatus: string }
  | { ok: false; code: HttpsErrorCode; message: string };

type HttpsErrorCode = "failed-precondition" | "invalid-argument";

export function parseDecision(raw: unknown): PaymentReviewDecision {
  if (
    typeof raw === "string" &&
    (PAYMENT_REVIEW_DECISIONS as readonly string[]).includes(raw)
  ) {
    return raw as PaymentReviewDecision;
  }
  throw new HttpsError("invalid-argument", "قرار المراجعة غير صالح");
}

/**
 * Pure transition check — `pending_review` is the only reviewable state, so a
 * repeated request can never apply a second transition (idempotent reject).
 */
export function decidePaymentReview(params: {
  payment: Record<string, unknown>;
  decision: PaymentReviewDecision;
  amountPaidConfirmed?: unknown;
}): PaymentReviewOutcome {
  const { payment, decision } = params;
  const reviewStatus =
    typeof payment.reviewStatus === "string" ? payment.reviewStatus : "";
  const status = typeof payment.status === "string" ? payment.status : "";

  if (reviewStatus !== REVIEW_STATUS_PENDING) {
    return {
      ok: false,
      code: "failed-precondition",
      message: "لا يوجد إيصال بانتظار المراجعة لهذه الدفعة (ربما تمت مراجعته مسبقاً)",
    };
  }
  if (status === "paid") {
    return {
      ok: false,
      code: "failed-precondition",
      message: "تم سداد هذه الدفعة بالفعل",
    };
  }

  const amount = payment.amount;
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    return {
      ok: false,
      code: "failed-precondition",
      message: "مبلغ الفاتورة غير صالح",
    };
  }

  if (decision === "approve") {
    return {
      ok: true,
      previousStatus: status,
      patch: {
        reviewStatus: REVIEW_STATUS_BY_DECISION.approve,
        status: "paid",
        amountPaidConfirmed: amount,
        remainingAmount: 0,
      },
    };
  }

  if (decision === "reject") {
    return {
      ok: true,
      previousStatus: status,
      patch: { reviewStatus: REVIEW_STATUS_BY_DECISION.reject },
    };
  }

  const confirmed = params.amountPaidConfirmed;
  if (
    typeof confirmed !== "number" ||
    !Number.isFinite(confirmed) ||
    confirmed <= 0 ||
    confirmed >= amount
  ) {
    return {
      ok: false,
      code: "invalid-argument",
      message: "المبلغ المؤكد للسداد الجزئي يجب أن يكون أكبر من صفر وأقل من قيمة الفاتورة",
    };
  }
  return {
    ok: true,
    previousStatus: status,
    patch: {
      reviewStatus: REVIEW_STATUS_BY_DECISION.partial,
      amountPaidConfirmed: confirmed,
      remainingAmount: Math.round((amount - confirmed) * 100) / 100,
    },
  };
}

/** One audit entry per review cycle (a resubmitted proof opens a new cycle). */
export function paymentReviewAuditId(
  paymentId: string,
  proofSubmittedAt: unknown,
): string {
  let cycle = "initial";
  if (proofSubmittedAt instanceof admin.firestore.Timestamp) {
    cycle = String(proofSubmittedAt.toMillis());
  }
  return `payment_review_${paymentId}_${cycle}`;
}

export type ReviewPaymentProofResult = {
  paymentId: string;
  reviewStatus: string;
  status: string;
};

export async function reviewPaymentProofCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<ReviewPaymentProofResult> {
  const uid = requireCallerUid(callerUid);
  const paymentId = requireText(data.paymentId, "paymentId");
  const decision = parseDecision(data.decision);
  const notes = optionalText(data.notes, MAX_REVIEW_NOTES_LENGTH);

  const role = await loadCallerRole(db, uid);
  if (role !== "admin" && role !== "supervisor") {
    throw new HttpsError(
      "permission-denied",
      "مراجعة الإيصالات متاحة للمسؤول أو المشرف المختص فقط",
    );
  }
  const actor: AuditActor =
    role === "admin" ? adminActor(uid) : supervisorActor(uid);

  const paymentRef = db.collection("payments").doc(paymentId);

  return db.runTransaction(async (tx) => {
    const paymentSnap = await tx.get(paymentRef);
    if (!paymentSnap.exists) {
      throw new HttpsError("not-found", "الدفعة غير موجودة");
    }
    const payment = paymentSnap.data() ?? {};
    const parentId = typeof payment.parentId === "string" ? payment.parentId.trim() : "";
    const studentId =
      typeof payment.studentId === "string" ? payment.studentId.trim() : "";
    if (!parentId) {
      throw new HttpsError("failed-precondition", "الدفعة بلا ولي أمر");
    }

    // Parent/payment scope: the invoiced student must be linked to the parent.
    if (studentId) {
      const parentSnap = await tx.get(db.collection("parentProfiles").doc(parentId));
      if (!stringList(parentSnap.data()?.childrenIds).includes(studentId)) {
        throw new HttpsError(
          "failed-precondition",
          "الطالب غير مرتبط بولي الأمر صاحب الدفعة",
        );
      }
    }

    if (role === "supervisor") {
      if (!studentId) {
        throw new HttpsError("permission-denied", "الدفعة خارج نطاق إشرافك");
      }
      const profileSnap = await tx.get(db.collection("studentProfiles").doc(studentId));
      const halaqaId =
        typeof profileSnap.data()?.halaqaId === "string"
          ? String(profileSnap.data()?.halaqaId).trim()
          : "";
      const halaqaSnap = halaqaId
        ? await tx.get(db.collection("halaqat").doc(halaqaId))
        : null;
      const halaqa = halaqaSnap?.data() ?? {};
      const scoped =
        halaqaSnap?.exists === true &&
        halaqa.supervisorId === uid &&
        stringList(halaqa.studentIds).includes(studentId);
      if (!scoped) {
        throw new HttpsError("permission-denied", "الدفعة خارج نطاق إشرافك");
      }
    }

    const outcome = decidePaymentReview({
      payment,
      decision,
      amountPaidConfirmed: data.amountPaidConfirmed,
    });
    if (!outcome.ok) {
      throw new HttpsError(outcome.code, outcome.message);
    }

    const auditRef = db
      .collection(AUDIT_LOGS_COLLECTION)
      .doc(paymentReviewAuditId(paymentId, payment.proofSubmittedAt));
    const auditSnap = await tx.get(auditRef);
    if (auditSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "تمت مراجعة هذا الإيصال مسبقاً",
      );
    }

    const update: Record<string, unknown> = {
      reviewStatus: outcome.patch.reviewStatus,
      reviewedBy: uid,
      reviewedAt: FieldValue.serverTimestamp(),
      reviewNotes: notes ? notes : FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (outcome.patch.status === "paid") {
      update.status = "paid";
      update.paidAt = FieldValue.serverTimestamp();
    }
    if (outcome.patch.amountPaidConfirmed !== undefined) {
      update.amountPaidConfirmed = outcome.patch.amountPaidConfirmed;
    }
    if (outcome.patch.remainingAmount !== undefined) {
      update.remainingAmount = outcome.patch.remainingAmount;
    }
    tx.update(paymentRef, update);

    const newStatus = outcome.patch.status ?? outcome.previousStatus;
    tx.set(
      auditRef,
      buildAuditLogEntry(
        {
          actor,
          action: AUDIT_ACTION.paymentReview,
          targetType: AUDIT_TARGET_TYPE.payment,
          targetId: paymentId,
          metadata: {
            paymentId,
            parentId,
            ...(studentId ? { studentId } : {}),
            decision,
            previousStatus: outcome.previousStatus,
            newStatus,
            previousReviewStatus: REVIEW_STATUS_PENDING,
            newReviewStatus: outcome.patch.reviewStatus,
          },
          source: "reviewPaymentProof",
        },
        FieldValue.serverTimestamp(),
      ),
    );

    return {
      paymentId,
      reviewStatus: outcome.patch.reviewStatus,
      status: newStatus,
    };
  });
}

export const reviewPaymentProof = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("reviewPaymentProof");
    return reviewPaymentProofCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);
