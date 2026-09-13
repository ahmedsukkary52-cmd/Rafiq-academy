/**
 * WA-9 / C7 — Session conflict engine (pure).
 *
 * Half-open intervals [startAt, endAt).
 * Hard: same halaqa | same teacher | student roster intersection.
 * Supervisor overlap is NOT a hard conflict (D9).
 *
 * Status filter (C7 §7.2 / WAVE_A WA-9):
 * - Conflict set participants: `scheduled`, `in_progress`
 * - Always excluded: `cancelled`
 * - `completed` excluded from future scheduling conflict set
 *   ("past completed … do not block history")
 */

export type ConflictReason =
  | "same_halaqa"
  | "same_teacher"
  | "student_roster_intersection"
  | "invalid_interval";

export type ConflictCandidate = {
  sessionId: string;
  halaqaId: string;
  teacherId: string;
  supervisorId?: string | null;
  status: string;
  startAt: Date;
  endAt: Date;
};

export type ConflictRequest = {
  /** Deterministic id of the session being created — excluded from matches. */
  sessionId: string;
  halaqaId: string;
  teacherId: string;
  supervisorId?: string | null;
  startAt: Date;
  endAt: Date;
  /** Authoritative student ids from requested halaqa (not client-supplied). */
  studentIds: string[];
};

export type ConflictHit = {
  reason: ConflictReason;
  conflictingSessionId: string;
  conflictingHalaqaId: string;
};

export type ConflictEvaluation = {
  ok: true;
} | {
  ok: false;
  conflicts: ConflictHit[];
};

/** Statuses that participate in the conflict set (C7). */
export const CONFLICT_PARTICIPANT_STATUSES = [
  "scheduled",
  "in_progress",
] as const;

export function isConflictParticipantStatus(status: unknown): boolean {
  const s = typeof status === "string" ? status.trim() : "";
  return (CONFLICT_PARTICIPANT_STATUSES as readonly string[]).includes(s);
}

/**
 * C7 status filter for conflict detection.
 * cancelled → never; completed → excluded from future scheduling set;
 * scheduled / in_progress → included.
 */
export function sessionParticipatesInConflicts(status: unknown): boolean {
  return isConflictParticipantStatus(status);
}

/** Half-open overlap: aStart < bEnd && bStart < aEnd. */
export function intervalsOverlapHalfOpen(
  aStart: Date,
  aEnd: Date,
  bStart: Date,
  bEnd: Date,
): boolean {
  return aStart.getTime() < bEnd.getTime() && bStart.getTime() < aEnd.getTime();
}

/** Reject zero-duration / inverted / invalid timestamps. */
export function assertValidHalfOpenInterval(startAt: Date, endAt: Date): void {
  if (!(startAt instanceof Date) || Number.isNaN(startAt.getTime())) {
    throw new Error("invalid interval: startAt");
  }
  if (!(endAt instanceof Date) || Number.isNaN(endAt.getTime())) {
    throw new Error("invalid interval: endAt");
  }
  if (!(endAt.getTime() > startAt.getTime())) {
    throw new Error("invalid interval: endAt must be after startAt (half-open)");
  }
}

/** Adjacent half-open intervals share a boundary and do NOT overlap. */
export function intervalsAreAdjacentHalfOpen(
  aStart: Date,
  aEnd: Date,
  bStart: Date,
  bEnd: Date,
): boolean {
  return (
    aEnd.getTime() === bStart.getTime() || bEnd.getTime() === aStart.getTime()
  );
}

