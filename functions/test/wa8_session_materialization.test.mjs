/**
 * WA-8 session materialization unit tests (no Firestore emulator required).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function loadSession() {
  const resolved = require.resolve("../lib/sessions/sessionMaterialization.js");
  delete require.cache[resolved];
  // Also bust cairoTime dependency cache when reloading.
  try {
    delete require.cache[require.resolve("../lib/billing/cairoTime.js")];
  } catch {
    /* ignore */
  }
  return require("../lib/sessions/sessionMaterialization.js");
}

function loadCairo() {
  const resolved = require.resolve("../lib/billing/cairoTime.js");
  delete require.cache[resolved];
  return require("../lib/billing/cairoTime.js");
}

const sundaySlot = {
  day: "الأحد",
  startTime: "16:00",
  endTime: "17:00",
  slotId: "slot-sun-1",
};

/** 2026-09-13 is a Sunday. */
const sundayYmd = "2026-09-13";

const halaqaOk = {
  teacherId: "teacher-1",
  supervisorId: "supervisor-1",
  schedule: [sundaySlot],
};

test("deterministic session id is stable for identity", () => {
  const { deterministicSessionId, occurrenceKey } = loadSession();
  const identity = {
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
  };
  const a = deterministicSessionId(identity);
  const b = deterministicSessionId(identity);
  assert.equal(a, b);
  assert.match(a, /^sess_[a-f0-9]{64}$/);
  assert.equal(
    occurrenceKey(identity),
    `v1|h1|slot-sun-1|${sundayYmd}`,
  );
});

test("different slot or date yields different session ids", () => {
  const { deterministicSessionId } = loadSession();
  const base = deterministicSessionId({
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
  });
  const otherSlot = deterministicSessionId({
    halaqaId: "h1",
    slotId: "slot-other",
    date: sundayYmd,
  });
  const otherDate = deterministicSessionId({
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: "2026-09-20",
  });
  const otherHalaqa = deterministicSessionId({
    halaqaId: "h2",
    slotId: "slot-sun-1",
    date: sundayYmd,
  });
  assert.notEqual(base, otherSlot);
  assert.notEqual(base, otherDate);
  assert.notEqual(base, otherHalaqa);
});

test("session id does not depend on client randomness or wall clock", () => {
  const { deterministicSessionId } = loadSession();
  const ids = new Set();
  for (let i = 0; i < 20; i++) {
    ids.add(
      deterministicSessionId({
        halaqaId: "h1",
        slotId: "slot-sun-1",
        date: sundayYmd,
      }),
    );
  }
  assert.equal(ids.size, 1);
});

test("valid materialization builds snapshot fields", () => {
  const { buildSessionSnapshot, SESSION_STATUS_SCHEDULED } = loadSession();
  const snap = buildSessionSnapshot({
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
    halaqa: halaqaOk,
  });
  assert.equal(snap.halaqaId, "h1");
  assert.equal(snap.slotId, "slot-sun-1");
  assert.equal(snap.date, sundayYmd);
  assert.equal(snap.teacherId, "teacher-1");
  assert.equal(snap.supervisorId, "supervisor-1");
  assert.equal(snap.status, SESSION_STATUS_SCHEDULED);
  assert.ok(snap.endAt.getTime() > snap.startAt.getTime());
});

test("Cairo wall times: start/end on requested Cairo date", () => {
  const { buildSessionSnapshot } = loadSession();
  const { cairoYmd } = loadCairo();
  const snap = buildSessionSnapshot({
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
    halaqa: halaqaOk,
  });
  assert.equal(cairoYmd(snap.startAt), sundayYmd);
  assert.equal(cairoYmd(snap.endAt), sundayYmd);
  // 16:00 Cairo in Sep 2026 (UTC+3) → 13:00 UTC
  assert.equal(snap.startAt.toISOString(), "2026-09-13T13:00:00.000Z");
  assert.equal(snap.endAt.toISOString(), "2026-09-13T14:00:00.000Z");
});

