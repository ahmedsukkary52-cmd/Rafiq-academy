/**
 * Phase 1A — journey position engine on synthetic, non-Quranic fixtures only
 * (plan §5.9-1, coverage items 1–5). The same fixture drives the Dart test
 * `test/shared/quran/journey_position_synthetic_test.dart`, so equal
 * expectations on both sides are the Dart <-> TypeScript parity check.
 *
 * The module under test is compiled from src/ into a temporary directory
 * under os.tmpdir() (fixtures/compile_src_modules.mjs); lib/ is never
 * read or written, so no `npm run build` is needed.
 *
 * Run: cd functions && node --test test/journey_position_synthetic.test.mjs
 */
import assert from "node:assert/strict";
import test, { after } from "node:test";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { compileSrcModules } from "./fixtures/compile_src_modules.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");
const compiled = compileSrcModules(["quran/quranPosition"]);
after(() => compiled.dispose());
const {
  PROGRESS_BP_WHOLE,
  QuranIndex,
  QuranIndexFormatError,
  InvalidQuranReferenceError,
  computeJourneyPosition,
  globalIndex,
  juzOf,
  levelForJuz,
  quranRangeIssue,
  quranVerseIssue,
  upperBound,
} = compiled.load("quran/quranPosition");

const fixture = JSON.parse(
  readFileSync(join(repoRoot, "test/fixtures/quran_journey_synthetic_v1.json"), "utf8"),
);

const ref = ([s, a]) => ({ s, a });
const indexFrom = (parts) =>
  QuranIndex.fromParts({
    ayahCounts: parts.ayahCounts,
    juzStarts: parts.juzStarts.map(ref),
    wordCounts: parts.wordCounts,
  });
const indexes = Object.fromEntries(
  Object.entries(fixture.indexes).map(([name, parts]) => [name, indexFrom(parts)]),
);

/** Every verse of `index` in reading order. */
function* verses(index) {
  for (let s = 1; s <= index.surahCount; s++) {
    for (let a = 1; a <= index.ayahCount(s); a++) yield { s, a };
  }
}
const at = (index, v) => computeJourneyPosition(index, { from: v, to: v });

test("fixture is marked synthetic and non-Quranic", () => {
  assert.equal(fixture.synthetic, true);
  assert.match(fixture.notice, /Synthetic data, not Quranic data/);
  assert.equal(fixture.schemaVersion, 1);
});

test("upperBound counts elements <= value", () => {
  for (const c of fixture.upperBoundCases) {
    assert.equal(upperBound(c.sorted, c.value), c.expect, JSON.stringify(c));
  }
});

test("juzOf: a verse on a part start belongs to that part", () => {
  const index = indexes[fixture.juzOfCases.index];
  for (const c of fixture.juzOfCases.cases) {
    assert.equal(juzOf(index, c.g), c.expectJuz, `g = ${c.g}`);
  }
  for (const g of [0, index.verseCount + 1, 1.5, Number.NaN]) {
    assert.throws(() => juzOf(index, g), RangeError, String(g));
  }
});

test("levelForJuz runs in reverse part order and rejects other parts", () => {
  const index = indexes.main;
  assert.equal(levelForJuz(index, 1), index.juzCount);
  assert.equal(levelForJuz(index, index.juzCount), 1);
  for (const juz of [0, index.juzCount + 1, 2.5]) {
    assert.throws(() => levelForJuz(index, juz), RangeError, String(juz));
  }
});

test("globalIndex numbers every verse 1..verseCount in reading order", () => {
  for (const index of Object.values(indexes)) {
    const globals = [...verses(index)].map((v) => globalIndex(index, v));
    assert.deepEqual(globals, Array.from({ length: index.verseCount }, (_, i) => i + 1));
  }
  assert.throws(
    () => globalIndex(indexes.main, { s: 2, a: 2 }),
    (e) => e instanceof InvalidQuranReferenceError && e.issue === "ayahOutOfRange",
  );
});

