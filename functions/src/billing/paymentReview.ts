/**
 * PH-02 / C4 + C16 — server-authoritative payment proof review.
 *
 * The client sends intent only. Reviewer identity, review timestamp,
 * `status=paid`, `paidAt`, the cumulative `amountPaidConfirmed` and
 * `remainingAmount` are derived here. The invoice snapshot (`amount`,
 * parent/student identity, due date, pricing) is never written.
 *
 * Two request contracts are accepted:
 *   - Current: `{ paymentId, decision, notes?, requestId, expectedProofFileName,
 *     amountMode?, amountValue? }`. `amountMode` / `amountValue` are required
 *     for `partial` and rejected otherwise. `requestId` makes a retry return
 *     the stored result; `expectedProofFileName` binds the review to the proof
 *     the reviewer actually saw.
 *     `expectedProofCycleId` (optional) binds it to the server-issued proof
 *     cycle (paymentProofSubmission.ts) and is part of the request
 *     fingerprint.
 *   - Legacy: `{ paymentId, decision, notes?, amountPaidConfirmed? }`, where a
 *     partial `amountPaidConfirmed` is the new cumulative total.
 *
 * Proof-cycle binding (checked in the review transaction, before any write):
 *   - Payment has `proofCycleId`: only a current-contract request carrying
 *     that exact cycle may review it. Legacy requests and requests without a
 *     cycle fail closed (`PROOF_CYCLE_REQUIRED_MESSAGE`); another cycle is
 *     stale (`PROOF_CHANGED_MESSAGE`).
 *   - Payment without `proofCycleId` (written before proof submission moved
 *     server-side): no cycle is ever inferred for it. Since clients can no
 *     longer write payments, its proof pointer can only change through the
 *     submission callable, which always issues a cycle — so the existing
 *     file-name binding (current) / unbound review (legacy) still applies.
 *
 * Amounts are computed in integer minor units (2 decimals). The stored
 * `amountPaidConfirmed` is always the cumulative confirmed total and
 * `remainingAmount = amount - amountPaidConfirmed`. Reject never moves totals.
 *
 * Reviewer matrix (SECURITY_DATA_CONTRACT_FREEZE §4.7):
 *   Admin      — any payment.
 *   Supervisor — payments of students on a halaqa they supervise (roster SSOT,
 *                selected by the studentProfiles.halaqaId pointer).
 *   Everyone else — denied.
 */

import { createHash } from "node:crypto";

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
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
import { contactInfoViolation } from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";

export const PAYMENT_REVIEW_DECISIONS = ["approve", "reject", "partial"] as const;
export type PaymentReviewDecision = (typeof PAYMENT_REVIEW_DECISIONS)[number];

export const REVIEW_STATUS_PENDING = "pending_review";
export const MAX_REVIEW_NOTES_LENGTH = 500;

/** CF-only idempotency records, one per `{reviewerUid}_{requestId}`. */
export const PAYMENT_REVIEW_REQUESTS_COLLECTION = "paymentReviewRequests";

export const AMOUNT_INPUT_MODES = ["receipt", "cumulative"] as const;
export type AmountInputMode = (typeof AMOUNT_INPUT_MODES)[number];

/** How a review's amounts were obtained (audit + response). */
export type ReviewAmountMode =
  | AmountInputMode
  | "legacy_cumulative"
  | "approve_remaining"
  | "reject_unchanged";

export const PROOF_CHANGED_MESSAGE = "تم تحديث الإيصال، أعد تحميل الصفحة";
export const REQUEST_ID_REUSED_MESSAGE = "معرّف الطلب مستخدم لطلب مختلف";
export const PROOF_CYCLE_REQUIRED_MESSAGE =
  "تم تحديث الإيصال، أعد تحميل الصفحة (وإن تكرر ذلك فحدّث التطبيق)";

/** Server-issued proof cycle (see paymentProofSubmission.ts). */
export const PROOF_CYCLE_ID_PATTERN = /^pc_[A-Za-z0-9_-]{16,64}$/;