test("Cairo date boundary near midnight UTC still uses Africa/Cairo", () => {
  const { cairoYmd, cairoLocalDateTimeToUtc, cairoWeekdayMon1 } = loadCairo();
  const late = new Date(Date.UTC(2026, 8, 12, 22, 30, 0));
  assert.equal(cairoYmd(late), "2026-09-13");
  assert.equal(cairoWeekdayMon1("2026-09-13"), 7);
  const local = cairoLocalDateTimeToUtc("2026-09-13", 0, 30);
  assert.equal(cairoYmd(local), "2026-09-13");
});

test("missing slotId fails (never invents replacement)", () => {
  const { buildSessionSnapshot } = loadSession();
  assert.throws(
    () =>
      buildSessionSnapshot({
        halaqaId: "h1",
        slotId: "",
        date: sundayYmd,
        halaqa: halaqaOk,
      }),
    /slotId is required/,
  );
});

test("empty schedule rejected", () => {
  const { buildSessionSnapshot } = loadSession();
  assert.throws(
    () =>
      buildSessionSnapshot({
        halaqaId: "h1",
        slotId: "slot-sun-1",
        date: sundayYmd,
        halaqa: { ...halaqaOk, schedule: [] },
      }),
    /empty/,
  );
});

test("malformed schedule entry for matching slot rejected", () => {
  const { findScheduleSlotById } = loadSession();
  assert.throws(
    () =>
      findScheduleSlotById(
        [{ slotId: "slot-sun-1", day: "", startTime: "16:00", endTime: "17:00" }],
        "slot-sun-1",
      ),
    /malformed/,
  );
});

test("non-array schedule rejected", () => {
  const { buildSessionSnapshot } = loadSession();
  assert.throws(
    () =>
      buildSessionSnapshot({
        halaqaId: "h1",
        slotId: "slot-sun-1",
        date: sundayYmd,
        halaqa: { ...halaqaOk, schedule: null },
      }),
    /malformed|missing/,
  );
});

test("missing slotId in schedule rejected (wrong halaqa/slot relationship)", () => {
  const { buildSessionSnapshot } = loadSession();
  assert.throws(
    () =>
      buildSessionSnapshot({
        halaqaId: "h1",
        slotId: "slot-from-other-halaqa",
        date: sundayYmd,
        halaqa: halaqaOk,
      }),
    /not found/,
  );
});

test("weekday mismatch rejected", () => {
  const { buildSessionSnapshot } = loadSession();
  assert.throws(
    () =>
      buildSessionSnapshot({
        halaqaId: "h1",
        slotId: "slot-sun-1",
        date: "2026-09-14",
        halaqa: halaqaOk,
      }),
    /weekday/,
  );
});

test("missing teacherId rejected", () => {
  const { buildSessionSnapshot } = loadSession();
  assert.throws(
    () =>
      buildSessionSnapshot({
        halaqaId: "h1",
        slotId: "slot-sun-1",
        date: sundayYmd,
        halaqa: { ...halaqaOk, teacherId: "" },
      }),
    /teacherId/,
  );
});

test("authorization: admin and assigned teacher only", () => {
  const { canCallerMaterialize } = loadSession();
  assert.equal(
    canCallerMaterialize({
      callerUid: "admin-1",
      callerRole: "admin",
      halaqaTeacherId: "teacher-1",
    }),
    true,
  );
  assert.equal(
    canCallerMaterialize({
      callerUid: "teacher-1",
      callerRole: "teacher",
      halaqaTeacherId: "teacher-1",
    }),
    true,
  );
  assert.equal(
    canCallerMaterialize({
      callerUid: "teacher-2",
      callerRole: "teacher",
      halaqaTeacherId: "teacher-1",
    }),
    false,
  );
  assert.equal(
    canCallerMaterialize({
      callerUid: "supervisor-1",
      callerRole: "supervisor",
      halaqaTeacherId: "teacher-1",
    }),
    false,
  );
  assert.equal(
    canCallerMaterialize({
      callerUid: "parent-1",
      callerRole: "parent",
      halaqaTeacherId: "teacher-1",
    }),
    false,
  );
});

