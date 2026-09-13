/**
 * WA-9 session conflict engine unit tests (no Firestore emulator required).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function loadConflict() {
  const resolved = require.resolve("../lib/sessions/sessionConflict.js");
  delete require.cache[resolved];
  return require("../lib/sessions/sessionConflict.js");
}

function at(h, m = 0) {
  return new Date(Date.UTC(2026, 8, 13, h, m, 0));
}

function cand(partial) {
  return {
    sessionId: partial.sessionId ?? "s1",
    halaqaId: partial.halaqaId ?? "h1",
    teacherId: partial.teacherId ?? "t1",
    supervisorId: partial.supervisorId ?? null,
    status: partial.status ?? "scheduled",
    startAt: partial.startAt,
    endAt: partial.endAt,
  };
}

function req(partial) {
  return {
    sessionId: partial.sessionId ?? "new",
    halaqaId: partial.halaqaId ?? "h1",
    teacherId: partial.teacherId ?? "t1",
    supervisorId: partial.supervisorId ?? "sv1",
    startAt: partial.startAt,
    endAt: partial.endAt,
    studentIds: partial.studentIds ?? ["st1"],
  };
}

test("half-open: adjacent boundary is NOT a conflict", () => {
  const {
    intervalsOverlapHalfOpen,
    intervalsAreAdjacentHalfOpen,
    evaluateSessionConflicts,
  } = loadConflict();
  assert.equal(
    intervalsOverlapHalfOpen(at(10), at(11), at(11), at(12)),
    false,
  );
  assert.equal(
    intervalsAreAdjacentHalfOpen(at(10), at(11), at(11), at(12)),
    true,
  );
  const r = evaluateSessionConflicts({
    request: req({ startAt: at(11), endAt: at(12), sessionId: "new" }),
    candidates: [
      cand({
        sessionId: "old",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, true);
});

test("half-open: partial overlap is a conflict", () => {
  const { intervalsOverlapHalfOpen, evaluateSessionConflicts } = loadConflict();
  assert.equal(
    intervalsOverlapHalfOpen(at(10), at(11), at(10, 59), at(12)),
    true,
  );
  const r = evaluateSessionConflicts({
    request: req({ startAt: at(10, 59), endAt: at(12) }),
    candidates: [cand({ sessionId: "old", startAt: at(10), endAt: at(11) })],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, false);
  assert.equal(r.conflicts[0].reason, "same_halaqa");
});

test("exact same interval => conflict (different session id)", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({ sessionId: "new", startAt: at(10), endAt: at(11) }),
    candidates: [
      cand({ sessionId: "other", startAt: at(10), endAt: at(11) }),
    ],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, false);
});

test("contained interval => conflict", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({ startAt: at(10, 15), endAt: at(10, 45) }),
    candidates: [cand({ sessionId: "old", startAt: at(10), endAt: at(11) })],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, false);
});

test("invalid / zero-duration interval => reject", () => {
  const { assertValidHalfOpenInterval, evaluateSessionConflicts } =
    loadConflict();
  assert.throws(() => assertValidHalfOpenInterval(at(10), at(10)), /invalid/);
  assert.throws(() => assertValidHalfOpenInterval(at(11), at(10)), /invalid/);
  const r = evaluateSessionConflicts({
    request: req({ startAt: at(10), endAt: at(10) }),
    candidates: [],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, false);
  assert.equal(r.conflicts[0].reason, "invalid_interval");
});

test("same Halaqa overlapping => reject; adjacent => allow", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const overlap = evaluateSessionConflicts({
    request: req({ halaqaId: "h1", startAt: at(10), endAt: at(11) }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "h1",
        teacherId: "tOther",
        startAt: at(10, 30),
        endAt: at(11, 30),
      }),
    ],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(overlap.ok, false);
  assert.ok(overlap.conflicts.some((c) => c.reason === "same_halaqa"));

  const adjacent = evaluateSessionConflicts({
    request: req({ halaqaId: "h1", startAt: at(11), endAt: at(12) }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "h1",
        teacherId: "tOther",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(adjacent.ok, true);
});

test("same Teacher overlapping => reject; adjacent => allow", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const overlap = evaluateSessionConflicts({
    request: req({
      halaqaId: "hA",
      teacherId: "t1",
      studentIds: ["a"],
      startAt: at(10),
      endAt: at(11),
    }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "hB",
        teacherId: "t1",
        startAt: at(10, 30),
        endAt: at(11, 30),
      }),
    ],
    rosterByHalaqaId: new Map([["hB", ["b"]]]),
  });
  assert.equal(overlap.ok, false);
  assert.ok(overlap.conflicts.some((c) => c.reason === "same_teacher"));

  const adjacent = evaluateSessionConflicts({
    request: req({
      halaqaId: "hA",
      teacherId: "t1",
      studentIds: ["a"],
      startAt: at(11),
      endAt: at(12),
    }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "hB",
        teacherId: "t1",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map([["hB", ["b"]]]),
  });
  assert.equal(adjacent.ok, true);
});

test("same Teacher different Halaqat overlapping => reject", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({
      halaqaId: "hA",
      teacherId: "t1",
      studentIds: ["a"],
      startAt: at(10),
      endAt: at(11),
    }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "hB",
        teacherId: "t1",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map([["hB", ["b"]]]),
  });
  assert.equal(r.ok, false);
  assert.ok(r.conflicts.some((c) => c.reason === "same_teacher"));
});

test("different Teachers different Halaqat disjoint students => allow", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({
      halaqaId: "hA",
      teacherId: "tA",
      studentIds: ["a1"],
      startAt: at(10),
      endAt: at(11),
    }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "hB",
        teacherId: "tB",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map([["hB", ["b1"]]]),
  });
  assert.equal(r.ok, true);
});

test("student roster intersection + overlap => reject", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({
      halaqaId: "hA",
      teacherId: "tA",
      studentIds: ["shared", "a2"],
      startAt: at(10),
      endAt: at(11),
    }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "hB",
        teacherId: "tB",
        startAt: at(10, 30),
        endAt: at(11, 30),
      }),
    ],
    rosterByHalaqaId: new Map([["hB", ["shared", "b2"]]]),
  });
  assert.equal(r.ok, false);
  assert.ok(
    r.conflicts.some((c) => c.reason === "student_roster_intersection"),
  );
});

test("student roster disjoint + overlap => allow", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({
      halaqaId: "hA",
      teacherId: "tA",
      studentIds: ["a1"],
      startAt: at(10),
      endAt: at(11),
    }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "hB",
        teacherId: "tB",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map([["hB", ["b1"]]]),
  });
  assert.equal(r.ok, true);
});

test("Supervisor overlap alone => allow", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({
      halaqaId: "hA",
      teacherId: "tA",
      supervisorId: "svSame",
      studentIds: ["a1"],
      startAt: at(10),
      endAt: at(11),
    }),
    candidates: [
      cand({
        sessionId: "old",
        halaqaId: "hB",
        teacherId: "tB",
        supervisorId: "svSame",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map([["hB", ["b1"]]]),
  });
  assert.equal(r.ok, true);
});

test("cancelled sessions excluded from conflict set", () => {
  const { evaluateSessionConflicts, sessionParticipatesInConflicts } =
    loadConflict();
  assert.equal(sessionParticipatesInConflicts("cancelled"), false);
  const r = evaluateSessionConflicts({
    request: req({ startAt: at(10), endAt: at(11) }),
    candidates: [
      cand({
        sessionId: "old",
        status: "cancelled",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, true);
});

test("completed sessions excluded from future scheduling conflict set", () => {
  const { evaluateSessionConflicts, sessionParticipatesInConflicts } =
    loadConflict();
  assert.equal(sessionParticipatesInConflicts("completed"), false);
  assert.equal(sessionParticipatesInConflicts("scheduled"), true);
  assert.equal(sessionParticipatesInConflicts("in_progress"), true);
  const r = evaluateSessionConflicts({
    request: req({ startAt: at(10), endAt: at(11) }),
    candidates: [
      cand({
        sessionId: "old",
        status: "completed",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, true);
});

test("idempotent reuse of same sessionId is not a self-conflict", () => {
  const { evaluateSessionConflicts } = loadConflict();
  const r = evaluateSessionConflicts({
    request: req({ sessionId: "sess_same", startAt: at(10), endAt: at(11) }),
    candidates: [
      cand({
        sessionId: "sess_same",
        startAt: at(10),
        endAt: at(11),
      }),
    ],
    rosterByHalaqaId: new Map(),
  });
  assert.equal(r.ok, true);
});

test("concurrent gated creates: overlapping teacher => one wins", async () => {
  const { materializeWithConflictGate } = loadConflict();
  const store = new Map();
  const dayLocks = new Map();
  const cairoDate = "2026-09-13";
  const rosterByHalaqaId = new Map([
    ["hA", ["a1"]],
    ["hB", ["b1"]],
  ]);

  const mk = (sessionId, halaqaId, teacherId, start, end) => ({
    store,
    dayLocks,
    cairoDate,
    rosterByHalaqaId,
    request: {
      sessionId,
      halaqaId,
      teacherId,
      startAt: start,
      endAt: end,
      studentIds: rosterByHalaqaId.get(halaqaId),
    },
    createDoc: {
      sessionId,
      halaqaId,
      teacherId,
      status: "scheduled",
      startAt: start,
      endAt: end,
      createdBy: "t",
    },
  });

  const results = await Promise.all([
    materializeWithConflictGate(mk("sA", "hA", "tSame", at(10), at(11))),
    materializeWithConflictGate(mk("sB", "hB", "tSame", at(10, 30), at(11, 30))),
  ]);
  const created = results.filter((r) => r.created);
  const conflicted = results.filter((r) => r.conflict && !r.conflict.ok);
  assert.equal(created.length, 1);
  assert.equal(conflicted.length, 1);
  assert.equal(store.size, 1);
});

test("concurrent gated creates: identical session id converges to reuse", async () => {
  const { materializeWithConflictGate } = loadConflict();
  const store = new Map();
  const dayLocks = new Map();
  const results = await Promise.all(
    Array.from({ length: 20 }, () =>
      materializeWithConflictGate({
        store,
        dayLocks,
        cairoDate: "2026-09-13",
        rosterByHalaqaId: new Map([["h1", ["st1"]]]),
        request: req({
          sessionId: "sess_one",
          startAt: at(16),
          endAt: at(17),
        }),
        createDoc: cand({
          sessionId: "sess_one",
          startAt: at(16),
          endAt: at(17),
          createdBy: "t1",
        }),
      }),
    ),
  );
  assert.equal(store.size, 1);
  assert.equal(results.filter((r) => r.created).length, 1);
  assert.equal(results.filter((r) => r.reused).length, 19);
});

test("cairo day lock id is stable", () => {
  const { cairoDayConflictLockId } = loadConflict();
  assert.equal(cairoDayConflictLockId("2026-09-13"), "cairo_2026-09-13");
});

test("materializeSession wires conflict gate + day lock + ignores client roster", async () => {
  const { readFileSync } = await import("node:fs");
  const { join, dirname } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const src = readFileSync(
    join(
      dirname(fileURLToPath(import.meta.url)),
      "..",
      "src",
      "sessions",
      "materializeSession.ts",
    ),
    "utf8",
  );
  assert.match(src, /evaluateSessionConflicts/);
  assert.match(src, /sessionConflictLocks/);
  assert.match(src, /cairoDayConflictLockId/);
  assert.match(src, /normalizeStudentIds\(halaqaRaw\.studentIds\)/);
  assert.match(src, /Client roster\/staff fields are ignored/);
  assert.match(src, /session_conflict/);
  assert.doesNotMatch(src, /normalizeStudentIds\(data\.studentIds\)/);
});

test("WA-8 materialization helpers still export deterministic id", () => {
  const resolved = require.resolve("../lib/sessions/sessionMaterialization.js");
  delete require.cache[resolved];
  const m = require("../lib/sessions/sessionMaterialization.js");
  const id = m.deterministicSessionId({
    halaqaId: "h1",
    slotId: "slot",
    date: "2026-09-13",
  });
  assert.match(id, /^sess_[a-f0-9]{64}$/);
});