const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;
const PROOF_FILE_NAME_PATTERN = /^[A-Za-z0-9_.-]{1,80}$/;

const REVIEW_STATUS_BY_DECISION: Record<PaymentReviewDecision, string> = {
  approve: "approved",
  reject: "rejected",
  partial: "partial",
};

/**
 * Positive or zero money value with at most 2 decimals, as integer minor
 * units; `null` for anything else (strings, NaN, extra precision).
 */
export function toMinorUnits(raw: unknown): number | null {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return null;
  const scaled = raw * 100;
  const units = Math.round(scaled);
  if (Math.abs(scaled - units) > 1e-6 || !Number.isSafeInteger(units)) {
    return null;
  }
  return units;
}

function fromMinorUnits(units: number): number {
  return units / 100;
}

export type PartialAmountInput = {
  mode: AmountInputMode | "legacy_cumulative";
  value: unknown;
};

export type PaymentReviewPatch = {
  reviewStatus: string;
  status?: "paid";
  amountPaidConfirmed?: number;
  remainingAmount?: number;
};

/** All values in minor units. `receipt` is null when nothing was received. */
export type PaymentReviewAmounts = {
  mode: ReviewAmountMode;
  invoice: number;
  previous: number;
  total: number;
  remaining: number;
  receipt: number | null;
};

export type PaymentReviewOutcome =
  | {
    ok: true;
    patch: PaymentReviewPatch;
    previousStatus: string;
    amounts: PaymentReviewAmounts;
  }
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

function invalid(message: string): PaymentReviewOutcome {
  return { ok: false, code: "invalid-argument", message };
}

function precondition(message: string): PaymentReviewOutcome {
  return { ok: false, code: "failed-precondition", message };
}

/**
 * Pure transition + amount check — `pending_review` is the only reviewable
 * state, so a repeated request can never apply a second transition.
 *
 * `amountInput` carries the current contract's partial amount; when absent a
 * legacy partial `amountPaidConfirmed` is read as the new cumulative total.
 */
export function decidePaymentReview(params: {
  payment: Record<string, unknown>;
  decision: PaymentReviewDecision;
  amountPaidConfirmed?: unknown;
  amountInput?: PartialAmountInput;
}): PaymentReviewOutcome {
  const { payment, decision } = params;
  const reviewStatus =
    typeof payment.reviewStatus === "string" ? payment.reviewStatus : "";
  const status = typeof payment.status === "string" ? payment.status : "";

  if (reviewStatus !== REVIEW_STATUS_PENDING) {
    return precondition(
      "لا يوجد إيصال بانتظار المراجعة لهذه الدفعة (ربما تمت مراجعته مسبقاً)",
    );
  }
  if (status === "paid") {
    return precondition("تم سداد هذه الدفعة بالفعل");
  }

  const invoice = toMinorUnits(payment.amount);
  if (invoice === null || invoice <= 0) {
    return precondition("مبلغ الفاتورة غير صالح");
  }

  const previousRaw = payment.amountPaidConfirmed;
  const previous = previousRaw == null ? 0 : toMinorUnits(previousRaw);
  if (previous === null || previous < 0 || previous >= invoice) {
    return precondition("المبلغ المؤكد السابق لهذه الدفعة غير صالح");
  }

  if (decision === "approve") {
    return {
      ok: true,
      previousStatus: status,
      patch: {
        reviewStatus: REVIEW_STATUS_BY_DECISION.approve,
        status: "paid",
        amountPaidConfirmed: fromMinorUnits(invoice),
        remainingAmount: 0,
      },
      amounts: {
        mode: "approve_remaining",
        invoice,
        previous,
        total: invoice,
        remaining: 0,
        receipt: invoice - previous,
      },
    };
  }

  if (decision === "reject") {
    return {
      ok: true,
      previousStatus: status,
      patch: { reviewStatus: REVIEW_STATUS_BY_DECISION.reject },
      amounts: {
        mode: "reject_unchanged",
        invoice,
        previous,
        total: previous,
        remaining: invoice - previous,
        receipt: null,
      },
    };
  }

  const input: PartialAmountInput = params.amountInput ?? {
    mode: "legacy_cumulative",
    value: params.amountPaidConfirmed,
  };
  const value = toMinorUnits(input.value);
  if (value === null || value <= 0) {
    return invalid("المبلغ يجب أن يكون أكبر من صفر وبحد أقصى منزلتين عشريتين");
  }

  let total: number;
  if (input.mode === "receipt") {
    total = previous + value;
  } else {
    if (value <= previous) {
      return invalid(
        `الإجمالي المؤكد يجب أن يكون أكبر من الإجمالي المؤكد سابقاً (${fromMinorUnits(previous)})`,
      );
    }
    total = value;
  }
  if (total > invoice) {
    return invalid(
      `المبلغ يتجاوز المتبقي من الفاتورة (${fromMinorUnits(invoice - previous)})`,
    );
  }
  if (total === invoice) {
    return invalid("المبلغ يغطي كامل الفاتورة — استخدم الاعتماد الكامل بدل السداد الجزئي");
  }

  return {
    ok: true,
    previousStatus: status,
    patch: {
      reviewStatus: REVIEW_STATUS_BY_DECISION.partial,
      amountPaidConfirmed: fromMinorUnits(total),
      remainingAmount: fromMinorUnits(invoice - total),
    },
    amounts: {
      mode: input.mode,
      invoice,
      previous,
      total,
      remaining: invoice - total,
      receipt: total - previous,
    },
  };
}