test("repeated materialize reuses existing without rewriting createdAt/createdBy", async () => {
  const { materializeInMemory } = loadSession();
  const store = new Map();
  const locks = new Map();
  const identity = {
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
  };
  const first = await materializeInMemory({
    store,
    locks,
    identity,
    halaqa: halaqaOk,
    createdBy: "teacher-1",
    now: new Date("2026-09-01T10:00:00.000Z"),
  });
  assert.equal(first.created, true);
  assert.equal(first.doc.createdBy, "teacher-1");
  const createdAt = first.doc.createdAt;
  const startAt = first.doc.startAt;
  const endAt = first.doc.endAt;
  const teacherId = first.doc.teacherId;
  const supervisorId = first.doc.supervisorId;

  const second = await materializeInMemory({
    store,
    locks,
    identity,
    halaqa: {
      teacherId: "teacher-NEW",
      supervisorId: "supervisor-NEW",
      schedule: [
        {
          ...sundaySlot,
          startTime: "18:00",
          endTime: "19:00",
        },
      ],
    },
    createdBy: "admin-2",
    now: new Date("2026-09-20T10:00:00.000Z"),
  });
  assert.equal(second.created, false);
  assert.equal(second.sessionId, first.sessionId);
  assert.equal(second.doc.createdBy, "teacher-1");
  assert.equal(second.doc.createdAt, createdAt);
  assert.equal(second.doc.teacherId, teacherId);
  assert.equal(second.doc.supervisorId, supervisorId);
  assert.equal(second.doc.startAt.getTime(), startAt.getTime());
  assert.equal(second.doc.endAt.getTime(), endAt.getTime());
  assert.equal(store.size, 1);
});

test("historical session survives empty/malformed schedule on rematerialize", async () => {
  const { materializeInMemory } = loadSession();
  const store = new Map();
  const locks = new Map();
  const identity = {
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
  };
  const first = await materializeInMemory({
    store,
    locks,
    identity,
    halaqa: halaqaOk,
    createdBy: "teacher-1",
  });
  const again = await materializeInMemory({
    store,
    locks,
    identity,
    halaqa: { teacherId: "teacher-1", schedule: [] },
    createdBy: "admin-1",
  });
  assert.equal(again.created, false);
  assert.equal(again.sessionId, first.sessionId);
  assert.equal(again.doc.startAt.getTime(), first.doc.startAt.getTime());
});

test("new Cairo date creates a distinct Session snapshot", async () => {
  const { materializeInMemory } = loadSession();
  const store = new Map();
  const locks = new Map();
  const a = await materializeInMemory({
    store,
    locks,
    identity: { halaqaId: "h1", slotId: "slot-sun-1", date: sundayYmd },
    halaqa: halaqaOk,
    createdBy: "teacher-1",
  });
  const nextSunday = "2026-09-20";
  const b = await materializeInMemory({
    store,
    locks,
    identity: { halaqaId: "h1", slotId: "slot-sun-1", date: nextSunday },
    halaqa: {
      ...halaqaOk,
      schedule: [{ ...sundaySlot, startTime: "18:00", endTime: "19:00" }],
    },
    createdBy: "teacher-1",
  });
  assert.notEqual(a.sessionId, b.sessionId);
  assert.equal(store.size, 2);
  assert.notEqual(a.doc.startAt.getTime(), b.doc.startAt.getTime());
});

test("concurrent locked materialization produces one Session", async () => {
  const { materializeInMemory } = loadSession();
  const store = new Map();
  const locks = new Map();
  const identity = {
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
  };
  const results = await Promise.all(
    Array.from({ length: 40 }, (_, i) =>
      materializeInMemory({
        store,
        locks,
        identity,
        halaqa: halaqaOk,
        createdBy: `caller-${i}`,
      }),
    ),
  );
  assert.equal(store.size, 1);
  assert.equal(new Set(results.map((r) => r.sessionId)).size, 1);
  assert.equal(results.filter((r) => r.created).length, 1);
  assert.equal(results.filter((r) => !r.created).length, 39);
});

