/**
 * WA-6 overdue / grace pure logic tests (no Firebase emulator).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function loadCairo() {
  const resolved = require.resolve("../lib/billing/cairoTime.js");
  delete require.cache[resolved];
  return require("../lib/billing/cairoTime.js");
}

function loadLogic() {
  const resolved = require.resolve("../lib/billing/overdueGraceLogic.js");
  delete require.cache[resolved];
  return require("../lib/billing/overdueGraceLogic.js");
}

/** Build a Date that falls on a given Cairo YMD (approx via UTC noon). */
function onCairoYmd(ymd) {
  const [y, m, d] = ymd.split("-").map(Number);
  // 12:00 UTC is usually same calendar day in Cairo (UTC+2/+3)
  return new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
}

test("Cairo YMD formatting is Africa/Cairo", () => {
  const { cairoYmd, CAIRO_TIME_ZONE } = loadCairo();
  assert.equal(CAIRO_TIME_ZONE, "Africa/Cairo");
  // 2026-09-10 21:30 UTC = Sep 11 early morning Cairo (UTC+3 in Sep)
  const lateUtc = new Date(Date.UTC(2026, 8, 10, 21, 30, 0));
  assert.equal(cairoYmd(lateUtc), "2026-09-11");
});

test("before due date → ok outside reminder window", () => {
  const logic = loadLogic();
  const due = onCairoYmd("2026-09-20");
  const now = onCairoYmd("2026-09-10");
  const days = logic.cairoDaysPastDue(due, now);
  assert.ok(days < -3);
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: days,
      gracePeriodDays: 7,
    }),
    "ok",
  );
});

test("before due date within lead → reminded", () => {
  const logic = loadLogic();
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: -2,
      gracePeriodDays: 7,
      reminderLeadDays: 3,
    }),
    "reminded",
  );
});

test("due day → due_warning + should mark overdue", () => {
  const logic = loadLogic();
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: 0,
      gracePeriodDays: 7,
    }),
    "due_warning",
  );
  const due = onCairoYmd("2026-09-10");
  const now = onCairoYmd("2026-09-10");
  assert.equal(
    logic.shouldMarkPaymentOverdue({ status: "due", dueDate: due, now }),
    true,
  );
});

test("inside grace after due day → in_grace", () => {
  const logic = loadLogic();
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: 3,
      gracePeriodDays: 7,
    }),
    "in_grace",
  );
});

test("grace ended → suspended", () => {
  const logic = loadLogic();
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: 7,
      gracePeriodDays: 7,
    }),
    "suspended",
  );
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: 10,
      gracePeriodDays: 7,
    }),
    "suspended",
  );
});

test("gracePeriodDays 0 suspends on due day", () => {
  const logic = loadLogic();
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: 0,
      gracePeriodDays: 0,
    }),
    "suspended",
  );
});

test("paid payment never marked overdue", () => {
  const logic = loadLogic();
  assert.equal(
    logic.shouldMarkPaymentOverdue({
      status: "paid",
      dueDate: onCairoYmd("2026-09-01"),
      now: onCairoYmd("2026-09-20"),
    }),
    false,
  );
});

test("already overdue is idempotent (no re-mark)", () => {
  const logic = loadLogic();
  assert.equal(
    logic.shouldMarkPaymentOverdue({
      status: "overdue",
      dueDate: onCairoYmd("2026-09-01"),
      now: onCairoYmd("2026-09-20"),
    }),
    false,
  );
});

test("multi invoice / multi student picks worst + earliest primary", () => {
  const logic = loadLogic();
  const now = onCairoYmd("2026-09-20");
  const target = logic.computeParentAccessTarget({
    unpaid: [
      {
        id: "inv_a",
        studentId: "stu1",
        parentId: "p1",
        dueDate: onCairoYmd("2026-09-18"),
        status: "due",
      },
      {
        id: "inv_b",
        studentId: "stu2",
        parentId: "p1",
        dueDate: onCairoYmd("2026-09-01"),
        status: "overdue",
      },
    ],
    childrenIds: ["stu1", "stu2", "stu3"],
    gracePeriodDays: 7,
    now,
  });
  assert.equal(target.status, "suspended");
  assert.equal(target.primaryInvoiceId, "inv_b");
  assert.deepEqual(target.affectedStudentIds, ["stu1", "stu2", "stu3"]);
});