/**
 * One audit entry per review cycle (a resubmitted proof opens a new cycle).
 * Server-issued cycles key it directly; legacy payments fall back to the
 * submission time.
 */
export function paymentReviewAuditId(
  paymentId: string,
  proofSubmittedAt: unknown,
  proofCycleId?: string,
): string {
  if (proofCycleId) return `payment_review_${paymentId}_c_${proofCycleId}`;
  let cycle = "initial";
  if (proofSubmittedAt instanceof Timestamp) {
    cycle = String(proofSubmittedAt.toMillis());
  }
  return `payment_review_${paymentId}_${cycle}`;
}

export type ParsedReviewRequest = {
  paymentId: string;
  decision: PaymentReviewDecision;
  notes: string;
  /** Present only for the current contract (idempotent + proof-bound). */
  idempotency?: {
    requestId: string;
    expectedProofFileName: string;
    /** Empty when the reviewer's item had no server-issued cycle. */
    expectedProofCycleId: string;
    fingerprint: string;
  };
  amountInput?: PartialAmountInput;
  legacyAmountPaidConfirmed?: unknown;
};

function isCurrentContract(data: Record<string, unknown>): boolean {
  return [
    "requestId",
    "expectedProofFileName",
    "expectedProofCycleId",
    "amountMode",
    "amountValue",
  ].some((key) => data[key] !== undefined);
}

/**
 * sha256 over the normalized intent; any difference is a different request.
 * The cycle is appended only when present so pre-cycle fingerprints are
 * unchanged.
 */
export function paymentReviewFingerprint(parts: {
  paymentId: string;
  decision: PaymentReviewDecision;
  amountMode: AmountInputMode | null;
  amountValueMinor: number | null;
  notes: string;
  expectedProofFileName: string;
  expectedProofCycleId?: string;
}): string {
  const fields: unknown[] = [
    parts.paymentId,
    parts.decision,
    parts.amountMode,
    parts.amountValueMinor,
    parts.notes,
    parts.expectedProofFileName,
  ];
  if (parts.expectedProofCycleId) fields.push(parts.expectedProofCycleId);
  return createHash("sha256").update(JSON.stringify(fields)).digest("hex");
}

