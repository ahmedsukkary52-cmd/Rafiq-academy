/**
 * WA-3 / WA-5 pure billing helpers (no emulator).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function loadHelpers() {
  const resolved = require.resolve("../lib/billing/paymentHelpers.js");
  delete require.cache[resolved];
  return require("../lib/billing/paymentHelpers.js");
}

test("paymentAccess status validation", () => {
  const h = loadHelpers();
  assert.equal(h.isValidPaymentAccessStatus("ok"), true);
  assert.equal(h.isValidPaymentAccessStatus("suspended"), true);
  assert.equal(h.isValidPaymentAccessStatus("paid"), false);
  assert.equal(h.isValidPaymentAccessStatus(""), false);
});

test("periodKey + invoiceDocId idempotency key", () => {
  const h = loadHelpers();
  assert.equal(h.periodKeyForDate(new Date(Date.UTC(2026, 8, 10))), "2026-09");
  assert.equal(h.invoiceDocId("stu1", "2026-09"), "inv_stu1_2026-09");
});

function loadAdminBilling() {
  const resolved = require.resolve("../lib/admin/adminBilling.js");
  delete require.cache[resolved];
  return require("../lib/admin/adminBilling.js");
}

/** Cairo calendar day of an instant, independent of the machine time zone. */
function cairoDay(instant) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(instant);
}

function lastDayOfMonth(year, month) {
  const day = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

test("default due date is the last Cairo day of every month 2024–2027", () => {
  const h = loadHelpers();
  const mismatches = [];
  for (let year = 2024; year <= 2027; year++) {
    for (let month = 1; month <= 12; month++) {
      const periodKey = `${year}-${String(month).padStart(2, "0")}`;
      const got = cairoDay(h.defaultInvoiceDueDate(periodKey));
      const expected = lastDayOfMonth(year, month);
      if (got !== expected) mismatches.push(`${periodKey}: ${got} != ${expected}`);
    }
  }
  assert.deepEqual(mismatches, []);
});

test("default due date in summer time (April, September) stays in the month", () => {
  const h = loadHelpers();
  assert.equal(cairoDay(h.defaultInvoiceDueDate("2026-04")), "2026-04-30");
  assert.equal(cairoDay(h.defaultInvoiceDueDate("2026-09")), "2026-09-30");
  assert.equal(h.defaultInvoiceDueDate("2026-04").toISOString(), "2026-04-30T09:00:00.000Z");
  assert.equal(h.defaultInvoiceDueDate("2026-09").toISOString(), "2026-09-30T09:00:00.000Z");
});

test("default due date in October across the summer-time transition", () => {
  const h = loadHelpers();
  // 2024: summer time ends at the end of Oct 31 itself.
  assert.equal(cairoDay(h.defaultInvoiceDueDate("2024-10")), "2024-10-31");
  assert.equal(h.defaultInvoiceDueDate("2024-10").toISOString(), "2024-10-31T09:00:00.000Z");
  // 2026: summer time ended on Oct 29, so Oct 31 is standard time.
  assert.equal(cairoDay(h.defaultInvoiceDueDate("2026-10")), "2026-10-31");
  assert.equal(h.defaultInvoiceDueDate("2026-10").toISOString(), "2026-10-31T10:00:00.000Z");
});

test("default due date in standard time (January, February)", () => {
  const h = loadHelpers();
  assert.equal(h.defaultInvoiceDueDate("2026-01").toISOString(), "2026-01-31T10:00:00.000Z");
  assert.equal(cairoDay(h.defaultInvoiceDueDate("2024-02")), "2024-02-29");
  assert.equal(cairoDay(h.defaultInvoiceDueDate("2026-02")), "2026-02-28");
});

test("explicit dueDateIso bypasses the default unchanged", () => {
  const { dueDateFromInput } = loadAdminBilling();
  const iso = "2026-05-15T08:30:00.000Z";
  assert.equal(dueDateFromInput(iso, "2026-04").toISOString(), iso);
  assert.equal(dueDateFromInput("2026-07-31T21:00:00Z", "2026-07").toISOString(), "2026-07-31T21:00:00.000Z");
  assert.throws(() => dueDateFromInput("not-a-date", "2026-04"), { code: "invalid-argument" });
  assert.equal(dueDateFromInput(undefined, "2026-04").toISOString(), "2026-04-30T09:00:00.000Z");
});

test("selectApplicableRule prefers student then halaqa then default", () => {
  const h = loadHelpers();
  const rules = [
    { id: "def", scope: "academy_default", amount: 100, active: true, version: 1 },
    { id: "h1", scope: "halaqa", scopeId: "halaqaA", amount: 150, active: true, version: 1 },
    { id: "s1", scope: "student", scopeId: "stu1", amount: 200, active: true, version: 2 },
  ];
  const selected = h.selectApplicableRule({
    rules,
    studentId: "stu1",
    halaqaId: "halaqaA",
  });
  assert.equal(selected.id, "s1");
  assert.equal(selected.amount, 200);
});

test("assertPositiveAmount rejects client-like zero/negative", () => {
  const h = loadHelpers();
  assert.throws(() => h.assertPositiveAmount(0));
  assert.throws(() => h.assertPositiveAmount(-5));
  assert.equal(h.assertPositiveAmount(120), 120);
});

test("index exports WA-5 callables and keeps Paymob quarantined", async () => {
  const { readFileSync } = await import("node:fs");
  const { join, dirname } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const root = join(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "src",
    "index.ts",
  );
  const src = readFileSync(root, "utf8");
  assert.match(src, /adminGenerateInvoice/);
  assert.match(src, /adminReinstatePaymentAccess/);
  assert.doesNotMatch(src, /^export \{ createPaymentIntention/m);
});

test("adminBilling exposes system issuer issueInvoiceFromPricing", async () => {
  const { readFileSync } = await import("node:fs");
  const { join, dirname } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const billing = join(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "src",
    "admin",
    "adminBilling.ts",
  );
  const src = readFileSync(billing, "utf8");
  assert.match(src, /export async function issueInvoiceFromPricing/);
  assert.match(src, /system-owned invoice issuer/);
});