test("computeJourneyPosition: named cases", () => {
  for (const c of fixture.positionCases) {
    const range = { from: ref(c.from), to: ref(c.to) };
    assert.deepEqual(computeJourneyPosition(indexes[c.index], range), c.expect, c.description);
  }
});

test("computeJourneyPosition matches the shared table for every synthetic position", () => {
  const rows = fixture.allPositions.rows;
  assert.deepEqual(Object.keys(rows).sort(), Object.keys(indexes).sort());
  for (const [name, table] of Object.entries(rows)) {
    const index = indexes[name];
    const actual = [...verses(index)].map((v) => {
      const p = at(index, v);
      return [v.s, v.a, p.juz, p.level, p.progressBp];
    });
    assert.deepEqual(actual, table, name);
  }
});

test("progress is monotonic inside each part, ends at 10000 and starts above 0", () => {
  for (const [name, index] of Object.entries(indexes)) {
    const byJuz = new Map();
    for (const v of verses(index)) {
      const p = at(index, v);
      assert.equal(p.level, levelForJuz(index, p.juz));
      assert.ok(Number.isSafeInteger(p.progressBp));
      if (!byJuz.has(p.juz)) byJuz.set(p.juz, []);
      byJuz.get(p.juz).push(p.progressBp);
    }
    assert.deepEqual([...byJuz.keys()], Array.from({ length: index.juzCount }, (_, i) => i + 1));
    for (const [juz, bps] of byJuz) {
      const where = `${name} part ${juz}`;
      assert.ok(bps[0] > 0, where);
      assert.equal(bps[bps.length - 1], PROGRESS_BP_WHOLE, where);
      bps.forEach((bp, i) => assert.ok(i === 0 || bp >= bps[i - 1], where));
    }
  }
});

test("computeJourneyPosition depends only on the end of the range (D6)", () => {
  const index = indexes.main;
  const all = [...verses(index)];
  all.forEach((to, i) => {
    const expected = at(index, to);
    for (const from of all.slice(0, i + 1)) {
      assert.deepEqual(computeJourneyPosition(index, { from, to }), expected);
    }
  });
});

test("invalid ranges are reported and thrown with the same issue", () => {
  for (const c of fixture.invalidRangeCases) {
    const index = indexes[c.index];
    const range = { from: ref(c.from), to: ref(c.to) };
    assert.equal(quranRangeIssue(index, range), c.expectIssue, c.description);
    assert.throws(
      () => computeJourneyPosition(index, range),
      (e) => e instanceof InvalidQuranReferenceError && e.issue === c.expectIssue && e.reference === range,
      c.description,
    );
  }
  assert.equal(quranRangeIssue(indexes.main, { from: { s: 1, a: 1 }, to: { s: 7, a: 6 } }), null);
});

test("request-shaped input that is not two integer verses is malformed (server side only)", () => {
  const index = indexes.main;
  const malformedVerses = [null, undefined, 3, "1:1", {}, { s: 1 }, { s: "1", a: 1 }, { s: 1, a: 1.5 }, { s: Number.NaN, a: 1 }, { s: 1, a: Infinity }];
  for (const v of malformedVerses) {
    assert.equal(quranVerseIssue(index, v), "malformedReference", JSON.stringify(v));
    assert.equal(quranRangeIssue(index, { from: { s: 1, a: 1 }, to: v }), "malformedReference");
    assert.throws(() => computeJourneyPosition(index, { from: v, to: v }), InvalidQuranReferenceError);
  }
  for (const r of [null, undefined, "1:1-1:2", []]) {
    assert.equal(quranRangeIssue(index, r), "malformedReference", String(r));
  }
});