export function parseReviewRequest(
  data: Record<string, unknown>,
): ParsedReviewRequest {
  const paymentId = requireText(data.paymentId, "paymentId");
  const decision = parseDecision(data.decision);
  const notes = optionalText(data.notes, MAX_REVIEW_NOTES_LENGTH);
  const notesViolation = contactInfoViolation(notes);
  if (notesViolation) {
    throw new HttpsError("invalid-argument", notesViolation);
  }

  if (!isCurrentContract(data)) {
    return {
      paymentId,
      decision,
      notes,
      legacyAmountPaidConfirmed:
        decision === "partial" ? data.amountPaidConfirmed : undefined,
    };
  }

  const requestId = typeof data.requestId === "string" ? data.requestId.trim() : "";
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    throw new HttpsError("invalid-argument", "معرّف الطلب غير صالح");
  }
  const expectedProofFileName =
    typeof data.expectedProofFileName === "string"
      ? data.expectedProofFileName.trim()
      : "";
  if (!PROOF_FILE_NAME_PATTERN.test(expectedProofFileName)) {
    throw new HttpsError("invalid-argument", "بيانات الإيصال المراجَع غير صالحة");
  }
  let expectedProofCycleId = "";
  if (data.expectedProofCycleId !== undefined && data.expectedProofCycleId !== null) {
    expectedProofCycleId =
      typeof data.expectedProofCycleId === "string" ? data.expectedProofCycleId.trim() : "";
    if (!PROOF_CYCLE_ID_PATTERN.test(expectedProofCycleId)) {
      throw new HttpsError("invalid-argument", "بيانات الإيصال المراجَع غير صالحة");
    }
  }
  if (data.amountPaidConfirmed !== undefined) {
    throw new HttpsError(
      "invalid-argument",
      "amountPaidConfirmed غير مسموح مع amountMode / amountValue",
    );
  }

  let amountInput: PartialAmountInput | undefined;
  let amountMode: AmountInputMode | null = null;
  let amountValueMinor: number | null = null;
  if (decision === "partial") {
    if (
      typeof data.amountMode !== "string" ||
      !(AMOUNT_INPUT_MODES as readonly string[]).includes(data.amountMode)
    ) {
      throw new HttpsError("invalid-argument", "طريقة إدخال المبلغ غير صالحة");
    }
    amountMode = data.amountMode as AmountInputMode;
    amountValueMinor = toMinorUnits(data.amountValue);
    if (amountValueMinor === null || amountValueMinor <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "المبلغ يجب أن يكون أكبر من صفر وبحد أقصى منزلتين عشريتين",
      );
    }
    amountInput = { mode: amountMode, value: data.amountValue };
  } else if (data.amountMode !== undefined || data.amountValue !== undefined) {
    throw new HttpsError(
      "invalid-argument",
      "لا يُقبل مبلغ مع قرار الاعتماد أو الرفض",
    );
  }

  return {
    paymentId,
    decision,
    notes,
    amountInput,
    idempotency: {
      requestId,
      expectedProofFileName,
      expectedProofCycleId,
      fingerprint: paymentReviewFingerprint({
        paymentId,
        decision,
        amountMode,
        amountValueMinor,
        notes,
        expectedProofFileName,
        expectedProofCycleId,
      }),
    },
  };
}

export type ReviewPaymentProofResult = {
  paymentId: string;
  reviewStatus: string;
  status: string;
  amount: number;
  previousAmountPaidConfirmed: number;
  amountPaidConfirmed: number;
  remainingAmount: number;
  receiptAmount: number | null;
  amountMode: ReviewAmountMode;
  replayed: boolean;
};

