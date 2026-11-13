/**
 * Learning-journey position engine (plan §5.4 and §5.6-3, Phase 1A).
 *
 * Maps the end of a new-memorization range to the journey position
 * `{juz, level, progressBp}` against a `QuranIndex` that is always passed in.
 * This module embeds no Quran data: the real index is generated only in
 * Phase 1B, and Phase 1A is tested on synthetic, non-Quranic fixtures
 * (`test/fixtures/quran_journey_synthetic_v1.json` at the repo root).
 *
 * Pure and Firebase-free. Client mirror: `lib/shared/quran/quran_position.dart`.
 * Both sides must return literally equal results for every position, so all
 * arithmetic is on integers; the progress division uses BigInt.
 */

/** Basis points of a whole juz: the last verse of a juz is exactly this. */
export const PROGRESS_BP_WHOLE = 10_000;

/**
 * Upper bound for the total word count of an index, so that
 * `PROGRESS_BP_WHOLE * words` stays a safe integer on both sides.
 */
export const MAX_INDEX_WORDS = Math.floor(Number.MAX_SAFE_INTEGER / PROGRESS_BP_WHOLE);

/** One verse by 1-based surah and ayah numbers (the stored `Range` shape, plan §4). */
export type QuranVerseRef = { s: number; a: number };

/** An inclusive verse range; valid only when `from` does not come after `to`. */
export type QuranRange = { from: QuranVerseRef; to: QuranVerseRef };

/** The derived journey position stored in the journey head (plan §4). */
export type JourneyPosition = {
  /** 1-based juz that contains the end of the range. */
  juz: number;
  /** `juzCount + 1 - juz` (decision #1: levels run in reverse juz order). */
  level: number;
  /** Progress inside `juz` in basis points, `1..PROGRESS_BP_WHOLE`. */
  progressBp: number;
};

/** Why index data was rejected by `QuranIndex.fromParts`. */
export type QuranIndexIssue =
  | "emptyCatalog"
  | "invalidAyahCount"
  | "wordCountLengthMismatch"
  | "invalidWordCount"
  | "totalWordsTooLarge"
  | "emptyJuzStarts"
  | "juzStartOutOfCatalog"
  | "firstJuzNotAtStart"
  | "juzStartsNotIncreasing";

/** Malformed index data: a data or generator defect, never a user input error. */
export class QuranIndexFormatError extends Error {
  constructor(
    readonly issue: QuranIndexIssue,
    message: string,
  ) {
    super(message);
    this.name = "QuranIndexFormatError";
  }
}

/**
 * Why a verse or range is not valid against an index. Callers map any of
 * these to `invalid-argument` (plan §5.4-4). `malformedReference` exists only
 * on this side: request data may carry non-integer or missing numbers, which
 * Dart's types already exclude.
 */
export type QuranReferenceIssue =
  | "malformedReference"
  | "surahOutOfRange"
  | "ayahOutOfRange"
  | "reversedRange";

/**
 * Thrown by `globalIndex` and `computeJourneyPosition` for an invalid
 * reference. Use `quranVerseIssue` or `quranRangeIssue` to check first
 * without throwing.
 */
export class InvalidQuranReferenceError extends Error {
  constructor(
    readonly issue: QuranReferenceIssue,
    readonly reference: unknown,
  ) {
    super(`invalid Quran reference (${issue})`);
    this.name = "InvalidQuranReferenceError";
  }
}

export type QuranIndexParts = {
  ayahCounts: readonly number[];
  juzStarts: readonly QuranVerseRef[];
  wordCounts: readonly number[];
};

const isCount = (value: unknown, max: number): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= 1 && value <= max;

const formatError = (issue: QuranIndexIssue, message: string) =>
  new QuranIndexFormatError(issue, message);

/**
 * Validated, immutable index the engine computes against: ayah counts per
 * surah, the first verse of every juz, and the word count of every verse.
 * Juz starts are given as verse references; their global indexes are derived
 * here, so callers never handle the internal coordinate.
 *
 * Immutable at run time, not only in the types: `fromParts` keeps private
 * copies of the inputs, every stored array is frozen, and so is the instance,
 * so its fields cannot be reassigned or extended (a TypeError in strict mode).
 * Accessors return numbers or the frozen `juzStartGlobal`.
 */
