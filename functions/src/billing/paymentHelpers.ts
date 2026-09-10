/**
 * Pure helpers for WA-3/WA-5 payment + invoice (unit-testable).
 */

export const PAYMENT_ACCESS_STATUSES = [
  "ok",
  "reminded",
  "due_warning",
  "in_grace",
  "suspended",
] as const;

export type PaymentAccessStatus = (typeof PAYMENT_ACCESS_STATUSES)[number];

export function isValidPaymentAccessStatus(
  raw: unknown,
): raw is PaymentAccessStatus {
  return (
    typeof raw === "string" &&
    (PAYMENT_ACCESS_STATUSES as readonly string[]).includes(raw)
  );
}

export function periodKeyForDate(date: Date): string {
  const y = date.getUTCFullYear().toString().padStart(4, "0");
  const m = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  return `${y}-${m}`;
}

export function invoiceDocId(studentId: string, periodKey: string): string {
  return `inv_${studentId.trim()}_${periodKey.trim()}`;
}

export type PricingRuleLike = {
  id: string;
  scope?: string;
  scopeId?: string | null;
  amount?: number;
  currency?: string;
  billingPeriod?: string;
  active?: boolean;
  version?: number;
  effectiveFrom?: Date | null;
  effectiveTo?: Date | null;
};

export function ruleIsEffectiveAt(
  rule: PricingRuleLike,
  at: Date,
): boolean {
  if (rule.active === false) return false;
  if (rule.effectiveFrom && at < rule.effectiveFrom) return false;
  if (rule.effectiveTo && at > rule.effectiveTo) return false;
  return true;
}

/** Prefer student → halaqa → academy_default among active effective rules.
 * C4 scope values are IMPLEMENTATION-DEFINED BUT SAFE; most-specific-wins.
 */
export function selectApplicableRule(params: {
  rules: PricingRuleLike[];
  studentId: string;
  halaqaId?: string | null;
  at?: Date;
}): PricingRuleLike | null {
  const at = params.at ?? new Date();
  const active = params.rules.filter((r) => ruleIsEffectiveAt(r, at));
  const student = active.find(
    (r) => r.scope === "student" && r.scopeId === params.studentId,
  );
  if (student) return student;
  if (params.halaqaId) {
    const halaqa = active.find(
      (r) => r.scope === "halaqa" && r.scopeId === params.halaqaId,
    );
    if (halaqa) return halaqa;
  }
  return (
    active.find((r) => r.scope === "academy_default") ??
    active.find((r) => !r.scope || r.scope === "academy_default") ??
    null
  );
}

export function assertPositiveAmount(amount: unknown): number {
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new Error("pricing rule amount must be a positive number");
  }
  return amount;
}
