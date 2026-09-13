/**
 * WA-8 / C6 — pure Session materialization helpers.
 *
 * A Session is one occurrence of one Halaqa schedule slot on one Cairo date.
 * Uniqueness: (halaqaId, slotId, date). Deterministic doc id — no random IDs.
 */

import { createHash } from "node:crypto";
import {
  cairoLocalDateTimeToUtc,
  cairoWeekdayMon1,
  normalizeCairoYmd,
} from "../billing/cairoTime";

export const SESSION_STATUSES = [
  "scheduled",
  "in_progress",
  "completed",
  "cancelled",
] as const;

export type SessionStatus = (typeof SESSION_STATUSES)[number];

export const SESSION_STATUS_SCHEDULED: SessionStatus = "scheduled";

export type ScheduleSlot = {
  slotId: string;
  day: string;
  startTime: string;
  endTime: string;
  raw: Record<string, unknown>;
};

export type MaterializeIdentity = {
  halaqaId: string;
  slotId: string;
  /** Cairo calendar date YYYY-MM-DD */
  date: string;
};

export type SessionSnapshotFields = MaterializeIdentity & {
  startAt: Date;
  endAt: Date;
  teacherId: string;
  supervisorId?: string;
  status: SessionStatus;
};

export type ExistingSessionDoc = {
  halaqaId?: unknown;
  slotId?: unknown;
  date?: unknown;
  startAt?: unknown;
  endAt?: unknown;
  teacherId?: unknown;
  supervisorId?: unknown;
  status?: unknown;
  createdAt?: unknown;
  createdBy?: unknown;
  updatedAt?: unknown;
};

export type MaterializeDecision =
  | {
      action: "reuse";
      sessionId: string;
      /** Existing data returned as-is — never rewrite identity/snapshot. */
      existing: ExistingSessionDoc;
    }
  | {
      action: "create";
      sessionId: string;
      fields: SessionSnapshotFields;
    };

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireNonEmptyString(raw: unknown, field: string): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new Error(`${field} is required`);
  }
  return raw.trim();
}

/** Canonical occurrence key used for hashing (not the Firestore doc id). */
export function occurrenceKey(identity: MaterializeIdentity): string {
  const halaqaId = requireNonEmptyString(identity.halaqaId, "halaqaId");
  const slotId = requireNonEmptyString(identity.slotId, "slotId");
  const date = normalizeCairoYmd(identity.date);
  return `v1|${halaqaId}|${slotId}|${date}`;
}

/**
 * Deterministic Firestore document id for (halaqaId, slotId, Cairo date).
 * Full SHA-256 hex (256-bit) — no client randomness; collision risk negligible
 * for academy-scale occurrence keys.
 */
export function deterministicSessionId(identity: MaterializeIdentity): string {
  const digest = createHash("sha256")
    .update(occurrenceKey(identity), "utf8")
    .digest("hex");
  return `sess_${digest}`;
}

function normalizeDigits(input: string): string {
  const eastern = "٠١٢٣٤٥٦٧٨٩";
  const persian = "۰۱۲۳۴۵۶۷۸۹";
  let out = "";
  for (const ch of input) {
    const e = eastern.indexOf(ch);
    if (e >= 0) {
      out += String(e);
      continue;
    }
    const p = persian.indexOf(ch);
    if (p >= 0) {
      out += String(p);
      continue;
    }
    out += ch;
  }
  return out;
}

/** Parses HH:mm / H:mm and Arabic ص/م / am/pm variants. */
export function parseClockTime(
  raw: string,
): { hour: number; minute: number } | null {
  const text = normalizeDigits(raw.trim());
  if (!text) return null;
  const match = /^(\d{1,2})[:.](\d{2})\s*(ص|م|am|pm)?$/i.exec(text);
  if (!match) return null;
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  if (
    !Number.isInteger(hour) ||
    !Number.isInteger(minute) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59
  ) {
    return null;
  }
  const period = match[3]?.toLowerCase();
  if (period) {
    const isPm = period === "م" || period === "pm";
    const isAm = period === "ص" || period === "am";
    if (isPm || isAm) {
      hour = hour % 12;
      if (isPm) hour += 12;
    }
  }
  return { hour, minute };
}

