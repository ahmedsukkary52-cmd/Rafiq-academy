/**
 * WA-7 slotId migration unit tests (no Firestore emulator required).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function load() {
  const resolved = require.resolve("../lib/halaqa/slotIdMigration.js");
  delete require.cache[resolved];
  return require("../lib/halaqa/slotIdMigration.js");
}

test("single slot without id gets uuid", () => {
  const { migrateScheduleSlots } = load();
  let n = 0;
  const r = migrateScheduleSlots(
    [{ day: "الأحد", startTime: "16:00", endTime: "17:00" }],
    () => `id-${++n}`,
  );
  assert.equal(r.assigned, 1);
  assert.equal(r.preserved, 0);
  assert.equal(r.changed, true);
  assert.equal(r.schedule[0].slotId, "id-1");
  assert.equal(r.schedule[0].day, "الأحد");
  assert.equal(r.schedule[0].startTime, "16:00");
});

test("multiple slots each get independent ids", () => {
  const { migrateScheduleSlots } = load();
  let n = 0;
  const r = migrateScheduleSlots(
    [
      { day: "الأحد", startTime: "16:00", endTime: "17:00" },
      { day: "الثلاثاء", startTime: "18:00", endTime: "19:00" },
    ],
    () => `id-${++n}`,
  );
  assert.equal(r.assigned, 2);
  assert.equal(r.schedule[0].slotId, "id-1");
  assert.equal(r.schedule[1].slotId, "id-2");
  assert.notEqual(r.schedule[0].slotId, r.schedule[1].slotId);
});

test("existing slotId preserved (idempotent)", () => {
  const { migrateScheduleSlots } = load();
  const existing = [
    {
      day: "الأحد",
      startTime: "16:00",
      endTime: "17:00",
      slotId: "keep-me",
    },
  ];
  const r1 = migrateScheduleSlots(existing, () => "new");
  assert.equal(r1.assigned, 0);
  assert.equal(r1.preserved, 1);
  assert.equal(r1.changed, false);
  assert.equal(r1.schedule[0].slotId, "keep-me");
  const r2 = migrateScheduleSlots(r1.schedule, () => "newer");
  assert.equal(r2.schedule[0].slotId, "keep-me");
  assert.equal(r2.assigned, 0);
  assert.equal(r2.changed, false);
});

test("empty schedule does not crash", () => {
  const { migrateScheduleSlots, scheduleSlotsAllHaveIds } = load();
  const r = migrateScheduleSlots([]);
  assert.deepEqual(r.schedule, []);
  assert.equal(r.changed, false);
  assert.equal(scheduleSlotsAllHaveIds([]), true);
});

test("null / non-array schedule treated safely", () => {
  const { migrateScheduleSlots, scheduleSlotsAllHaveIds } = load();
  const r = migrateScheduleSlots(null);
  assert.deepEqual(r.schedule, []);
  assert.equal(scheduleSlotsAllHaveIds(null), false);
});

test("malformed entries preserved (non-destructive)", () => {
  const { migrateScheduleSlots } = load();
  let n = 0;
  const r = migrateScheduleSlots(
    ["bad", null, { day: "الأحد", startTime: "10:00", endTime: "11:00" }],
    () => `id-${++n}`,
  );
  assert.equal(r.skippedMalformed, 2);
  assert.equal(r.assigned, 1);
  assert.equal(r.schedule[0], "bad");
  assert.equal(r.schedule[1], null);
  assert.equal(r.schedule[2].slotId, "id-1");
});

test("reorder keeps slotIds on slot objects (not index-bound)", () => {
  const { migrateScheduleSlots } = load();
  let n = 0;
  const first = migrateScheduleSlots(
    [
      { day: "A", startTime: "1", endTime: "2" },
      { day: "B", startTime: "3", endTime: "4" },
    ],
    () => `id-${++n}`,
  );
  const reordered = [first.schedule[1], first.schedule[0]];
  const second = migrateScheduleSlots(reordered, () => "should-not-run");
  assert.equal(second.assigned, 0);
  assert.equal(second.schedule[0].slotId, "id-2");
  assert.equal(second.schedule[0].day, "B");
  assert.equal(second.schedule[1].slotId, "id-1");
  assert.equal(second.schedule[1].day, "A");
});

test("assertNonEmptyScheduleWithSlotIds rejects empty / missing ids", () => {
  const { assertNonEmptyScheduleWithSlotIds } = load();
  assert.throws(() => assertNonEmptyScheduleWithSlotIds([]));
  assert.throws(() =>
    assertNonEmptyScheduleWithSlotIds([
      { day: "الأحد", startTime: "16:00", endTime: "17:00" },
    ]),
  );
  assert.doesNotThrow(() =>
    assertNonEmptyScheduleWithSlotIds([
      {
        day: "الأحد",
        startTime: "16:00",
        endTime: "17:00",
        slotId: "abc",
      },
    ]),
  );
});

test("index exports adminMigrateHalaqaSlotIds", async () => {
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
  assert.match(src, /adminMigrateHalaqaSlotIds/);
  // Paymob remains quarantined (WA-0 / D2).
  assert.doesNotMatch(src, /^export \{ createPaymentIntention/m);
});

test("sequential second pass is no-op (idempotent)", () => {
  const { migrateScheduleSlots, shouldWriteMigratedSchedule } = load();
  let n = 0;
  const once = migrateScheduleSlots(
    [{ day: "الأحد", startTime: "16:00", endTime: "17:00" }],
    () => `id-${++n}`,
  );
  assert.equal(shouldWriteMigratedSchedule(false, once.changed), true);
  const twice = migrateScheduleSlots(once.schedule, () => "must-not-assign");
  assert.equal(twice.assigned, 0);
  assert.equal(twice.changed, false);
  assert.equal(twice.schedule[0].slotId, "id-1");
  assert.equal(shouldWriteMigratedSchedule(false, twice.changed), false);
});

test("concurrent-style: existing slotId always wins over planned ids", () => {
  const { migrateScheduleSlots } = load();
  const original = [
    { day: "A", startTime: "1", endTime: "2" },
    { day: "B", startTime: "3", endTime: "4" },
  ];
  // Writer A
  let a = 0;
  const writerA = migrateScheduleSlots(original, () => `A-${++a}`);
  // Writer B started from same original (stale) — would invent B-* ids
  let b = 0;
  const writerBStale = migrateScheduleSlots(original, () => `B-${++b}`);
  assert.notEqual(writerA.schedule[0].slotId, writerBStale.schedule[0].slotId);
  // Transaction retry: B re-reads A's result → preserves A's ids
  const writerBRetry = migrateScheduleSlots(writerA.schedule, () => "B-new");
  assert.equal(writerBRetry.assigned, 0);
  assert.equal(writerBRetry.changed, false);
  assert.equal(writerBRetry.schedule[0].slotId, "A-1");
  assert.equal(writerBRetry.schedule[1].slotId, "A-2");
});

test("dryRun and unchanged schedules never write", () => {
  const { shouldWriteMigratedSchedule } = load();
  assert.equal(shouldWriteMigratedSchedule(true, true), false);
  assert.equal(shouldWriteMigratedSchedule(true, false), false);
  assert.equal(shouldWriteMigratedSchedule(false, false), false);
  assert.equal(shouldWriteMigratedSchedule(false, true), true);
});

test("readyForSessionsPrerequisite rejects empty/malformed active schedules", () => {
  const { isHalaqaReadyForSessionsSlotPrerequisite } = load();
  assert.equal(
    isHalaqaReadyForSessionsSlotPrerequisite({
      status: "active",
      schedule: [],
    }),
    false,
  );
  assert.equal(
    isHalaqaReadyForSessionsSlotPrerequisite({
      status: "active",
      schedule: ["bad", { day: "A", startTime: "1", endTime: "2", slotId: "x" }],
    }),
    false,
  );
  assert.equal(
    isHalaqaReadyForSessionsSlotPrerequisite({
      status: "active",
      schedule: [{ day: "A", startTime: "1", endTime: "2", slotId: "x" }],
    }),
    true,
  );
  assert.equal(
    isHalaqaReadyForSessionsSlotPrerequisite({
      status: "archived",
      schedule: [],
    }),
    true,
  );
});

test("adminMigrateHalaqaSlotIds uses Firestore transactions", async () => {
  const { readFileSync } = await import("node:fs");
  const { join, dirname } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const src = readFileSync(
    join(
      dirname(fileURLToPath(import.meta.url)),
      "..",
      "src",
      "admin",
      "adminMigrateHalaqaSlotIds.ts",
    ),
    "utf8",
  );
  assert.match(src, /runTransaction/);
  assert.match(src, /shouldWriteMigratedSchedule/);
});
