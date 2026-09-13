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

/** Validate / normalize a Cairo calendar date string `YYYY-MM-DD`. */
export function normalizeCairoYmd(ymd: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(ymd.trim());
  if (!m) {
    throw new Error(`invalid Cairo YMD: ${ymd}`);
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  // Reject impossible calendar dates (UTC noon round-trip).
  const probe = new Date(Date.UTC(y, mo - 1, d, 12, 0, 0));
  if (
    probe.getUTCFullYear() !== y ||
    probe.getUTCMonth() !== mo - 1 ||
    probe.getUTCDate() !== d
  ) {
    throw new Error(`invalid Cairo YMD: ${ymd}`);
  }
  return `${m[1]}-${m[2]}-${m[3]}`;
}

type CairoParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
};

function cairoParts(instant: Date): CairoParts {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: CAIRO_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(instant);
  const num = (type: string): number => {
    const v = parts.find((p) => p.type === type)?.value;
    if (v == null) throw new Error(`Cairo parts missing ${type}`);
    return Number(v);
  };
  return {
    year: num("year"),
    month: num("month"),
    day: num("day"),
    hour: num("hour"),
    minute: num("minute"),
    second: num("second"),
  };
}

/**
 * Absolute UTC instant for a Cairo wall-clock date+time.
 * Reuses Africa/Cairo — do not introduce a second business timezone.
 */
export function cairoLocalDateTimeToUtc(
  ymd: string,
  hour: number,
  minute: number,
  second = 0,
): Date {
  const normalized = normalizeCairoYmd(ymd);
  if (
    !Number.isInteger(hour) ||
    hour < 0 ||
    hour > 23 ||
    !Number.isInteger(minute) ||
    minute < 0 ||
    minute > 59 ||
    !Number.isInteger(second) ||
    second < 0 ||
    second > 59
  ) {
    throw new Error(`invalid Cairo clock: ${hour}:${minute}:${second}`);
  }
  const [y, mo, d] = normalized.split("-").map(Number);
  // Initial guess as if the wall time were UTC, then correct by Cairo offset.
  let guessMs = Date.UTC(y, mo - 1, d, hour, minute, second);
  for (let i = 0; i < 4; i++) {
    const p = cairoParts(new Date(guessMs));
    const asUtcLike = Date.UTC(
      p.year,
      p.month - 1,
      p.day,
      p.hour,
      p.minute,
      p.second,
    );
    const desired = Date.UTC(y, mo - 1, d, hour, minute, second);
    const delta = desired - asUtcLike;
    guessMs += delta;
    if (delta === 0) break;
  }
  const out = new Date(guessMs);
  // Final verify: Cairo calendar day + clock match.
  const check = cairoParts(out);
  if (
    check.year !== y ||
    check.month !== mo ||
    check.day !== d ||
    check.hour !== hour ||
    check.minute !== minute
  ) {
    throw new Error(
      `failed to resolve Cairo local time ${normalized} ${hour}:${minute}`,
    );
  }
  return out;
}

/**
 * ISO weekday in Africa/Cairo for a Cairo YMD: 1=Monday … 7=Sunday
 * (matches Dart `DateTime.weekday`).
 */
export function cairoWeekdayMon1(ymd: string): number {
  const noon = cairoLocalDateTimeToUtc(normalizeCairoYmd(ymd), 12, 0);
  const label = new Intl.DateTimeFormat("en-US", {
    timeZone: CAIRO_TZ,
    weekday: "short",
  }).format(noon);
  const map: Record<string, number> = {
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
    Sun: 7,
  };
  const n = map[label];
  if (n == null) throw new Error(`unexpected weekday label: ${label}`);
  return n;
}
