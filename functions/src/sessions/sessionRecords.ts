/**
 * PH-02 / C6 — pure helpers for server-authoritative attendance/evaluation.
 *
 * Operational day (D6 collapse): same-day slots of one halaqa form one
 * register. Attendance binds to the real session of the earliest slot of the
 * Cairo date; the register stays editable until the latest slot of that day
 * ends (AttendancePolicy.canEditSession freeze policy, spec §9.3).
 */

import {
  cairoLocalDateTimeToUtc,
  cairoWeekdayMon1,
  cairoYmd,
  normalizeCairoYmd,
} from "../billing/cairoTime";
import {
  buildOccurrenceTimes,
  weekdayFromSlotDayLabel,
} from "./sessionMaterialization";

export const EVALUATION_TYPES = ["memorization", "review"] as const;
export type EvaluationType = (typeof EVALUATION_TYPES)[number];

/** Wire enum (Dart RecitationGrade.name) → stored Arabic label. */
export const GRADE_LABELS: Record<string, string> = {
  excellent: "ممتاز",
  veryGood: "جيد جداً",
  good: "جيد",
  needsRetry: "يحتاج تحسين",
};

export const MAX_ATTENDANCE_MARKS = 300;
export const MAX_EVALUATION_NOTES_LENGTH = 1000;

/** B1: Teacher may edit an evaluation for 24h after it was first created. */
export const EVALUATION_TEACHER_EDIT_WINDOW_MS = 24 * 60 * 60 * 1000;

/**
 * Whether the Teacher edit window is still open. [createdAt] is the
 * server-persisted creation time of the evaluation; a missing anchor fails
 * closed (Admin correction only). Open while `now < createdAt + 24h`.
 */
export function isWithinTeacherEditWindow(
  createdAt: Date | null,
  now: Date,
): boolean {
  if (!createdAt || Number.isNaN(createdAt.getTime())) return false;
  return now.getTime() < createdAt.getTime() + EVALUATION_TEACHER_EDIT_WINDOW_MS;
}

/** Legacy `{halaqaId}_yyyyMMdd` day ids — historical dual-read only. */
export function isLegacySyntheticSessionId(sessionId: string): boolean {
  return /^.+_\d{8}$/.test(sessionId.trim());
}

export function attendanceDocId(sessionId: string, studentId: string): string {
  return `${sessionId}_${studentId}`;
}

export function evaluationDocId(
  sessionId: string,
  studentId: string,
  type: EvaluationType,
): string {
  return `${sessionId}_${studentId}_${type}`;
}

export type DaySlot = { slotId: string; startAt: Date; endAt: Date };

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Every schedule slot that occurs on [dateYmd]. A slot without a WA-7
 * `slotId` fails closed — the migration must run before attendance.
 */
export function operationalSlotsForDate(
  schedule: unknown,
  dateYmd: string,
): DaySlot[] {
  const date = normalizeCairoYmd(dateYmd);
  if (!Array.isArray(schedule)) {
    throw new Error("halaqa schedule is missing or malformed");
  }
  const weekday = cairoWeekdayMon1(date);
  const out: DaySlot[] = [];
  for (const entry of schedule) {
    if (!isPlainObject(entry)) continue;
    const day = text(entry.day);
    if (weekdayFromSlotDayLabel(day) !== weekday) continue;
    const slotId = text(entry.slotId);
    if (!slotId) {
      throw new Error("slotId is required");
    }
    const startTime = text(entry.startTime);
    const endTime = text(entry.endTime);
    if (!startTime || !endTime) {
      throw new Error("schedule slot is malformed (day/startTime/endTime)");
    }
    const { startAt, endAt } = buildOccurrenceTimes(
      { slotId, day, startTime, endTime, raw: entry },
      date,
    );
    out.push({ slotId, startAt, endAt });
  }
  return out;
}

export type OperationalDay = {
  primarySlotId: string;
  startAt: Date;
  endAt: Date;
};

/** Earliest slot owns the register; the day closes with the latest slot. */
export function operationalDay(slots: readonly DaySlot[]): OperationalDay | null {
  if (slots.length === 0) return null;
  const sorted = [...slots].sort(
    (a, b) =>
      a.startAt.getTime() - b.startAt.getTime() ||
      a.slotId.localeCompare(b.slotId),
  );
  const endAt = sorted.reduce(
    (max, s) => (s.endAt.getTime() > max.getTime() ? s.endAt : max),
    sorted[0].endAt,
  );
  return { primarySlotId: sorted[0].slotId, startAt: sorted[0].startAt, endAt };
}

/** Teacher window: the session's own Cairo day, until the day's last slot ends. */
export function isWithinAttendanceWindow(params: {
  now: Date;
  dateYmd: string;
  dayEndAt: Date;
}): boolean {
  return (
    cairoYmd(params.now) === normalizeCairoYmd(params.dateYmd) &&
    params.now.getTime() < params.dayEndAt.getTime()
  );
}

function nextYmd(ymd: string): string {
  const [y, m, d] = normalizeCairoYmd(ymd).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + 1, 12)).toISOString().slice(0, 10);
}

/** Cairo start of day; DST-start days have no 00:00, so the day opens at 01:00. */
function cairoStartOfDay(ymd: string): Date {
  try {
    return cairoLocalDateTimeToUtc(ymd, 0, 0);
  } catch {
    return cairoLocalDateTimeToUtc(ymd, 1, 0);
  }
}

/** [Cairo midnight, next Cairo midnight) — the stored `date` range of a day. */
export function cairoDayRange(dateYmd: string): { start: Date; end: Date } {
  const date = normalizeCairoYmd(dateYmd);
  return {
    start: cairoStartOfDay(date),
    end: cairoStartOfDay(nextYmd(date)),
  };
}