export class QuranIndex {
  private constructor(
    private readonly ayahCounts: readonly number[],
    private readonly surahStart: readonly number[],
    /** Global index of the first verse of each juz, ascending, starting at 1. */
    readonly juzStartGlobal: readonly number[],
    private readonly cumulativeWords: readonly number[],
  ) {
    Object.freeze(this);
  }

  /** Validates the parts and precomputes the prefix sums; throws `QuranIndexFormatError`. */
  static fromParts(parts: QuranIndexParts): QuranIndex {
    const { ayahCounts, juzStarts, wordCounts } = parts;
    if (!Array.isArray(ayahCounts) || ayahCounts.length === 0) {
      throw formatError("emptyCatalog", "ayahCounts is empty");
    }
    // surahStart[i] = number of verses before surah i + 1.
    const surahStart: number[] = [];
    let verseCount = 0;
    ayahCounts.forEach((count, i) => {
      // Every verse has at least one word, so a count above MAX_INDEX_WORDS
      // can never be valid; rejecting it early also keeps the sum exact.
      if (!isCount(count, MAX_INDEX_WORDS)) {
        throw formatError("invalidAyahCount", `surah ${i + 1} has ${String(count)} verses`);
      }
      surahStart.push(verseCount);
      verseCount += count;
    });
    if (!Array.isArray(wordCounts) || wordCounts.length !== verseCount) {
      throw formatError(
        "wordCountLengthMismatch",
        `${Array.isArray(wordCounts) ? wordCounts.length : "no"} word counts for ${verseCount} verses`,
      );
    }
    // cumulativeWords[g] = words in verses 1..g; cumulativeWords[0] = 0.
    const cumulativeWords = [0];
    for (let g = 1; g <= verseCount; g++) {
      const words = wordCounts[g - 1];
      if (!isCount(words, Number.MAX_SAFE_INTEGER)) {
        throw formatError("invalidWordCount", `verse ${g} has ${String(words)} words`);
      }
      const before = cumulativeWords[g - 1];
      if (words > MAX_INDEX_WORDS - before) {
        throw formatError("totalWordsTooLarge", `total words exceed ${MAX_INDEX_WORDS}`);
      }
      cumulativeWords.push(before + words);
    }
    if (!Array.isArray(juzStarts) || juzStarts.length === 0) {
      throw formatError("emptyJuzStarts", "juzStarts is empty");
    }
    const juzStartGlobal: number[] = [];
    for (const start of juzStarts) {
      if (verseIssue(ayahCounts.length, (surah) => ayahCounts[surah - 1], start) !== null) {
        throw formatError("juzStartOutOfCatalog", `juz start ${refText(start)} is not in the catalog`);
      }
      const g = surahStart[start.s - 1] + start.a;
      if (juzStartGlobal.length === 0 && g !== 1) {
        throw formatError(
          "firstJuzNotAtStart",
          `first juz starts at ${refText(start)}, not at the first verse`,
        );
      }
      if (juzStartGlobal.length > 0 && g <= juzStartGlobal[juzStartGlobal.length - 1]) {
        throw formatError(
          "juzStartsNotIncreasing",
          `juz start ${refText(start)} does not follow the previous one`,
        );
      }
      juzStartGlobal.push(g);
    }
    return new QuranIndex(
      Object.freeze([...ayahCounts]),
      Object.freeze(surahStart),
      Object.freeze(juzStartGlobal),
      Object.freeze(cumulativeWords),
    );
  }

  get surahCount(): number {
    return this.ayahCounts.length;
  }

  get verseCount(): number {
    return this.cumulativeWords.length - 1;
  }

  get juzCount(): number {
    return this.juzStartGlobal.length;
  }

  /** Number of verses in `surah`; throws `RangeError` outside `1..surahCount`. */
  ayahCount(surah: number): number {
    checkInterval(surah, 1, this.surahCount, "surah");
    return this.ayahCounts[surah - 1];
  }

  /** @internal `surahStart[s - 1] + a` for an already validated verse. */
  globalOf(ref: QuranVerseRef): number {
    return this.surahStart[ref.s - 1] + ref.a;
  }

  /** @internal Words in verses `1..g`. */
  wordsThrough(g: number): number {
    return this.cumulativeWords[g];
  }
}

function refText(ref: unknown): string {
  const r = ref as Partial<QuranVerseRef> | null;
  return `${String(r?.s)}:${String(r?.a)}`;
}

function checkInterval(value: number, min: number, max: number, name: string): void {
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    throw new RangeError(`${name} must be an integer in ${min}..${max}, got ${String(value)}`);
  }
}

