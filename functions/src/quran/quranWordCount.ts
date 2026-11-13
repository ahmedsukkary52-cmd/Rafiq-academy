/**
 * Word-counting rule `words-kfgqpc-hafs-v2.0-v2`, algorithmic part
 * (plan §5.8 condition 2, items 2–4; `tool/quran_index/COUNTING_RULE.md`).
 *
 * Phase 1A: the rule is fixed and tested on synthetic, non-Quranic text only.
 * Applying it to the licensed source is Phase 1B. Client mirror:
 * `lib/shared/quran/quran_word_count.dart`.
 *
 * Matching is by explicit code point ranges on purpose: `\s`, `\p{L}` and
 * other engine-defined classes may differ between Dart and JavaScript, and
 * `\p{L}` would count the U+FC00… verse-end symbols as words.
 */

/**
 * Version id of this rule; any change to it needs a new id. `-v2` replaced
 * `-v1`, whose first range also covered U+0640 TATWEEL.
 */
export const QURAN_WORD_COUNT_RULE_ID = "words-kfgqpc-hafs-v2.0-v2";

/**
 * The only separators: SPACE and NO-BREAK SPACE. Runs of them, and leading or
 * trailing ones, produce no words.
 */
export const SPACE = 0x0020;
export const NO_BREAK_SPACE = 0x00a0;

type CodePointRange = readonly [first: number, last: number];

/**
 * A segment is a word when it holds at least one code point in these inclusive
 * ranges. U+0640 TATWEEL is not a letter: a segment of tatweel alone is not a
 * word, and tatweel next to a letter adds nothing.
 */
export const WORD_LETTER_RANGES: readonly CodePointRange[] = [
  [0x0621, 0x063f],
  [0x0641, 0x064a],
  [0x0671, 0x06d3],
];

/**
 * Code points of Unicode general categories Zs, Zl, Zp, Cc and Cf
 * (Unicode 15.1.0), except the two separators. Any of them fails the count.
 */
export const DISALLOWED_CODE_POINT_RANGES: readonly CodePointRange[] = [
  [0x0000, 0x001f],
  [0x007f, 0x009f],
  [0x00ad, 0x00ad],
  [0x0600, 0x0605],
  [0x061c, 0x061c],
  [0x06dd, 0x06dd],
  [0x070f, 0x070f],
  [0x0890, 0x0891],
  [0x08e2, 0x08e2],
  [0x1680, 0x1680],
  [0x180e, 0x180e],
  [0x2000, 0x200f],
  [0x2028, 0x202f],
  [0x205f, 0x2064],
  [0x2066, 0x206f],
  [0x3000, 0x3000],
  [0xfeff, 0xfeff],
  [0xfff9, 0xfffb],
  [0x110bd, 0x110bd],
  [0x110cd, 0x110cd],
  [0x13430, 0x1343f],
  [0x1bca0, 0x1bca3],
  [0x1d173, 0x1d17a],
  [0xe0001, 0xe0001],
  [0xe0020, 0xe007f],
];

/**
 * The text holds a code point the rule does not allow (a separator other than
 * SPACE / NO-BREAK SPACE, or a control or format character).
 */
export class DisallowedCharacterError extends Error {
  constructor(
    readonly codePoint: number,
    /** UTF-16 code unit offset of `codePoint` in the text. */
    readonly offset: number,
  ) {
    super(
      `disallowed character U+${codePoint.toString(16).toUpperCase().padStart(4, "0")} at offset ${offset}`,
    );
    this.name = "DisallowedCharacterError";
  }
}

function inRanges(ranges: readonly CodePointRange[], codePoint: number): boolean {
  return ranges.some(([first, last]) => codePoint >= first && codePoint <= last);
}

/**
 * Words in `text` under `QURAN_WORD_COUNT_RULE_ID`. The text is used as is
 * (no normalization): it is split on SPACE / NO-BREAK SPACE only, and a
 * segment counts once when it holds a letter from `WORD_LETTER_RANGES`.
 * Throws `DisallowedCharacterError` at the first disallowed code point.
 */
export function countQuranWords(text: string): number {
  let words = 0;
  let segmentHasLetter = false;
  let offset = 0;
  for (const char of text) {
    const codePoint = char.codePointAt(0) as number;
    if (codePoint === SPACE || codePoint === NO_BREAK_SPACE) {
      if (segmentHasLetter) words++;
      segmentHasLetter = false;
    } else if (inRanges(DISALLOWED_CODE_POINT_RANGES, codePoint)) {
      throw new DisallowedCharacterError(codePoint, offset);
    } else if (inRanges(WORD_LETTER_RANGES, codePoint)) {
      segmentHasLetter = true;
    }
    offset += char.length;
  }
  return segmentHasLetter ? words + 1 : words;
}