test("QuranIndex.fromParts rejects malformed index data with a typed issue", () => {
  for (const c of fixture.invalidIndexCases) {
    assert.throws(
      () => indexFrom(c),
      (e) => e instanceof QuranIndexFormatError && e.issue === c.expectIssue,
      c.description,
    );
  }
  const valid = fixture.indexes.main;
  const bad = (patch, issue) =>
    assert.throws(
      () => QuranIndex.fromParts({ ayahCounts: valid.ayahCounts, juzStarts: valid.juzStarts.map(ref), wordCounts: valid.wordCounts, ...patch }),
      (e) => e instanceof QuranIndexFormatError && e.issue === issue,
      JSON.stringify(patch),
    );
  bad({ ayahCounts: null }, "emptyCatalog");
  bad({ ayahCounts: [3, 1.5, 5, 2, 4, 1, 6] }, "invalidAyahCount");
  bad({ ayahCounts: [3, "1", 5, 2, 4, 1, 6] }, "invalidAyahCount");
  bad({ wordCounts: valid.wordCounts.map((w, i) => (i === 4 ? 0.5 : w)) }, "invalidWordCount");
  bad({ wordCounts: null }, "wordCountLengthMismatch");
  bad({ juzStarts: [{ s: 1, a: 1 }, { s: 3, a: "3" }] }, "juzStartOutOfCatalog");
});

test("QuranIndex exposes the catalog shape and is immutable", () => {
  const index = indexes.main;
  const parts = fixture.indexes.main;
  assert.equal(index.surahCount, parts.ayahCounts.length);
  assert.equal(index.verseCount, parts.ayahCounts.reduce((a, b) => a + b, 0));
  assert.equal(index.juzCount, parts.juzStarts.length);
  assert.deepEqual(
    Array.from({ length: index.surahCount }, (_, i) => index.ayahCount(i + 1)),
    parts.ayahCounts,
  );
  assert.throws(() => index.ayahCount(0), RangeError);
  assert.throws(() => index.ayahCount(index.surahCount + 1), RangeError);
  assert.ok(Object.isFrozen(index.juzStartGlobal));

  const ayahCounts = [2, 1];
  const juzStarts = [{ s: 1, a: 1 }, { s: 2, a: 1 }];
  const wordCounts = [1, 3, 2];
  const small = QuranIndex.fromParts({ ayahCounts, juzStarts, wordCounts });
  const before = at(small, { s: 1, a: 1 });
  ayahCounts[0] = 9;
  juzStarts.push({ s: 1, a: 2 });
  wordCounts[0] = 100;
  assert.equal(small.ayahCount(1), 2);
  assert.deepEqual([...small.juzStartGlobal], [1, 3]);
  assert.deepEqual(at(small, { s: 1, a: 1 }), before);
});

test("QuranIndex is frozen at run time: mutation attempts throw and change nothing", () => {
  // ES modules run in strict mode, so writes to frozen objects throw TypeError.
  const index = indexFrom(fixture.indexes.main);
  const everyPosition = () =>
    Array.from({ length: index.surahCount }, (_, i) => i + 1).flatMap((s) =>
      Array.from({ length: index.ayahCount(s) }, (_, i) => at(index, { s, a: i + 1 })),
    );
  const before = everyPosition();

  assert.ok(Object.isFrozen(index));
  const fields = Object.keys(index);
  assert.ok(fields.length > 0);
  for (const field of fields) {
    const stored = index[field];
    assert.ok(Array.isArray(stored) && Object.isFrozen(stored), field);
    assert.throws(() => stored.push(1), TypeError, field);
    assert.throws(() => { stored[0] = 999; }, TypeError, field);
    assert.throws(() => { index[field] = [0, 1, 2, 3]; }, TypeError, field);
    assert.throws(() => { delete index[field]; }, TypeError, field);
  }
  assert.throws(() => { index.extra = 1; }, TypeError);
  assert.throws(() => { index.globalOf = () => 1; }, TypeError);
  assert.throws(() => { index.wordsThrough = () => 0; }, TypeError);
  assert.throws(() => { index.juzStartGlobal.length = 0; }, TypeError);

  assert.deepEqual(everyPosition(), before);
});
