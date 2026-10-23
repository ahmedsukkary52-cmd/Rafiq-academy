/**
 * getParentAchievements — parent-scoped achievements read (no emulator).
 *
 * Run: cd functions && npm run build && node --test test/parent_achievements_callable.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
const admin = require("firebase-admin");
const { Timestamp } = admin.firestore;
const mod = require("../lib/awards/parentAchievementFunctions.js");

/** Minimal Firestore double: doc gets plus single-filter + limit queries. */
function fakeDb(collections) {
  const queries = [];
  const docsOf = (name) => Object.entries(collections[name] ?? {});
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
                  const matches = docsOf(name).filter(([, d]) =>
                    op === "array-contains"
                      ? Array.isArray(d[field]) && d[field].includes(value)
                      : op === "==" && d[field] === value,
                  );
                  return {
                    docs: matches.slice(0, n).map(([id, d]) => ({ id, data: () => d })),
                  };
                },
              };
            },
          };
        },
      };
    },
  };
}

const ts = (iso) => Timestamp.fromDate(new Date(iso));

function dataset(overrides = {}) {
  return {
    users: {
      parent1: { role: "parent", isActive: true },
      parent2: { role: "parent", isActive: true },
      inactiveParent: { role: "parent", isActive: false },
      teacher1: { role: "teacher", isActive: true },
      student1: { role: "student", isActive: true },
    },
    parentProfiles: {
      parent1: { childrenIds: ["student1", "student2"] },
      parent2: { childrenIds: ["student3"] },
      inactiveParent: { childrenIds: ["student1"] },
    },
    achievements: {
      legacy1: {
        studentId: "student1",
        type: "star",
        title: "نجمة",
        issuedBy: "sup1",
        date: ts("2026-10-01T10:00:00Z"),
        halaqaId: "h1",
      },
      multi1: {
        studentId: "student3",
        recipientStudentIds: ["student3", "student1", "student2"],
        studentName: "Other Child",
        type: "custom",
        title: "حفظ جزء",
        description: "سبب",
        grantedBy: "teacher1",
        issuedBy: "teacher1",
        date: ts("2026-10-05T10:00:00Z"),
        halaqaId: "h1",
        halaqaIds: ["h1"],
      },
      single2: {
        studentId: "student2",
        recipientStudentIds: ["student2"],
        type: "achievement",
        note: "ملاحظة",
        grantedBy: "teacher1",
        grantedAt: ts("2026-10-03T10:00:00Z"),
        imageUrl: "https://example.test/a.png",
      },
      unrelated: {
        studentId: "student3",
        recipientStudentIds: ["student3"],
        type: "star",
        title: "غير مرتبط",
        date: ts("2026-10-07T10:00:00Z"),
      },
      ...overrides,
    },
  };
}

async function assertHttpsCode(promise, code) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code);
    return true;
  });
}

test("unauthenticated caller is rejected before any read", async () => {
  const db = fakeDb(dataset());
  await assertHttpsCode(mod.getParentAchievementsCore(db, undefined, {}), "unauthenticated");
  await assertHttpsCode(mod.getParentAchievementsCore(db, "  ", {}), "unauthenticated");
  assert.equal(db.queries.length, 0);
});

test("non-parent, inactive parent and missing profile are denied", async () => {
  for (const uid of ["teacher1", "student1", "inactiveParent", "ghost"]) {
    const db = fakeDb(dataset());
    await assertHttpsCode(mod.getParentAchievementsCore(db, uid, {}), "permission-denied");
    assert.equal(db.queries.length, 0, `${uid} must not query achievements`);
  }
});

test("authorized parent gets only linked children's achievements, newest first", async () => {
  const db = fakeDb(dataset());
  const { achievements } = await mod.getParentAchievementsCore(db, "parent1", {});
  assert.deepEqual(
    achievements.map((a) => a.id),
    ["multi1", "single2", "legacy1"],
  );
  assert.ok(!achievements.some((a) => a.id === "unrelated"));
  const queried = new Set(db.queries.map((q) => q.value));
  assert.deepEqual([...queried].sort(), ["student1", "student2"]);
  for (const q of db.queries) {
    assert.equal(q.name, "achievements");
    assert.equal(q.limit, mod.PARENT_ACHIEVEMENTS_PER_QUERY_LIMIT);
  }
});

test("client-supplied parent identity is ignored", async () => {
  const db = fakeDb(dataset());
  const { achievements } = await mod.getParentAchievementsCore(db, "parent2", {
    parentId: "parent1",
    uid: "parent1",
  });
  assert.deepEqual(achievements.map((a) => a.id), ["unrelated", "multi1"]);
  for (const a of achievements) assert.deepEqual(a.recipientStudentIds, ["student3"]);
});

