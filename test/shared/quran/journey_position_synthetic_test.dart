// Phase 1A: journey position engine on synthetic, non-Quranic fixtures only
// (plan §5.9-1, coverage items 1–5). The same fixture drives the server
// mirror test `functions/test/journey_position_synthetic.test.mjs`, so equal
// expectations on both sides are the Dart <-> TypeScript parity check.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/quran/quran_position.dart';

const _fixturePath = 'test/fixtures/quran_journey_synthetic_v1.json';

final Map<String, dynamic> _fixture =
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

QuranVerseRef _ref(List<dynamic> pair) =>
    QuranVerseRef(pair[0] as int, pair[1] as int);

QuranIndex _indexFrom(Map<String, dynamic> parts) => QuranIndex.fromParts(
  ayahCounts: (parts['ayahCounts'] as List).cast<int>(),
  juzStarts: [for (final p in parts['juzStarts'] as List) _ref(p as List)],
  wordCounts: (parts['wordCounts'] as List).cast<int>(),
);

final Map<String, QuranIndex> _indexes = {
  for (final e in (_fixture['indexes'] as Map<String, dynamic>).entries)
    e.key: _indexFrom(e.value as Map<String, dynamic>),
};

List<Map<String, dynamic>> _cases(String key) =>
    (_fixture[key] as List).cast<Map<String, dynamic>>();

/// Every verse of [index] in reading order.
Iterable<QuranVerseRef> _verses(QuranIndex index) sync* {
  for (var s = 1; s <= index.surahCount; s++) {
    for (var a = 1; a <= index.ayahCount(s); a++) {
      yield QuranVerseRef(s, a);
    }
  }
}

JourneyPosition _at(QuranIndex index, QuranVerseRef ref) =>
    computeJourneyPosition(index, QuranRange(ref, ref));

