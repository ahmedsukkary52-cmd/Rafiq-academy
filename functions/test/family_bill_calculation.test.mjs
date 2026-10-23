/**
 * Batch A — pure family bill calculation (no emulator, no Firebase).
 * Amounts are illustrative minor units, not academy prices.
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";

const require = createRequire(import.meta.url);
const calc = require("../lib/billing/familyBillCalculation.js");
const { calculateFamilyBill, allocateDiscount, familyDiscountMinor } = calc;

const child = (studentId, feeMinor, due = true) => ({ studentId, feeMinor, due });

function assertBalanced(result) {
  assert.equal(result.ok, true);
  const sum = result.lines.reduce((a, l) => a + l.amountMinor, 0);
  assert.equal(sum, result.totalMinor);
  assert.equal(result.subtotalMinor - result.discountMinor, result.totalMinor);
  for (const l of result.lines) {
    assert.ok(Number.isSafeInteger(l.amountMinor) && l.amountMinor >= 0);
    assert.equal(l.feeMinor - l.discountMinor, l.amountMinor);
  }
}

test("single child: fee only, discount never applied", () => {
  const r = calculateFamilyBill({
    children: [child("s1", 30000)],
    discount: { type: "percentage", basisPoints: 1000 },
  });
  assertBalanced(r);
  assert.equal(r.totalMinor, 30000);
  assert.equal(r.discountMinor, 0);
  assert.equal(r.appliedDiscount, null);
});

test("two children with a fixed family discount", () => {
  const r = calculateFamilyBill({
    children: [child("s1", 30000), child("s2", 20000)],
    discount: { type: "fixed", valueMinor: 5000 },
  });
  assertBalanced(r);
  assert.equal(r.subtotalMinor, 50000);
  assert.equal(r.discountMinor, 5000);
  assert.equal(r.totalMinor, 45000);
  assert.deepEqual(r.lines.map((l) => l.discountMinor), [3000, 2000]);
  assert.deepEqual(r.appliedDiscount, { type: "fixed", valueMinor: 5000 });
});

test("percentage discount is rounded down to the piaster", () => {
  // 3333 + 3334 = 6667; 15% = 1000.05 -> 1000
  const r = calculateFamilyBill({
    children: [child("s1", 3333), child("s2", 3334)],
    discount: { type: "percentage", basisPoints: 1500 },
  });
  assertBalanced(r);
  assert.equal(r.discountMinor, 1000);
  assert.equal(familyDiscountMinor(999, { type: "percentage", basisPoints: 3333 }), 332);
});

test("children not due are excluded and never charged", () => {
  const r = calculateFamilyBill({
    children: [child("s1", 30000), child("s2", 20000, false), child("s3", 10000)],
    discount: { type: "fixed", valueMinor: 4000 },
  });
  assertBalanced(r);
  assert.deepEqual(r.lines.map((l) => l.studentId), ["s1", "s3"]);
  assert.deepEqual(r.excludedStudentIds, ["s2"]);
  assert.equal(r.subtotalMinor, 40000);
});

test("no discount when fewer than two children are due", () => {
  const r = calculateFamilyBill({
    children: [child("s1", 30000), child("s2", 20000, false)],
    discount: { type: "fixed", valueMinor: 4000 },
  });
  assertBalanced(r);
  assert.equal(r.discountMinor, 0);
  assert.equal(r.appliedDiscount, null);
  assert.equal(r.totalMinor, 30000);
});

test("a missing or invalid fee fails the bill instead of counting as zero", () => {
  for (const fee of [null, undefined, 0, -100, 12.5, Number.NaN, "300"]) {
    const r = calculateFamilyBill({ children: [child("s1", 30000), child("s2", fee)] });
    assert.equal(r.ok, false, String(fee));
    assert.equal(r.reason, "fee_not_configured");
    assert.deepEqual(r.studentIds, ["s2"]);
  }
});

test("a missing fee on a child who is not due does not block the bill", () => {
  const r = calculateFamilyBill({ children: [child("s1", 30000), child("s2", null, false)] });
  assertBalanced(r);
  assert.equal(r.totalMinor, 30000);
});

test("nobody due is reported, not billed at zero", () => {
  const r = calculateFamilyBill({ children: [child("s1", 30000, false)] });
  assert.deepEqual(r, { ok: false, reason: "no_children_due", studentIds: ["s1"] });
});

test("discounts are capped at the subtotal", () => {
  const fixed = calculateFamilyBill({
    children: [child("s1", 1000), child("s2", 2000)],
    discount: { type: "fixed", valueMinor: 999999 },
  });
  assertBalanced(fixed);
  assert.equal(fixed.discountMinor, 3000);
  assert.equal(fixed.totalMinor, 0);
  const full = calculateFamilyBill({
    children: [child("s1", 1000), child("s2", 2000)],
    discount: { type: "percentage", basisPoints: 10000 },
  });
  assertBalanced(full);
  assert.equal(full.totalMinor, 0);
});

test("invalid discount rules are rejected, not silently ignored", () => {
  for (const discount of [
    { type: "fixed", valueMinor: 0 },
    { type: "fixed", valueMinor: 10.5 },
    { type: "percentage", basisPoints: 0 },
    { type: "percentage", basisPoints: 10001 },
    { type: "percentage", basisPoints: 12.5 },
    { type: "free" },
  ]) {
    const r = calculateFamilyBill({ children: [child("s1", 1000), child("s2", 1000)], discount });
    assert.equal(r.ok, false, JSON.stringify(discount));
    assert.equal(r.reason, "invalid_discount");
  }
});

test("duplicate children are rejected so nobody is billed twice", () => {
  const r = calculateFamilyBill({ children: [child("s1", 1000), child(" s1 ", 1000)] });
  assert.deepEqual(r, { ok: false, reason: "invalid_input", studentIds: ["s1"] });
});

test("malformed children are rejected", () => {
  assert.equal(calculateFamilyBill({ children: [{ studentId: "", due: true, feeMinor: 1 }] }).reason, "invalid_input");
  assert.equal(calculateFamilyBill({ children: [{ studentId: "s1", feeMinor: 1 }] }).reason, "invalid_input");
  assert.equal(calculateFamilyBill({ children: null }).reason, "invalid_input");
});

test("allocation uses largest remainder and always sums exactly", () => {
  assert.deepEqual(allocateDiscount([1, 1, 1], 2), [1, 1, 0]);
  assert.deepEqual(allocateDiscount([100, 100, 100], 100), [34, 33, 33]);
  for (let d = 0; d <= 3000; d += 7) {
    const shares = allocateDiscount([1000, 1500, 500], d);
    assert.equal(shares.reduce((a, b) => a + b, 0), d);
    shares.forEach((s, i) => assert.ok(s <= [1000, 1500, 500][i]));
  }
});

test("large amounts stay exact (no floating point)", () => {
  const big = 4_000_000_000_000;
  const r = calculateFamilyBill({
    children: [child("s1", big), child("s2", big + 1)],
    discount: { type: "percentage", basisPoints: 3333 },
  });
  assertBalanced(r);
  assert.equal(r.discountMinor, Number((BigInt(2 * big + 1) * 3333n) / 10000n));
  const overflow = calculateFamilyBill({
    children: [child("s1", Number.MAX_SAFE_INTEGER), child("s2", 1)],
  });
  assert.equal(overflow.reason, "invalid_input");
});

test("the module has no Firebase dependency", () => {
  const src = readFileSync(new URL("../src/billing/familyBillCalculation.ts", import.meta.url), "utf8");
  assert.doesNotMatch(src, /firebase|import\s/);
});
