/**
 * getParentChildHalaqat — parent-scoped Halaqa projection (no emulator).
 *
 * Run: cd functions && npm run build && node --test test/parent_child_halaqat_callable.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const mod = require("../lib/halaqa/parentHalaqaFunctions.js");

/** Minimal Firestore double: doc gets plus one array-contains + limit query. */
function fakeDb(collections) {
  const queries = [];
  return {
    queries,
    collection(name) {
      return {
        doc(id) {
          return {
            async get() {
              const data = collections[name]?.[id];
              return { exists: data !== undefined, data: () => data };
            },
          };
        },
        where(field, op, value) {
          return {
            limit(n) {
              return {
                async get() {
                  queries.push({ name, field, op, value, limit: n });
                  const matches = Object.entries(collections[name] ?? {}).filter(
                    ([, d]) => op === "array-contains" && Array.isArray(d[field]) && d[field].includes(value),
                  );
                  return { docs: matches.slice(0, n).map(([id, d]) => ({ id, data: () => d })) };
                },
              };
            },
          };
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
    },
    parentProfiles: {
      parent1: { childrenIds: ["student1", "student2"] },
      inactiveParent: { childrenIds: ["student1"] },
    },
    halaqat: {
      h2: {
        name: " حلقة العصر ",
        teacherId: "teacher2",
        supervisorId: "sup1",
        studentIds: ["student1", "student9"],
        meetingLink: "https://meet.example.test/legacy",
        schedule: [{ day: "saturday" }],
        createdBy: "admin1",
        status: "active",
      },
      h1: {
        name: "حلقة الفجر",
        teacherId: "teacher1",
        supervisorId: "sup1",
        studentIds: ["student1", "student3"],
      },
      h3: { name: "other", teacherId: "teacher3", studentIds: ["student3"] },
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

test("linked parent gets only name and staff ids of the child's Halaqat", async () => {
  const db = fakeDb(dataset());
  const res = await mod.getParentChildHalaqatCore(db, "parent1", { studentId: "student1" });
  assert.deepEqual(res, {
    halaqat: [
      { id: "h1", name: "حلقة الفجر", teacherId: "teacher1", supervisorId: "sup1" },
      { id: "h2", name: "حلقة العصر", teacherId: "teacher2", supervisorId: "sup1" },
    ],
  });
  const json = JSON.stringify(res);
  for (const leaked of ["studentIds", "student9", "student3", "meetingLink", "meet.example", "schedule", "createdBy"]) {
    assert.equal(json.includes(leaked), false, `response leaks ${leaked}`);
  }
  assert.deepEqual(db.queries, [
    { name: "halaqat", field: "studentIds", op: "array-contains", value: "student1", limit: mod.PARENT_CHILD_HALAQAT_LIMIT },
  ]);
});

test("a linked child on no roster yields an empty list", async () => {
  const res = await mod.getParentChildHalaqatCore(fakeDb(dataset()), "parent1", { studentId: "student2" });
  assert.deepEqual(res, { halaqat: [] });
});

test("unlinked child is denied without querying halaqat", async () => {
  const db = fakeDb(dataset());
  await rejects(
    mod.getParentChildHalaqatCore(db, "parent1", { studentId: "student3" }),
    "permission-denied",
    "هذا الطالب غير مرتبط بحسابك",
  );
  await rejects(
    mod.getParentChildHalaqatCore(db, "parent2", { studentId: "student1" }),
    "permission-denied",
  );
  assert.equal(db.queries.length, 0);
});

test("non-parent, deactivated, profile-less and anonymous callers are denied", async () => {
  const db = fakeDb(dataset());
  for (const uid of ["teacher1", "admin1", "inactiveParent", "ghost"]) {
    await rejects(mod.getParentChildHalaqatCore(db, uid, { studentId: "student1" }), "permission-denied");
  }
  await rejects(mod.getParentChildHalaqatCore(db, undefined, { studentId: "student1" }), "unauthenticated");
  assert.equal(db.queries.length, 0);
});

test("studentId must be a non-empty string", async () => {
  const db = fakeDb(dataset());
  for (const studentId of [undefined, null, "", "  ", 42, ["student1"], { id: "student1" }]) {
    await rejects(mod.getParentChildHalaqatCore(db, "parent1", { studentId }), "invalid-argument");
  }
  assert.equal(db.queries.length, 0);
});

test("callable is exported, gated by the backend switch and pinned to the client region", () => {
  const index = readFileSync(join(here, "..", "src", "index.ts"), "utf8");
  assert.match(index, /export \{ getParentChildHalaqat \} from "\.\/halaqa\/parentHalaqaFunctions";/);
  const src = readFileSync(join(here, "..", "src", "halaqa", "parentHalaqaFunctions.ts"), "utf8");
  assert.match(src, /assertBackendAllowed\("getParentChildHalaqat"\)/);
  assert.match(src, /region: "europe-west1"/);
  assert.doesNotMatch(src, /\.(set|update|create|delete)\(/, "read-only callable");
});
