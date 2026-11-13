/**
 * Phase 1A — word-counting rule `words-kfgqpc-hafs-v2.0-v2` on synthetic,
 * meaningless letter sequences only (plan §5.9-1, coverage item 6). The same
 * fixture drives `test/shared/quran/word_count_rule_synthetic_test.dart`.
 *
 * The module under test is compiled from src/ into a temporary directory
 * under os.tmpdir() (fixtures/compile_src_modules.mjs); lib/ is never
 * read or written, so no `npm run build` is needed.
 *
 * Run: cd functions && node --test test/quran_word_count_synthetic.test.mjs
 */
import assert from "node:assert/strict";
import test, { after } from "node:test";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { compileSrcModules } from "./fixtures/compile_src_modules.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
const compiled = compileSrcModules(["quran/quranWordCount"]);
after(() => compiled.dispose());
const {
  QURAN_WORD_COUNT_RULE_ID,
  SPACE,
  NO_BREAK_SPACE,
  WORD_LETTER_RANGES,
  DISALLOWED_CODE_POINT_RANGES,
  DisallowedCharacterError,
  countQuranWords,
} = compiled.load("quran/quranWordCount");

const fixture = JSON.parse(
  readFileSync(join(repoRoot, "test/fixtures/quran_journey_synthetic_v1.json"), "utf8"),
);
const spec = fixture.wordCount;
const plain = (ranges) => ranges.map(([first, last]) => [first, last]);

test("fixture is marked synthetic and non-Quranic", () => {
  assert.equal(fixture.synthetic, true);
  assert.match(fixture.notice, /Synthetic data, not Quranic data/);
});

test("rule tables match the shared fixture", () => {
  assert.equal(QURAN_WORD_COUNT_RULE_ID, spec.ruleId);
  assert.deepEqual([SPACE, NO_BREAK_SPACE], spec.separators);
  assert.deepEqual(plain(WORD_LETTER_RANGES), spec.letterRanges);
  assert.equal(spec.unicodeVersion, "15.1.0");
  assert.deepEqual(plain(DISALLOWED_CODE_POINT_RANGES), spec.disallowedRanges);
});

test("rule -v2: U+0640 TATWEEL is not a letter, its neighbours are", () => {
  assert.equal(QURAN_WORD_COUNT_RULE_ID, "words-kfgqpc-hafs-v2.0-v2");
  const isLetter = (cp) => WORD_LETTER_RANGES.some(([first, last]) => first <= cp && cp <= last);
  assert.equal(isLetter(0x0640), false);
  assert.equal(isLetter(0x063f), true);
  assert.equal(isLetter(0x0641), true);
});

test("countQuranWords: shared cases", () => {
  for (const c of spec.cases) {
    if (c.expectError) {
      assert.throws(
        () => countQuranWords(c.text),
        (e) =>
          e instanceof DisallowedCharacterError &&
          e.codePoint === c.expectError.codePoint &&
          e.offset === c.expectError.offset,
        c.description,
      );
    } else {
      assert.equal(countQuranWords(c.text), c.expectWords, c.description);
    }
  }
});

test("a \\p{L} match would miscount the verse-end symbols", () => {
  const naiveCases = spec.cases.filter((c) => c.naivePLetterSegments !== undefined);
  assert.ok(naiveCases.length > 0);
  for (const c of naiveCases) {
    const segments = c.text.split(/[\u0020\u00a0]+/).filter((s) => s !== "" && /\p{L}/u.test(s)).length;
    assert.equal(segments, c.naivePLetterSegments, c.description);
    assert.notEqual(countQuranWords(c.text), c.naivePLetterSegments, c.description);
  }
});

test("fails on the first and last code point of every disallowed range", () => {
  for (const [first, last] of DISALLOWED_CODE_POINT_RANGES) {
    for (const codePoint of new Set([first, last])) {
      assert.throws(
        () => countQuranWords(`ثقص${String.fromCodePoint(codePoint)}`),
        (e) => e instanceof DisallowedCharacterError && e.codePoint === codePoint && e.offset === 3,
        codePoint.toString(16),
      );
    }
  }
});