export async function reviewPaymentProofCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<ReviewPaymentProofResult> {
  const uid = requireCallerUid(callerUid);
  const request = parseReviewRequest(data);
  const { paymentId, decision, notes, idempotency } = request;

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
  const requestRef = idempotency
    ? db
      .collection(PAYMENT_REVIEW_REQUESTS_COLLECTION)
      .doc(`${uid}_${idempotency.requestId}`)
    : null;

  return db.runTransaction(async (tx) => {
    // Idempotency first: a recorded request replays its stored result without
    // re-reading or re-reviewing the (possibly since-resubmitted) payment.
    if (requestRef && idempotency) {
      const prior = await tx.get(requestRef);
      if (prior.exists) {
        const recorded = prior.data() ?? {};
        if (
          recorded.actorId !== uid ||
          recorded.paymentId !== paymentId ||
          recorded.fingerprint !== idempotency.fingerprint
        ) {
          throw new HttpsError("failed-precondition", REQUEST_ID_REUSED_MESSAGE);
        }
        return {
          ...(recorded.result as Omit<ReviewPaymentProofResult, "replayed">),
          replayed: true,
        };
      }
    }

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

    // A request bound to an older proof never reviews a newer resubmission.
    const storedCycle =
      typeof payment.proofCycleId === "string" ? payment.proofCycleId : "";
    if (storedCycle) {
      if (!idempotency || !idempotency.expectedProofCycleId) {
        throw new HttpsError("failed-precondition", PROOF_CYCLE_REQUIRED_MESSAGE);
      }
      if (idempotency.expectedProofCycleId !== storedCycle) {
        throw new HttpsError("failed-precondition", PROOF_CHANGED_MESSAGE);
      }
    } else if (idempotency?.expectedProofCycleId) {
      throw new HttpsError("failed-precondition", PROOF_CHANGED_MESSAGE);
    }
    if (idempotency) {
      const storedProof =
        typeof payment.proofFileName === "string" ? payment.proofFileName.trim() : "";
      if (!storedProof || storedProof !== idempotency.expectedProofFileName) {
        throw new HttpsError("failed-precondition", PROOF_CHANGED_MESSAGE);
      }
    }

    const outcome = decidePaymentReview({
      payment,
      decision,
      amountPaidConfirmed: request.legacyAmountPaidConfirmed,
      amountInput: request.amountInput,
    });
    if (!outcome.ok) {
      throw new HttpsError(outcome.code, outcome.message);
    }

    const auditId = paymentReviewAuditId(paymentId, payment.proofSubmittedAt, storedCycle);
    const auditRef = db.collection(AUDIT_LOGS_COLLECTION).doc(auditId);
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

    const { amounts } = outcome;
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
            amount: fromMinorUnits(amounts.invoice),
            amountMode: amounts.mode,
            ...(amounts.receipt === null
              ? {}
              : { receiptAmount: fromMinorUnits(amounts.receipt) }),
            previousAmountPaidConfirmed: fromMinorUnits(amounts.previous),
            amountPaidConfirmed: fromMinorUnits(amounts.total),
            remainingAmount: fromMinorUnits(amounts.remaining),
            ...(idempotency ? { requestId: idempotency.requestId } : {}),
            ...(storedCycle ? { proofCycleId: storedCycle } : {}),
          },
          source: "reviewPaymentProof",
        },
        FieldValue.serverTimestamp(),
      ),
    );

    const result: Omit<ReviewPaymentProofResult, "replayed"> = {
      paymentId,
      reviewStatus: outcome.patch.reviewStatus,
      status: newStatus,
      amount: fromMinorUnits(amounts.invoice),
      previousAmountPaidConfirmed: fromMinorUnits(amounts.previous),
      amountPaidConfirmed: fromMinorUnits(amounts.total),
      remainingAmount: fromMinorUnits(amounts.remaining),
      receiptAmount: amounts.receipt === null ? null : fromMinorUnits(amounts.receipt),
      amountMode: amounts.mode,
    };

    if (requestRef && idempotency) {
      tx.create(requestRef, {
        paymentId,
        actorId: uid,
        actorRole: actor.actorRole,
        decision,
        fingerprint: idempotency.fingerprint,
        ...(storedCycle ? { proofCycleId: storedCycle } : {}),
        auditLogId: auditId,
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return { ...result, replayed: false };
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
