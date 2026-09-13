/**
 * WA-6 / C5 — Africa/Cairo calendar-day helpers (no client TZ).
 */

const CAIRO_TZ = "Africa/Cairo";

/** YYYY-MM-DD in Africa/Cairo for an instant. */
export function cairoYmd(instant: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: CAIRO_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(instant);
}

/** Signed calendar-day difference: toYmd - fromYmd (Cairo YMD strings). */
export function cairoCalendarDaysBetween(
  fromYmd: string,
  toYmd: string,
): number {
  const a = parseYmdUtcNoon(fromYmd);
  const b = parseYmdUtcNoon(toYmd);
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

function parseYmdUtcNoon(ymd: string): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(ymd.trim());
  if (!m) {
    throw new Error(`invalid Cairo YMD: ${ymd}`);
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  return new Date(Date.UTC(y, mo - 1, d, 12, 0, 0));
}

/**
 * Instant representing Cairo midnight at the start of (dueYmd + graceDays).
 * Used as graceEndsAt / first suspended Cairo day boundary.
 */
export function cairoGraceEndsAtInstant(
  dueYmd: string,
  gracePeriodDays: number,
): Date {
  const days = Math.max(0, Math.floor(gracePeriodDays));
  const base = parseYmdUtcNoon(dueYmd);
  const endDay = new Date(base.getTime() + days * 86_400_000);
  const endYmd = endDay.toISOString().slice(0, 10);
  // Approximate Cairo midnight via UTC 22:00 previous day in winter is fragile;
  // store noon UTC of grace-end YMD as stable day marker (C5 day contract).
  return parseYmdUtcNoon(endYmd);
}

export const CAIRO_TIME_ZONE = CAIRO_TZ;