test("optimistic race-window retries converge on one Session", async () => {
  const { materializeOptimisticRetry } = loadSession();
  const store = new Map();
  const identity = {
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
  };
  const results = await Promise.all(
    Array.from({ length: 25 }, (_, i) =>
      materializeOptimisticRetry({
        store,
        identity,
        halaqa: halaqaOk,
        createdBy: `race-${i}`,
        now: new Date("2026-09-01T12:00:00.000Z"),
      }),
    ),
  );
  assert.equal(store.size, 1);
  assert.equal(new Set(results.map((r) => r.sessionId)).size, 1);
  assert.equal(results.filter((r) => r.created).length, 1);
  const winner = results.find((r) => r.created);
  assert.ok(winner);
  for (const r of results) {
    assert.equal(r.doc.createdAt, winner.doc.createdAt);
    assert.equal(r.doc.createdBy, winner.doc.createdBy);
    assert.equal(r.doc.startAt.getTime(), winner.doc.startAt.getTime());
  }
});

test("decideMaterialize reuse preserves existing identity fields", () => {
  const { decideMaterialize, deterministicSessionId } = loadSession();
  const identity = {
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
  };
  const existing = {
    halaqaId: "h1",
    slotId: "slot-sun-1",
    date: sundayYmd,
    startAt: new Date("2026-09-13T13:00:00.000Z"),
    endAt: new Date("2026-09-13T14:00:00.000Z"),
    teacherId: "teacher-1",
    supervisorId: "supervisor-1",
    status: "completed",
    createdAt: new Date("2026-01-01T00:00:00.000Z"),
    createdBy: "orig",
  };
  const d = decideMaterialize({
    identity,
    existing,
    halaqa: {
      teacherId: "other-teacher",
      supervisorId: "other-supervisor",
      schedule: [
        { ...sundaySlot, startTime: "20:00", endTime: "21:00" },
      ],
    },
  });
  assert.equal(d.action, "reuse");
  assert.equal(d.sessionId, deterministicSessionId(identity));
  assert.equal(d.existing.createdBy, "orig");
  assert.equal(d.existing.status, "completed");
  assert.equal(d.existing.teacherId, "teacher-1");
  assert.equal(d.existing.supervisorId, "supervisor-1");
  assert.equal(
    d.existing.startAt.getTime(),
    existing.startAt.getTime(),
  );
});

test("session status enum matches C6", () => {
  const { SESSION_STATUSES, isValidSessionStatus } = loadSession();
  assert.deepEqual([...SESSION_STATUSES], [
    "scheduled",
    "in_progress",
    "completed",
    "cancelled",
  ]);
  assert.equal(isValidSessionStatus("scheduled"), true);
  assert.equal(isValidSessionStatus("live"), false);
});

test("index exports materializeSession and keeps Paymob quarantined", async () => {
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
  assert.match(src, /materializeSession/);
  assert.match(src, /sessions\/materializeSession/);
  assert.doesNotMatch(src, /^export \{ createPaymentIntention/m);
  assert.doesNotMatch(src, /^export \{ paymobWebhook/m);
});

test("materializeSession enforces production gate + auth + ignores client staff fields", async () => {
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
  assert.match(src, /assertBackendAllowed\("materializeSession"\)/);
  assert.match(src, /unauthenticated/);
  assert.match(src, /canCallerMaterialize/);
  assert.match(src, /runTransaction/);
  assert.match(src, /FieldValue\.serverTimestamp/);
  assert.match(src, /الحلقة غير موجودة/);
  assert.match(src, /halaqaRaw\.teacherId/);
  assert.match(src, /Ignored if present/);
  // Must not assign snapshot teacher from request payload.
  assert.doesNotMatch(src, /teacherId:\s*data\.teacherId/);
  assert.doesNotMatch(src, /supervisorId:\s*data\.supervisorId/);
});