test("suspended never auto-reinstates to ok when all paid", () => {
  const logic = loadLogic();
  const cleared = logic.computeParentAccessTarget({
    unpaid: [],
    childrenIds: ["stu1"],
    gracePeriodDays: 7,
    now: onCairoYmd("2026-09-20"),
  });
  assert.equal(cleared.status, "ok");
  const locked = logic.resolveAccessTransition({
    currentStatus: "suspended",
    target: cleared,
  });
  assert.equal(locked.status, "suspended");
  assert.equal(locked.reason, "awaiting_admin_reinstate");
  assert.equal(locked.setSuspendedAt, false);
});

test("reminded may clear to ok when unpaid invoices disappear (pre-grace)", () => {
  const logic = loadLogic();
  const cleared = logic.computeParentAccessTarget({
    unpaid: [],
    childrenIds: ["stu1"],
    gracePeriodDays: 7,
    now: onCairoYmd("2026-09-20"),
  });
  const next = logic.resolveAccessTransition({
    currentStatus: "reminded",
    target: cleared,
  });
  assert.equal(next.status, "ok");
});

test("C5.3 paid during grace does not auto-clear in_grace/due_warning", () => {
  const logic = loadLogic();
  const cleared = logic.computeParentAccessTarget({
    unpaid: [],
    childrenIds: ["stu1"],
    gracePeriodDays: 7,
    now: onCairoYmd("2026-09-20"),
  });
  assert.equal(cleared.status, "ok");
  for (const current of ["due_warning", "in_grace"]) {
    const locked = logic.resolveAccessTransition({
      currentStatus: current,
      target: cleared,
    });
    assert.equal(locked.status, current);
    assert.equal(locked.reason, "awaiting_admin_reinstate");
  }
});

test("catch-up may advance due_warning → suspended in one pass", () => {
  const logic = loadLogic();
  const target = logic.computeParentAccessTarget({
    unpaid: [
      {
        id: "inv1",
        studentId: "stu1",
        parentId: "p1",
        dueDate: onCairoYmd("2026-09-01"),
        status: "overdue",
      },
    ],
    childrenIds: ["stu1"],
    gracePeriodDays: 7,
    now: onCairoYmd("2026-09-20"),
  });
  assert.equal(target.status, "suspended");
  const advanced = logic.resolveAccessTransition({
    currentStatus: "due_warning",
    target,
  });
  assert.equal(advanced.status, "suspended");
  assert.equal(advanced.setSuspendedAt, true);
});

test("grace boundary: last grace day in_grace, next day suspended", () => {
  const logic = loadLogic();
  // due day d=0; grace=7 → d=6 in_grace, d=7 suspended
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: 6,
      gracePeriodDays: 7,
    }),
    "in_grace",
  );
  assert.equal(
    logic.accessStatusForUnpaidInvoice({
      daysPastDue: 7,
      gracePeriodDays: 7,
    }),
    "suspended",
  );
});

test("Cairo midnight-adjacent instants share/split days correctly", () => {
  const { cairoYmd, cairoCalendarDaysBetween } = loadCairo();
  // 2026-09-10 20:59 UTC ≈ still Sep 10 in Cairo (UTC+3 → 23:59)
  const beforeMidnight = new Date(Date.UTC(2026, 8, 10, 20, 59, 0));
  // 2026-09-10 21:00 UTC ≈ Sep 11 00:00 Cairo
  const afterMidnight = new Date(Date.UTC(2026, 8, 10, 21, 0, 0));
  assert.equal(cairoYmd(beforeMidnight), "2026-09-10");
  assert.equal(cairoYmd(afterMidnight), "2026-09-11");
  assert.equal(
    cairoCalendarDaysBetween(
      cairoYmd(beforeMidnight),
      cairoYmd(afterMidnight),
    ),
    1,
  );
});

test("rerun same inputs yields identical target (idempotent)", () => {
  const logic = loadLogic();
  const params = {
    unpaid: [
      {
        id: "inv1",
        studentId: "stu1",
        parentId: "p1",
        dueDate: onCairoYmd("2026-09-10"),
        status: "overdue",
      },
    ],
    childrenIds: ["stu1"],
    gracePeriodDays: 7,
    now: onCairoYmd("2026-09-12"),
  };
  const a = logic.computeParentAccessTarget(params);
  const b = logic.computeParentAccessTarget(params);
  assert.deepEqual(a, b);
  assert.equal(a.status, "in_grace");
});

test("index exports WA-6 scheduled job", async () => {
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
  assert.match(src, /processPaymentOverdueGrace/);
});
