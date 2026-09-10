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
