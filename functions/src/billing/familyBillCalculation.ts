/**
 * Family bill calculation (docs/production/BILLING_PAYMENT_CONTRACT.md §4).
 *
 * Pure and Firebase-free: the single authoritative way to turn per-child
 * monthly fees and an optional family discount into a bill. All money is in
 * integer minor units (piasters); no floating-point arithmetic is used.
 *
 * Rules:
 *   - Children not due for the period are excluded (listed, never charged).
 *   - A due child without a valid positive fee fails the whole bill
 *     (`fee_not_configured`); a missing fee is never treated as zero.
 *   - The family discount applies only when at least two children are due.
 *   - Percentage discounts are basis points (1 bp = 0.01 %), rounded down to
 *     the piaster. Every discount is capped at the subtotal.
 *   - The discount is allocated across lines proportionally to their fees
 *     (largest remainder, ties by input order), so the line amounts always
 *     sum exactly to the bill total and no line goes below zero.
 *   - Duplicate student ids are rejected so a child can never be billed twice.
 */

export const FAMILY_DISCOUNT_MIN_DUE_CHILDREN = 2;
export const BASIS_POINTS_PER_WHOLE = 10_000;

export type FamilyDiscountRule =
  | { type: "fixed"; valueMinor: number }
  | { type: "percentage"; basisPoints: number };

export type FamilyBillChildInput = {
  studentId: string;
  /** Due for this billing period (active, billable from this month on). */
  due: boolean;
  /** Monthly fee in minor units; `null` when no fee is configured. */
  feeMinor: number | null;
};

export type FamilyBillLine = {
  studentId: string;
  feeMinor: number;
  discountMinor: number;
  amountMinor: number;
};

export type FamilyBillCalculation =
  | {
    ok: true;
    lines: FamilyBillLine[];
    subtotalMinor: number;
    discountMinor: number;
    totalMinor: number;
    /** The rule actually applied; `null` when none was eligible. */
    appliedDiscount: FamilyDiscountRule | null;
    excludedStudentIds: string[];
  }
  | {
    ok: false;
    reason: FamilyBillFailureReason;
    studentIds: string[];
  };

export type FamilyBillFailureReason =
  | "invalid_input"
  | "invalid_discount"
  | "fee_not_configured"
  | "no_children_due";

function isPositiveMinor(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0;
}

function fail(
  reason: FamilyBillFailureReason,
  studentIds: string[] = [],
): FamilyBillCalculation {
  return { ok: false, reason, studentIds };
}

export function isValidFamilyDiscountRule(rule: unknown): rule is FamilyDiscountRule {
  if (rule === null || typeof rule !== "object") return false;
  const r = rule as Record<string, unknown>;
  if (r.type === "fixed") return isPositiveMinor(r.valueMinor);
  if (r.type === "percentage") {
    return (
      typeof r.basisPoints === "number" &&
      Number.isSafeInteger(r.basisPoints) &&
      r.basisPoints > 0 &&
      r.basisPoints <= BASIS_POINTS_PER_WHOLE
    );
  }
  return false;
}

/** Discount for [subtotalMinor] under [rule], rounded down, capped at the subtotal. */
export function familyDiscountMinor(
  subtotalMinor: number,
  rule: FamilyDiscountRule,
): number {
  const raw =
    rule.type === "fixed"
      ? BigInt(rule.valueMinor)
      : (BigInt(subtotalMinor) * BigInt(rule.basisPoints)) /
        BigInt(BASIS_POINTS_PER_WHOLE);
  const capped = raw > BigInt(subtotalMinor) ? BigInt(subtotalMinor) : raw;
  return Number(capped);
}

/** Proportional split of [discountMinor] over [fees]; shares sum exactly. */
export function allocateDiscount(fees: number[], discountMinor: number): number[] {
  const subtotal = fees.reduce((a, b) => a + BigInt(b), BigInt(0));
  if (discountMinor === 0 || subtotal === BigInt(0)) return fees.map(() => 0);
  const d = BigInt(discountMinor);
  const shares = fees.map((fee) => (d * BigInt(fee)) / subtotal);
  const remainders = fees.map((fee, i) => ({
    i,
    rem: (d * BigInt(fee)) % subtotal,
  }));
  let left = d - shares.reduce((a, b) => a + b, BigInt(0));
  remainders.sort((a, b) => (a.rem === b.rem ? a.i - b.i : a.rem > b.rem ? -1 : 1));
  for (const { i } of remainders) {
    if (left === BigInt(0)) break;
    shares[i] += BigInt(1);
    left -= BigInt(1);
  }
  return shares.map(Number);
}

export function calculateFamilyBill(params: {
  children: FamilyBillChildInput[];
  discount?: FamilyDiscountRule | null;
}): FamilyBillCalculation {
  const { children } = params;
  const discount = params.discount ?? null;
  if (!Array.isArray(children)) return fail("invalid_input");

  const seen = new Set<string>();
  const duplicates: string[] = [];
  for (const child of children) {
    const id = typeof child?.studentId === "string" ? child.studentId.trim() : "";
    if (!id || typeof child.due !== "boolean") return fail("invalid_input");
    if (seen.has(id)) duplicates.push(id);
    seen.add(id);
  }
  if (duplicates.length > 0) return fail("invalid_input", duplicates);
  if (discount !== null && !isValidFamilyDiscountRule(discount)) {
    return fail("invalid_discount");
  }

  const due = children.filter((c) => c.due);
  const excludedStudentIds = children.filter((c) => !c.due).map((c) => c.studentId.trim());
  if (due.length === 0) return fail("no_children_due", excludedStudentIds);

  const unpriced = due.filter((c) => !isPositiveMinor(c.feeMinor)).map((c) => c.studentId.trim());
  if (unpriced.length > 0) return fail("fee_not_configured", unpriced);

  const fees = due.map((c) => c.feeMinor as number);
  const subtotal = fees.reduce((a, b) => a + BigInt(b), BigInt(0));
  if (subtotal > BigInt(Number.MAX_SAFE_INTEGER)) return fail("invalid_input");
  const subtotalMinor = Number(subtotal);

  const eligible = discount !== null && due.length >= FAMILY_DISCOUNT_MIN_DUE_CHILDREN;
  const discountMinor = eligible ? familyDiscountMinor(subtotalMinor, discount) : 0;
  const shares = allocateDiscount(fees, discountMinor);

  const lines = due.map((c, i) => ({
    studentId: c.studentId.trim(),
    feeMinor: fees[i],
    discountMinor: shares[i],
    amountMinor: fees[i] - shares[i],
  }));
  const totalMinor = subtotalMinor - discountMinor;
  const lineSum = lines.reduce((a, l) => a + l.amountMinor, 0);
  if (lineSum !== totalMinor || lines.some((l) => l.amountMinor < 0)) {
    throw new Error("family bill invariant violated");
  }

  return {
    ok: true,
    lines,
    subtotalMinor,
    discountMinor,
    totalMinor,
    appliedDiscount: eligible ? discount : null,
    excludedStudentIds,
  };
}