/**
 * ISO weekday 1=Mon…7=Sun for Arabic/English day labels used on schedule slots.
 * Returns null when the label is empty/unknown (invalid session source).
 */
export function weekdayFromSlotDayLabel(raw: string): number | null {
  const day = raw.trim().toLowerCase();
  if (!day) return null;
  const map: Record<string, number> = {
    الاثنين: 1,
    الإثنين: 1,
    الثلاثاء: 2,
    الأربعاء: 3,
    الاربعاء: 3,
    الخميس: 4,
    الجمعة: 5,
    السبت: 6,
    الأحد: 7,
    الاحد: 7,
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6,
    sunday: 7,
    mon: 1,
    tue: 2,
    wed: 3,
    thu: 4,
    fri: 5,
    sat: 6,
    sun: 7,
  };
  return map[day] ?? map[raw.trim()] ?? null;
}

/**
 * Find a schedule slot by stable WA-7 slotId.
 * Missing/empty slotId on the request must fail — never invent a replacement.
 */
export function findScheduleSlotById(
  schedule: unknown,
  slotId: string,
): ScheduleSlot {
  const want = requireNonEmptyString(slotId, "slotId");
  if (!Array.isArray(schedule)) {
    throw new Error("halaqa schedule is missing or malformed");
  }
  if (schedule.length === 0) {
    throw new Error("halaqa schedule is empty");
  }

  let found: ScheduleSlot | null = null;
  for (const entry of schedule) {
    if (!isPlainObject(entry)) {
      continue;
    }
    const id =
      typeof entry.slotId === "string" ? entry.slotId.trim() : "";
    if (!id || id !== want) continue;
    const day = typeof entry.day === "string" ? entry.day.trim() : "";
    const startTime =
      typeof entry.startTime === "string" ? entry.startTime.trim() : "";
    const endTime =
      typeof entry.endTime === "string" ? entry.endTime.trim() : "";
    if (!day || !startTime || !endTime) {
      throw new Error("schedule slot is malformed (day/startTime/endTime)");
    }
    if (found) {
      throw new Error("duplicate slotId in halaqa schedule");
    }
    found = { slotId: id, day, startTime, endTime, raw: entry };
  }

  if (!found) {
    throw new Error("schedule slot not found for slotId");
  }
  return found;
}

export function assertSlotMatchesCairoDate(
  slot: ScheduleSlot,
  dateYmd: string,
): void {
  const slotWeekday = weekdayFromSlotDayLabel(slot.day);
  if (slotWeekday == null) {
    throw new Error("schedule slot day label is invalid");
  }
  const dateWeekday = cairoWeekdayMon1(dateYmd);
  if (slotWeekday !== dateWeekday) {
    throw new Error(
      "Cairo date weekday does not match schedule slot day",
    );
  }
}

export function buildOccurrenceTimes(
  slot: ScheduleSlot,
  dateYmd: string,
): { startAt: Date; endAt: Date } {
  const startClock = parseClockTime(slot.startTime);
  const endClock = parseClockTime(slot.endTime);
  if (!startClock || !endClock) {
    throw new Error("schedule slot times are invalid");
  }
  const startAt = cairoLocalDateTimeToUtc(
    dateYmd,
    startClock.hour,
    startClock.minute,
  );
  let endAt = cairoLocalDateTimeToUtc(
    dateYmd,
    endClock.hour,
    endClock.minute,
  );
  if (!(endAt.getTime() > startAt.getTime())) {
    throw new Error("schedule slot endAt must be after startAt");
  }
  return { startAt, endAt };
}