function verseIssue(
  surahCount: number,
  ayahCountOf: (surah: number) => number,
  ref: unknown,
): QuranReferenceIssue | null {
  if (ref === null || typeof ref !== "object") return "malformedReference";
  const { s, a } = ref as Record<string, unknown>;
  if (!Number.isSafeInteger(s) || !Number.isSafeInteger(a)) return "malformedReference";
  const surah = s as number;
  const ayah = a as number;
  if (surah < 1 || surah > surahCount) return "surahOutOfRange";
  if (ayah < 1 || ayah > ayahCountOf(surah)) return "ayahOutOfRange";
  return null;
}

/** Why `ref` is not a verse of `index`, or null when it is. */
export function quranVerseIssue(index: QuranIndex, ref: unknown): QuranReferenceIssue | null {
  return verseIssue(index.surahCount, (surah) => index.ayahCount(surah), ref);
}

/**
 * Why `range` is not valid against `index`, or null when it is. Checks
 * `from`, then `to`, then their order (`from` after `to` is `reversedRange`).
 */
export function quranRangeIssue(index: QuranIndex, range: unknown): QuranReferenceIssue | null {
  if (range === null || typeof range !== "object") return "malformedReference";
  const { from, to } = range as Record<string, unknown>;
  const issue = quranVerseIssue(index, from) ?? quranVerseIssue(index, to);
  if (issue !== null) return issue;
  const r = range as QuranRange;
  return index.globalOf(r.from) > index.globalOf(r.to) ? "reversedRange" : null;
}

/**
 * 1-based position of `ref` in reading order across the whole index
 * (`g = surahStart[s] + a`, plan §5.4-1). Throws `InvalidQuranReferenceError`.
 */
export function globalIndex(index: QuranIndex, ref: QuranVerseRef): number {
  const issue = quranVerseIssue(index, ref);
  if (issue !== null) throw new InvalidQuranReferenceError(issue, ref);
  return index.globalOf(ref);
}

/**
 * Number of elements of the ascending array `sorted` that are `<= value`
 * (a count, not an element index; plan §5.4-2).
 */
export function upperBound(sorted: readonly number[], value: number): number {
  let low = 0;
  let high = sorted.length;
  while (low < high) {
    const mid = low + ((high - low) >> 1);
    if (sorted[mid] <= value) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/**
 * 1-based juz of the verse at global index `g`: `upperBound(juzStartG, g)`.
 * A verse on a juz start belongs to that juz. Throws `RangeError` outside
 * `1..verseCount`.
 */
export function juzOf(index: QuranIndex, g: number): number {
  checkInterval(g, 1, index.verseCount, "g");
  return upperBound(index.juzStartGlobal, g);
}

/** Level of `juz`: `juzCount + 1 - juz`. Throws `RangeError` outside `1..juzCount`. */
export function levelForJuz(index: QuranIndex, juz: number): number {
  checkInterval(juz, 1, index.juzCount, "juz");
  return index.juzCount + 1 - juz;
}

/**
 * Journey position for a new-memorization `range` (plan §5.6-3).
 *
 * The juz, level and progress come from the end of the range only, so a
 * range that spans two parts lands in the later one (D6). The last verse of a
 * juz is exactly `PROGRESS_BP_WHOLE`; the position never moves on to the next
 * juz by itself. Throws `InvalidQuranReferenceError` for an invalid range.
 */
export function computeJourneyPosition(index: QuranIndex, range: QuranRange): JourneyPosition {
  const issue = quranRangeIssue(index, range);
  if (issue !== null) throw new InvalidQuranReferenceError(issue, range);

  const g = index.globalOf(range.to);
  const juz = juzOf(index, g);
  const starts = index.juzStartGlobal;
  const firstVerse = starts[juz - 1];
  const nextJuzFirstVerse = juz < starts.length ? starts[juz] : index.verseCount + 1;
  const wordsBeforeJuz = index.wordsThrough(firstVerse - 1);
  const done = index.wordsThrough(g) - wordsBeforeJuz;
  const total = index.wordsThrough(nextJuzFirstVerse - 1) - wordsBeforeJuz;
  return {
    juz,
    level: levelForJuz(index, juz),
    progressBp: Number((BigInt(PROGRESS_BP_WHOLE) * BigInt(done)) / BigInt(total)),
  };
}