test("requesting an unlinked child is denied without querying", async () => {
  const db = fakeDb(dataset());
  await assertHttpsCode(
    mod.getParentAchievementsCore(db, "parent1", { studentId: "student3" }),
    "permission-denied",
  );
  await assertHttpsCode(
    mod.getParentAchievementsCore(db, "parent1", { studentId: ["student1"] }),
    "permission-denied",
  );
  assert.equal(db.queries.length, 0);
});

test("multi-recipient award: returned once, other students' IDs and names stripped", async () => {
  const db = fakeDb(dataset());
  const { achievements } = await mod.getParentAchievementsCore(db, "parent1", {});
  const multi = achievements.filter((a) => a.id === "multi1");
  assert.equal(multi.length, 1, "deduplicated across children and query shapes");
  assert.deepEqual(multi[0].recipientStudentIds.sort(), ["student1", "student2"]);
  assert.equal(multi[0].studentId, "student1");
  assert.equal(multi[0].description, "سبب");
  assert.equal(multi[0].issuedBy, "teacher1");
  const serialized = JSON.stringify(achievements);
  for (const leak of ["student3", "Other Child", "studentName", "halaqaId", "grantedBy"]) {
    assert.ok(!serialized.includes(leak), `${leak} must not be returned`);
  }
});

test("child filter narrows to that child only", async () => {
  const db = fakeDb(dataset());
  const { achievements } = await mod.getParentAchievementsCore(db, "parent1", {
    studentId: "student2",
  });
  assert.deepEqual(achievements.map((a) => a.id), ["multi1", "single2"]);
  for (const a of achievements) assert.deepEqual(a.recipientStudentIds, ["student2"]);
  assert.deepEqual([...new Set(db.queries.map((q) => q.value))], ["student2"]);
});

test("legacy single-recipient doc (studentId only) is returned with resolved fields", async () => {
  const db = fakeDb(dataset());
  const { achievements } = await mod.getParentAchievementsCore(db, "parent1", {
    studentId: "student1",
  });
  const legacy = achievements.find((a) => a.id === "legacy1");
  assert.deepEqual(legacy, {
    id: "legacy1",
    studentId: "student1",
    type: "star",
    title: "نجمة",
    description: "",
    imageUrl: null,
    issuedBy: "sup1",
    dateMillis: Date.parse("2026-10-01T10:00:00Z"),
    recipientStudentIds: ["student1"],
  });
});

test("title/actor/date fall back to note/grantedBy/grantedAt", async () => {
  const db = fakeDb(dataset());
  const { achievements } = await mod.getParentAchievementsCore(db, "parent1", {
    studentId: "student2",
  });
  const single = achievements.find((a) => a.id === "single2");
  assert.equal(single.title, "ملاحظة");
  assert.equal(single.issuedBy, "teacher1");
  assert.equal(single.dateMillis, Date.parse("2026-10-03T10:00:00Z"));
  assert.equal(single.imageUrl, "https://example.test/a.png");
});

test("parent with no linked children gets an empty list", async () => {
  const data = dataset();
  data.parentProfiles.parent1 = { childrenIds: [] };
  const db = fakeDb(data);
  const { achievements } = await mod.getParentAchievementsCore(db, "parent1", {});
  assert.deepEqual(achievements, []);
  assert.equal(db.queries.length, 0);
});

test("merge caps results and deduplicates by id", () => {
  const linked = new Set(["s1"]);
  const docs = [];
  for (let i = 0; i < 250; i++) {
    const data = { studentId: "s1", title: `t${i}`, date: Timestamp.fromMillis(i * 1000) };
    docs.push({ id: `a${i}`, data }, { id: `a${i}`, data });
  }
  const merged = mod.mergeParentAchievements(docs, linked);
  assert.equal(merged.length, mod.PARENT_ACHIEVEMENTS_MAX_RESULTS);
  assert.equal(new Set(merged.map((a) => a.id)).size, merged.length);
  assert.equal(merged[0].id, "a249");
});

test("callable is exported, gated and region-pinned", () => {
  const src = readFileSync(join(repoRoot, "functions/src/awards/parentAchievementFunctions.ts"), "utf8");
  assert.equal(src.split("onCall(").length - 1, 1);
  assert.equal(src.split("assertBackendAllowed(").length - 1, 1);
  assert.match(src, /region: "europe-west1"/);
  assert.match(src, /request\.auth\?\.uid/);
  const index = readFileSync(join(repoRoot, "functions/src/index.ts"), "utf8");
  assert.match(index, /getParentAchievements/);
});

test("rules keep parent list reads on achievements denied", () => {
  const rules = readFileSync(join(repoRoot, "firestore.rules"), "utf8");
  const block = rules.slice(rules.indexOf("match /achievements/"));
  const list = block.slice(block.indexOf("allow list:"), block.indexOf(";", block.indexOf("allow list:")));
  assert.ok(list.length > 0, "achievements must have a dedicated list rule");
  assert.doesNotMatch(list, /isParent|isLinkedParent|parentProfiles/);
});