export type HalaqaMaterializeSource = {
  teacherId: unknown;
  supervisorId?: unknown;
  schedule: unknown;
};

/**
 * Build frozen occurrence fields from authoritative Halaqa + slot + Cairo date.
 * Never trusts client-provided teacher/supervisor when halaqa can be resolved.
 */
export function buildSessionSnapshot(params: {
  halaqaId: string;
  slotId: string;
  date: string;
  halaqa: HalaqaMaterializeSource;
}): SessionSnapshotFields {
  const halaqaId = requireNonEmptyString(params.halaqaId, "halaqaId");
  const slotId = requireNonEmptyString(params.slotId, "slotId");
  const date = normalizeCairoYmd(params.date);
  const teacherId = requireNonEmptyString(
    params.halaqa.teacherId,
    "teacherId",
  );
  const supervisorRaw = params.halaqa.supervisorId;
  const supervisorId =
    typeof supervisorRaw === "string" && supervisorRaw.trim().length > 0
      ? supervisorRaw.trim()
      : undefined;

  const slot = findScheduleSlotById(params.halaqa.schedule, slotId);
  assertSlotMatchesCairoDate(slot, date);
  const { startAt, endAt } = buildOccurrenceTimes(slot, date);

  return {
    halaqaId,
    slotId,
    date,
    startAt,
    endAt,
    teacherId,
    ...(supervisorId ? { supervisorId } : {}),
    status: SESSION_STATUS_SCHEDULED,
  };
}

/**
 * Idempotent decision: reuse existing doc or create with snapshot.
 * Does not mutate existing identity / createdAt / createdBy / frozen times.
 */
export function decideMaterialize(params: {
  identity: MaterializeIdentity;
  existing: ExistingSessionDoc | null;
  halaqa: HalaqaMaterializeSource;
}): MaterializeDecision {
  const sessionId = deterministicSessionId(params.identity);
  if (params.existing) {
    return {
      action: "reuse",
      sessionId,
      existing: params.existing,
    };
  }
  const fields = buildSessionSnapshot({
    halaqaId: params.identity.halaqaId,
    slotId: params.identity.slotId,
    date: params.identity.date,
    halaqa: params.halaqa,
  });
  // Guard: identity in fields must match computed id inputs.
  if (deterministicSessionId(fields) !== sessionId) {
    throw new Error("session identity mismatch");
  }
  return { action: "create", sessionId, fields };
}

/** True when status is one of the C6 locked values. */
export function isValidSessionStatus(raw: unknown): raw is SessionStatus {
  return (
    typeof raw === "string" &&
    (SESSION_STATUSES as readonly string[]).includes(raw)
  );
}

/**
 * Server-side materialize authorization (C6 / WA-8).
 * Teacher must be the halaqa's assigned teacherId — never a client-supplied role claim.
 * Supervisor is NOT authorized to materialize (not required by freeze).
 */
export function canCallerMaterialize(params: {
  callerUid: string;
  callerRole: unknown;
  halaqaTeacherId: string;
}): boolean {
  const uid = params.callerUid.trim();
  const teacherId = params.halaqaTeacherId.trim();
  if (!uid || !teacherId) return false;
  if (params.callerRole === "admin") return true;
  if (params.callerRole === "teacher" && teacherId === uid) return true;
  return false;
}

/**
 * In-memory materializer for concurrency/idempotency tests.
 * Mirrors CF strategy: deterministic id + create-only-if-absent under a lock
 * (Firestore transaction analog).
 */