export function normalizeStudentIds(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const entry of raw) {
    if (typeof entry !== "string") continue;
    const id = entry.trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

export function studentRostersIntersect(
  a: readonly string[],
  b: readonly string[],
): boolean {
  if (a.length === 0 || b.length === 0) return false;
  const setB = new Set(b);
  for (const id of a) {
    if (setB.has(id)) return true;
  }
  return false;
}

/**
 * Evaluate hard conflicts against candidates.
 * Supervisor-only overlap is ignored (never emits a conflict reason).
 *
 * @param rosterByHalaqaId maps other halaqaId → authoritative studentIds
 *        (requested halaqa roster is on `request.studentIds`).
 */
export function evaluateSessionConflicts(params: {
  request: ConflictRequest;
  candidates: ConflictCandidate[];
  rosterByHalaqaId: Map<string, string[]>;
}): ConflictEvaluation {
  const { request, candidates, rosterByHalaqaId } = params;
  try {
    assertValidHalfOpenInterval(request.startAt, request.endAt);
  } catch {
    return {
      ok: false,
      conflicts: [
        {
          reason: "invalid_interval",
          conflictingSessionId: request.sessionId,
          conflictingHalaqaId: request.halaqaId,
        },
      ],
    };
  }

  const conflicts: ConflictHit[] = [];
  const seen = new Set<string>();

  const push = (hit: ConflictHit) => {
    const key = `${hit.reason}:${hit.conflictingSessionId}`;
    if (seen.has(key)) return;
    seen.add(key);
    conflicts.push(hit);
  };

  for (const cand of candidates) {
    if (cand.sessionId === request.sessionId) continue;
    if (!sessionParticipatesInConflicts(cand.status)) continue;

    let overlaps: boolean;
    try {
      assertValidHalfOpenInterval(cand.startAt, cand.endAt);
      overlaps = intervalsOverlapHalfOpen(
        cand.startAt,
        cand.endAt,
        request.startAt,
        request.endAt,
      );
    } catch {
      continue;
    }
    if (!overlaps) continue;

    if (cand.halaqaId === request.halaqaId) {
      push({
        reason: "same_halaqa",
        conflictingSessionId: cand.sessionId,
        conflictingHalaqaId: cand.halaqaId,
      });
    }

    if (cand.teacherId === request.teacherId) {
      push({
        reason: "same_teacher",
        conflictingSessionId: cand.sessionId,
        conflictingHalaqaId: cand.halaqaId,
      });
    }

    // Supervisor overlap is intentionally not a conflict (D9 / C7).

    if (cand.halaqaId !== request.halaqaId) {
      const otherRoster =
        rosterByHalaqaId.get(cand.halaqaId) ?? [];
      if (studentRostersIntersect(request.studentIds, otherRoster)) {
        push({
          reason: "student_roster_intersection",
          conflictingSessionId: cand.sessionId,
          conflictingHalaqaId: cand.halaqaId,
        });
      }
    }
  }

  if (conflicts.length > 0) return { ok: false, conflicts };
  return { ok: true };
}

/**
 * In-memory concurrent create gate used by tests to model the Cairo-day lock
 * + conflict check used by the Cloud Function.
 */
export async function materializeWithConflictGate(params: {
  store: Map<string, ConflictCandidate & { createdBy: string }>;
  dayLocks: Map<string, Promise<void>>;
  cairoDate: string;
  request: ConflictRequest;
  rosterByHalaqaId: Map<string, string[]>;
  createDoc: ConflictCandidate & { createdBy: string };
}): Promise<
  | { created: true; sessionId: string }
  | { created: false; sessionId: string; reused: true }
  | { created: false; conflict: ConflictEvaluation }
> {
  const lockKey = `cairo_${params.cairoDate}`;
  const prev = params.dayLocks.get(lockKey) ?? Promise.resolve();
  let release!: () => void;
  const gate = new Promise<void>((r) => {
    release = r;
  });
  params.dayLocks.set(lockKey, prev.then(() => gate));
  await prev;
  try {
    const existing = params.store.get(params.request.sessionId);
    if (existing) {
      return {
        created: false,
        sessionId: params.request.sessionId,
        reused: true,
      };
    }

    const candidates = [...params.store.values()];
    const evaluation = evaluateSessionConflicts({
      request: params.request,
      candidates,
      rosterByHalaqaId: params.rosterByHalaqaId,
    });
    if (!evaluation.ok) {
      return { created: false, conflict: evaluation };
    }

    params.store.set(params.request.sessionId, params.createDoc);
    return { created: true, sessionId: params.request.sessionId };
  } finally {
    release();
  }
}

/** Deterministic lock document id for Cairo-day serialization (C7.3). */
export function cairoDayConflictLockId(cairoDate: string): string {
  return `cairo_${cairoDate.trim()}`;
}
