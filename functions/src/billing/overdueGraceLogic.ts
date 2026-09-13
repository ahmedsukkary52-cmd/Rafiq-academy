/**
 * WA-6 / C5 — pure overdue + paymentAccess state machine (unit-testable).
 * Computes target from dueDate + grace; never auto-reinstates suspended→ok.
 */

import {
  cairoCalendarDaysBetween,
  cairoGraceEndsAtInstant,
  cairoYmd,
} from "./cairoTime";
import { PaymentAccessStatus } from "./paymentHelpers";

/** Pre-due reminder window (Cairo days). IMPLEMENTATION-DEFINED BUT SAFE. */
export const DEFAULT_REMINDER_LEAD_DAYS = 3;

export const ACCESS_SEVERITY: Record<PaymentAccessStatus, number> = {
  ok: 0,
  reminded: 1,
  due_warning: 2,
  in_grace: 3,
  suspended: 4,
};

export type UnpaidInvoiceLike = {
  id: string;
  studentId: string;
  parentId: string;
  dueDate: Date;
  status: string;
};

export type AccessTarget = {
  status: PaymentAccessStatus;
  reason: string;
  primaryInvoiceId: string | null;
  affectedStudentIds: string[];
  graceEndsAt: Date | null;
  setWarningIssuedAt: boolean;
  setLastReminderAt: boolean;
  setSuspendedAt: boolean;
};

export type PaymentMutation = {
  paymentId: string;
  setOverdue: boolean;
};

/** Days past due on Cairo calendar: 0 = due day, negative = before due. */
export function cairoDaysPastDue(dueDate: Date, now: Date): number {
  return cairoCalendarDaysBetween(cairoYmd(dueDate), cairoYmd(now));
}

/**
 * Target access status for a single unpaid invoice.
 * gracePeriodDays === 0 ⇒ suspend as soon as due day is reached.
 */
export function accessStatusForUnpaidInvoice(params: {
  daysPastDue: number;
  gracePeriodDays: number;
  reminderLeadDays?: number;
}): PaymentAccessStatus {
  const grace = Math.max(0, Math.floor(params.gracePeriodDays));
  const lead = Math.max(
    0,
    Math.floor(params.reminderLeadDays ?? DEFAULT_REMINDER_LEAD_DAYS),
  );
  const d = params.daysPastDue;

  if (d >= grace) return "suspended";
  if (d >= 0) {
    if (grace === 0) return "suspended";
    if (d === 0) return "due_warning";
    return "in_grace";
  }
  if (lead > 0 && d >= -lead) return "reminded";
  return "ok";
}

export function isUnpaidPaymentStatus(status: string): boolean {
  const s = (status || "").trim();
  return s === "due" || s === "overdue";
}

function isWorseOrEarlier(
  candidateStatus: PaymentAccessStatus,
  candidateDue: Date,
  bestStatus: PaymentAccessStatus,
  bestDue: Date | null,
): boolean {
  const c = ACCESS_SEVERITY[candidateStatus];
  const b = ACCESS_SEVERITY[bestStatus];
  if (c > b) return true;
  if (c < b) return false;
  if (bestDue === null) return true;
  return candidateDue.getTime() < bestDue.getTime();
}

/**
 * Aggregate unpaid invoices for one parent into the worst access target.
 */
export function computeParentAccessTarget(params: {
  unpaid: UnpaidInvoiceLike[];
  childrenIds: string[];
  gracePeriodDays: number;
  now: Date;
  reminderLeadDays?: number;
}): AccessTarget {
  const unpaid = params.unpaid.filter((p) => isUnpaidPaymentStatus(p.status));
  if (unpaid.length === 0) {
    return {
      status: "ok",
      reason: "no_unpaid_invoices",
      primaryInvoiceId: null,
      affectedStudentIds: [...new Set(params.childrenIds)].sort(),
      graceEndsAt: null,
      setWarningIssuedAt: false,
      setLastReminderAt: false,
      setSuspendedAt: false,
    };
  }

  let worst: PaymentAccessStatus = "ok";
  let primary: UnpaidInvoiceLike | null = null;

  for (const inv of unpaid) {
    const days = cairoDaysPastDue(inv.dueDate, params.now);
    const st = accessStatusForUnpaidInvoice({
      daysPastDue: days,
      gracePeriodDays: params.gracePeriodDays,
      reminderLeadDays: params.reminderLeadDays,
    });
    if (
      isWorseOrEarlier(
        st,
        inv.dueDate,
        worst,
        primary?.dueDate ?? null,
      )
    ) {
      worst = st;
      primary = inv;
    }
  }

  const affected = new Set<string>(params.childrenIds);
  for (const inv of unpaid) {
    if (inv.studentId) affected.add(inv.studentId);
  }

  const graceEndsAt =
    primary && worst !== "ok"
      ? cairoGraceEndsAtInstant(
          cairoYmd(primary.dueDate),
          params.gracePeriodDays,
        )
      : null;

  return {
    status: worst,
    reason: `invoice_${worst}`,
    primaryInvoiceId: primary?.id ?? null,
    affectedStudentIds: [...affected].sort(),
    graceEndsAt,
    setWarningIssuedAt:
      worst === "due_warning" ||
      worst === "in_grace" ||
      worst === "suspended",
    setLastReminderAt: worst === "reminded",
    setSuspendedAt: worst === "suspended",
  };
}

/**
 * Never auto-clear access after due/grace entry.
 * C2: suspended → ok is Admin reinstate only.
 * C5.3: payment approved during grace → access remains until Admin reinstate.
 * Severity may still advance (due_warning → in_grace → suspended) from dueDate+grace.
 */
export function resolveAccessTransition(params: {
  currentStatus: PaymentAccessStatus | null;
  target: AccessTarget;
}): AccessTarget {
  const current = params.currentStatus;
  const target = params.target;

  const lockedAgainstAutoOk =
    current === "suspended" ||
    current === "in_grace" ||
    current === "due_warning";

  if (!lockedAgainstAutoOk) return target;

  // Still unpaid / worse: allow catch-up toward suspended.
  if (ACCESS_SEVERITY[target.status] > ACCESS_SEVERITY[current]) {
    return target;
  }

  // Same severity: keep computed fields (primary, affected, graceEndsAt).
  if (target.status === current) return target;

  // Target is ok or milder (e.g. all paid) — do not auto-reinstate / auto-clear.
  return {
    ...target,
    status: current,
    reason:
      target.status === "ok"
        ? "awaiting_admin_reinstate"
        : target.reason,
    setSuspendedAt: false,
    setWarningIssuedAt: false,
    setLastReminderAt: false,
  };
}

export function shouldMarkPaymentOverdue(params: {
  status: string;
  dueDate: Date;
  now: Date;
}): boolean {
  if (params.status === "paid" || params.status === "overdue") return false;
  if (params.status !== "due") return false;
  return cairoDaysPastDue(params.dueDate, params.now) >= 0;
}

export function paymentMutationsForUnpaid(
  unpaid: UnpaidInvoiceLike[],
  now: Date,
): PaymentMutation[] {
  return unpaid
    .filter((p) =>
      shouldMarkPaymentOverdue({
        status: p.status,
        dueDate: p.dueDate,
        now,
      }),
    )
    .map((p) => ({ paymentId: p.id, setOverdue: true }));
}