export async function materializeInMemory(params: {
  store: Map<string, ExistingSessionDoc>;
  locks: Map<string, Promise<void>>;
  identity: MaterializeIdentity;
  halaqa: HalaqaMaterializeSource;
  createdBy: string;
  now?: Date;
}): Promise<{
  sessionId: string;
  created: boolean;
  doc: ExistingSessionDoc;
}> {
  const sessionId = deterministicSessionId(params.identity);

  const run = async (): Promise<{
    sessionId: string;
    created: boolean;
    doc: ExistingSessionDoc;
  }> => {
    const existing = params.store.get(sessionId) ?? null;
    const decision = decideMaterialize({
      identity: params.identity,
      existing,
      halaqa: params.halaqa,
    });
    if (decision.action === "reuse") {
      return {
        sessionId: decision.sessionId,
        created: false,
        doc: decision.existing,
      };
    }
    const createdAt = params.now ?? new Date();
    const doc: ExistingSessionDoc = {
      halaqaId: decision.fields.halaqaId,
      slotId: decision.fields.slotId,
      date: decision.fields.date,
      startAt: decision.fields.startAt,
      endAt: decision.fields.endAt,
      teacherId: decision.fields.teacherId,
      ...(decision.fields.supervisorId
        ? { supervisorId: decision.fields.supervisorId }
        : {}),
      status: decision.fields.status,
      createdAt,
      updatedAt: createdAt,
      createdBy: params.createdBy,
    };
    params.store.set(sessionId, doc);
    return { sessionId, created: true, doc };
  };

  // Serialize concurrent callers for the same sessionId (transaction analog).
  const prev = params.locks.get(sessionId) ?? Promise.resolve();
  let release!: () => void;
  const gate = new Promise<void>((r) => {
    release = r;
  });
  params.locks.set(
    sessionId,
    prev.then(() => gate),
  );
  await prev;
  try {
    return await run();
  } finally {
    release();
  }
}

/**
 * Optimistic create with retry — closer to Firestore transaction semantics:
 * read → yield (race window) → re-read → create-only-if-absent.
 * Concurrent callers must converge on one document.
 */
export async function materializeOptimisticRetry(params: {
  store: Map<string, ExistingSessionDoc>;
  identity: MaterializeIdentity;
  halaqa: HalaqaMaterializeSource;
  createdBy: string;
  now?: Date;
  raceDelayMs?: () => number;
  maxAttempts?: number;
}): Promise<{
  sessionId: string;
  created: boolean;
  doc: ExistingSessionDoc;
  attempts: number;
}> {
  const sessionId = deterministicSessionId(params.identity);
  const maxAttempts = params.maxAttempts ?? 32;
  const delay =
    params.raceDelayMs ?? (() => Math.floor(Math.random() * 8));

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const existing = params.store.get(sessionId) ?? null;
    if (existing) {
      return { sessionId, created: false, doc: existing, attempts: attempt };
    }

    // Race window: other callers may create before we write.
    const ms = delay();
    if (ms > 0) {
      await new Promise((r) => setTimeout(r, ms));
    }

    const again = params.store.get(sessionId) ?? null;
    if (again) {
      return { sessionId, created: false, doc: again, attempts: attempt };
    }

    const decision = decideMaterialize({
      identity: params.identity,
      existing: null,
      halaqa: params.halaqa,
    });
    if (decision.action !== "create") {
      throw new Error("expected create decision");
    }

    // Compare-and-set: only the first writer installs the doc.
    if (params.store.has(sessionId)) {
      continue;
    }
    const createdAt = params.now ?? new Date();
    const doc: ExistingSessionDoc = {
      halaqaId: decision.fields.halaqaId,
      slotId: decision.fields.slotId,
      date: decision.fields.date,
      startAt: decision.fields.startAt,
      endAt: decision.fields.endAt,
      teacherId: decision.fields.teacherId,
      ...(decision.fields.supervisorId
        ? { supervisorId: decision.fields.supervisorId }
        : {}),
      status: decision.fields.status,
      createdAt,
      updatedAt: createdAt,
      createdBy: params.createdBy,
    };
    params.store.set(sessionId, doc);
    return { sessionId, created: true, doc, attempts: attempt };
  }
  throw new Error("materializeOptimisticRetry exhausted attempts");
}
