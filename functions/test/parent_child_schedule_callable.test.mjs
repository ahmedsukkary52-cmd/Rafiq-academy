/**
 * getParentChildSchedule — parent-scoped weekly schedule projection (no emulator).
 *
 * Run: cd functions && npm run build && node --test test/parent_child_schedule_callable.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const mod = require("../lib/halaqa/parentScheduleFunctions.js");
const { MAX_SLOTS_PER_HALAQA } = require("../lib/halaqa/halaqaScheduleFunctions.js");

/** Minimal Firestore double: doc gets only, recording every read path. */
function fakeDb(collections) {
  const reads = [];
  return {
    reads,
    collection(name) {
      return {
        doc(id) {
          return {
            async get() {
              reads.push(`${name}/${id}`);
              const data = collections[name]?.[id];
              return { id, exists: data !== undefined, data: () => data };
            },
          };
        },
        where() {
          throw new Error("getParentChildSchedule must not query collections");
        },
      };
    },
  };
}

function dataset() {
  return {
    users: {
      parent1: { role: "parent", isActive: true },
      parent2: { role: "parent", isActive: true },
      inactiveParent: { role: "parent", isActive: false },
      teacher1: { role: "teacher", isActive: true },
      admin1: { role: "admin", isActive: true },
      student1: { role: "student", isActive: true },
    },
    parentProfiles: {
      parent1: { childrenIds: ["student1", "student2"] },
      inactiveParent: { childrenIds: ["student1"] },
    },
    halaqat: {
      h1: {
        name: " حلقة الفجر ",
        teacherId: "teacher1",
        supervisorId: "sup1",
        studentIds: ["student1", "student9"],
        meetingLink: "https://meet.example.test/legacy",
        createdBy: "admin1",
        status: "active",
        schedule: [
          { day: "السبت", startTime: "06:00", endTime: "07:00", slotId: "slot-a" },
          { day: " الاثنين ", startTime: "18:30 ", endTime: "19:30", slotId: "slot-b", extra: "x" },
          "not-a-slot",
          null,
          ["array"],
          { day: 7, startTime: null },
        ],
      },
      h2: { name: "حلقة العصر", teacherId: "teacher2", studentIds: ["student3"], schedule: [] },
      hNoSchedule: { name: "بلا جدول", studentIds: ["student1"] },
    },
  };
}

async function rejects(promise, code, message) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code);
    if (message) assert.equal(err.message, message);
    return true;
  });
}

test("linked parent gets only the Halaqa name and slot times", async () => {
  const db = fakeDb(dataset());
  const res = await mod.getParentChildScheduleCore(db, "parent1", { studentId: "student1", halaqaId: "h1" });
  assert.deepEqual(res, {
    halaqaId: "h1",
    name: "حلقة الفجر",
    schedule: [
      { day: "السبت", startTime: "06:00", endTime: "07:00" },
      { day: "الاثنين", startTime: "18:30", endTime: "19:30" },
      { day: "", startTime: "", endTime: "" },
    ],
  });
  const json = JSON.stringify(res);
  for (const leaked of [
    "studentIds", "student9", "student1", "meetingLink", "meet.example", "teacher", "supervisor",
    "sup1", "createdBy", "admin1", "status", "slotId", "slot-a", "extra",
  ]) {
    assert.equal(json.includes(leaked), false, `response leaks ${leaked}`);
  }
  assert.deepEqual(db.reads, ["users/parent1", "parentProfiles/parent1", "halaqat/h1"]);
});

test("a Halaqa without a schedule yields an empty list", async () => {
  const res = await mod.getParentChildScheduleCore(fakeDb(dataset()), "parent1", {
    studentId: "student1",
    halaqaId: "hNoSchedule",
  });
  assert.deepEqual(res, { halaqaId: "hNoSchedule", name: "بلا جدول", schedule: [] });
});

test("slots are capped at the server schedule limit", () => {
  const many = Array.from({ length: MAX_SLOTS_PER_HALAQA + 5 }, () => ({
    day: "السبت",
    startTime: "06:00",
    endTime: "07:00",
  }));
  const res = mod.toParentChildSchedule("h1", { name: "n", schedule: many });
  assert.equal(res.schedule.length, MAX_SLOTS_PER_HALAQA);
});

test("unlinked child is denied before the Halaqa is read", async () => {
  const db = fakeDb(dataset());
  await rejects(
    mod.getParentChildScheduleCore(db, "parent1", { studentId: "student3", halaqaId: "h2" }),
    "permission-denied",
    "هذا الطالب غير مرتبط بحسابك",
  );
  await rejects(
    mod.getParentChildScheduleCore(db, "parent2", { studentId: "student1", halaqaId: "h1" }),
    "permission-denied",
  );
  assert.equal(db.reads.some((r) => r.startsWith("halaqat/")), false);
});

test("a linked child outside the Halaqa, or a missing Halaqa, is denied alike", async () => {
  const db = fakeDb(dataset());
  for (const halaqaId of ["h2", "missing"]) {
    await rejects(
      mod.getParentChildScheduleCore(db, "parent1", { studentId: "student1", halaqaId }),
      "permission-denied",
      "الطالب ليس ضمن هذه الحلقة",
    );
  }
  await rejects(
    mod.getParentChildScheduleCore(db, "parent1", { studentId: "student2", halaqaId: "h1" }),
    "permission-denied",
    "الطالب ليس ضمن هذه الحلقة",
  );
});

test("non-parent, deactivated, profile-less and anonymous callers are denied", async () => {
  const db = fakeDb(dataset());
  for (const uid of ["teacher1", "admin1", "student1", "inactiveParent", "ghost"]) {
    await rejects(
      mod.getParentChildScheduleCore(db, uid, { studentId: "student1", halaqaId: "h1" }),
      "permission-denied",
    );
  }
  await rejects(
    mod.getParentChildScheduleCore(db, undefined, { studentId: "student1", halaqaId: "h1" }),
    "unauthenticated",
  );
  assert.equal(db.reads.some((r) => !r.startsWith("users/")), false);
});

test("studentId and halaqaId must be non-empty strings", async () => {
  const db = fakeDb(dataset());
  for (const bad of [undefined, null, "", "  ", 42, ["x"], { id: "x" }]) {
    await rejects(
      mod.getParentChildScheduleCore(db, "parent1", { studentId: bad, halaqaId: "h1" }),
      "invalid-argument",
    );
    await rejects(
      mod.getParentChildScheduleCore(db, "parent1", { studentId: "student1", halaqaId: bad }),
      "invalid-argument",
    );
  }
  assert.equal(db.reads.some((r) => !r.startsWith("users/")), false);
});

test("callable is exported, gated by the backend switch and pinned to the client region", () => {
  const index = readFileSync(join(here, "..", "src", "index.ts"), "utf8");
  assert.match(index, /export \{ getParentChildSchedule \} from "\.\/halaqa\/parentScheduleFunctions";/);
  const src = readFileSync(join(here, "..", "src", "halaqa", "parentScheduleFunctions.ts"), "utf8");
  assert.match(src, /assertBackendAllowed\("getParentChildSchedule"\)/);
  assert.match(src, /region: "europe-west1"/);
  assert.doesNotMatch(src, /\.(set|update|create|delete|add)\(/, "read-only callable");
  assert.doesNotMatch(src, /\.where\(/, "reads one Halaqa by id only");
});