void main() {
  test('fixture is marked synthetic and non-Quranic', () {
    expect(_fixture['synthetic'], isTrue);
    expect(_fixture['notice'], contains('Synthetic data, not Quranic data'));
    expect(_fixture['schemaVersion'], 1);
  });

  group('upperBound counts elements <= value', () {
    for (final c in _cases('upperBoundCases')) {
      final sorted = (c['sorted'] as List).cast<int>();
      test('$sorted, ${c['value']}', () {
        expect(upperBound(sorted, c['value'] as int), c['expect']);
      });
    }
  });

  group('juzOf', () {
    final spec = _fixture['juzOfCases'] as Map<String, dynamic>;
    final index = _indexes[spec['index']]!;

    for (final c in (spec['cases'] as List).cast<Map<String, dynamic>>()) {
      test('g = ${c['g']} is in part ${c['expectJuz']}', () {
        expect(juzOf(index, c['g'] as int), c['expectJuz']);
      });
    }

    test('rejects a global index outside 1..verseCount', () {
      expect(() => juzOf(index, 0), throwsRangeError);
      expect(() => juzOf(index, index.verseCount + 1), throwsRangeError);
    });
  });

  group('levelForJuz', () {
    final index = _indexes['main']!;

    test('runs in reverse part order', () {
      expect(levelForJuz(index, 1), index.juzCount);
      expect(levelForJuz(index, index.juzCount), 1);
    });

    test('rejects a part outside 1..juzCount', () {
      expect(() => levelForJuz(index, 0), throwsRangeError);
      expect(() => levelForJuz(index, index.juzCount + 1), throwsRangeError);
    });
  });

  group('globalIndex', () {
    test('numbers every verse 1..verseCount in reading order', () {
      for (final index in _indexes.values) {
        final globals = [for (final v in _verses(index)) globalIndex(index, v)];
        expect(globals, [for (var g = 1; g <= index.verseCount; g++) g]);
      }
    });

    test('throws a typed error for a verse outside the index', () {
      expect(
        () => globalIndex(_indexes['main']!, const QuranVerseRef(2, 2)),
        throwsA(
          isA<InvalidQuranReferenceException>().having(
            (e) => e.issue,
            'issue',
            QuranReferenceIssue.ayahOutOfRange,
          ),
        ),
      );
    });
  });

  group('computeJourneyPosition', () {
    for (final c in _cases('positionCases')) {
      test(c['description'], () {
        final index = _indexes[c['index']]!;
        final range = QuranRange(
          _ref(c['from'] as List),
          _ref(c['to'] as List),
        );
        final expected = c['expect'] as Map<String, dynamic>;
        expect(
          computeJourneyPosition(index, range),
          JourneyPosition(
            juz: expected['juz'] as int,
            level: expected['level'] as int,
            progressBp: expected['progressBp'] as int,
          ),
        );
      });
    }

    test('matches the shared table for every synthetic position', () {
      final all = _fixture['allPositions'] as Map<String, dynamic>;
      final rows = all['rows'] as Map<String, dynamic>;
      expect(rows.keys, unorderedEquals(_indexes.keys));
      rows.forEach((name, table) {
        final index = _indexes[name]!;
        final actual = [
          for (final v in _verses(index))
            [v.surah, v.ayah, ..._row(_at(index, v))],
        ];
        expect(actual, table, reason: name);
      });
    });

    test('is monotonic inside each part, ends at 10000 and starts above 0', () {
      for (final MapEntry(key: name, value: index) in _indexes.entries) {
        final byJuz = <int, List<int>>{};
        for (final v in _verses(index)) {
          final p = _at(index, v);
          expect(p.level, levelForJuz(index, p.juz), reason: '$name $v');
          byJuz.putIfAbsent(p.juz, () => []).add(p.progressBp);
        }
        expect(byJuz.keys, [for (var j = 1; j <= index.juzCount; j++) j]);
        byJuz.forEach((juz, bps) {
          final reason = '$name part $juz';
          expect(bps.first, greaterThan(0), reason: reason);
          expect(bps.last, kProgressBpWhole, reason: reason);
          for (var i = 1; i < bps.length; i++) {
            expect(bps[i], greaterThanOrEqualTo(bps[i - 1]), reason: reason);
          }
        });
      }
    });

    test('depends only on the end of the range (D6)', () {
      final index = _indexes['main']!;
      final verses = _verses(index).toList();
      for (var i = 0; i < verses.length; i++) {
        final expected = _at(index, verses[i]);
        for (var j = 0; j <= i; j++) {
          expect(
            computeJourneyPosition(index, QuranRange(verses[j], verses[i])),
            expected,
            reason: '${verses[j]}-${verses[i]}',
          );
        }
      }
    });
  });

  group('invalid ranges', () {
    for (final c in _cases('invalidRangeCases')) {
      test(c['description'], () {
        final index = _indexes[c['index']]!;
        final range = QuranRange(
          _ref(c['from'] as List),
          _ref(c['to'] as List),
        );
        final issue = QuranReferenceIssue.values.byName(
          c['expectIssue'] as String,
        );
        expect(quranRangeIssue(index, range), issue);
        expect(
          () => computeJourneyPosition(index, range),
          throwsA(
            isA<InvalidQuranReferenceException>()
                .having((e) => e.issue, 'issue', issue)
                .having((e) => e.reference, 'reference', range),
          ),
        );
      });
    }

    test('a valid range has no issue', () {
      const range = QuranRange(QuranVerseRef(1, 1), QuranVerseRef(7, 6));
      expect(quranRangeIssue(_indexes['main']!, range), isNull);
    });
  });

  group('QuranIndex.fromParts', () {
    for (final c in _cases('invalidIndexCases')) {
      test('rejects: ${c['description']}', () {
        expect(
          () => _indexFrom(c),
          throwsA(
            isA<QuranIndexFormatException>().having(
              (e) => e.issue.name,
              'issue',
              c['expectIssue'],
            ),
          ),
        );
      });
    }

    test('exposes the catalog shape', () {
      final index = _indexes['main']!;
      final parts = (_fixture['indexes'] as Map)['main'] as Map;
      final ayahCounts = (parts['ayahCounts'] as List).cast<int>();
      expect(index.surahCount, ayahCounts.length);
      expect(index.verseCount, ayahCounts.reduce((a, b) => a + b));
      expect(index.juzCount, (parts['juzStarts'] as List).length);
      expect([
        for (var s = 1; s <= index.surahCount; s++) index.ayahCount(s),
      ], ayahCounts);
      expect(() => index.ayahCount(0), throwsRangeError);
      expect(() => index.ayahCount(index.surahCount + 1), throwsRangeError);
    });

    test('is immutable and detached from its input lists', () {
      final ayahCounts = [2, 1];
      final juzStarts = [const QuranVerseRef(1, 1), const QuranVerseRef(2, 1)];
      final wordCounts = [1, 3, 2];
      final index = QuranIndex.fromParts(
        ayahCounts: ayahCounts,
        juzStarts: juzStarts,
        wordCounts: wordCounts,
      );
      final before = _at(index, const QuranVerseRef(1, 1));

      ayahCounts[0] = 9;
      juzStarts.add(const QuranVerseRef(1, 2));
      wordCounts[0] = 100;

      expect(index.ayahCount(1), 2);
      expect(index.juzStartGlobal, [1, 3]);
      expect(_at(index, const QuranVerseRef(1, 1)), before);
      expect(() => index.juzStartGlobal.add(5), throwsUnsupportedError);
      expect(() => index.juzStartGlobal[0] = 9, throwsUnsupportedError);
      expect(index.juzStartGlobal, [1, 3]);
    });
  });
}

List<int> _row(JourneyPosition p) => [p.juz, p.level, p.progressBp];
