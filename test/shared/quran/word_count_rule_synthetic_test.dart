// Phase 1A: word-counting rule `words-kfgqpc-hafs-v2.0-v2` on synthetic,
// meaningless letter sequences only (plan §5.9-1, coverage item 6). The same
// fixture drives `functions/test/quran_word_count_synthetic.test.mjs`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/quran/quran_word_count.dart';

const _fixturePath = 'test/fixtures/quran_journey_synthetic_v1.json';

final Map<String, dynamic> _fixture =
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

final Map<String, dynamic> _spec =
    _fixture['wordCount'] as Map<String, dynamic>;

List<List<int>> _ranges(List<(int, int)> ranges) => [
  for (final (first, last) in ranges) [first, last],
];

final RegExp _separators = RegExp('[\u0020\u00A0]+');
final RegExp _anyUnicodeLetter = RegExp(r'\p{L}', unicode: true);

void main() {
  test('fixture is marked synthetic and non-Quranic', () {
    expect(_fixture['synthetic'], isTrue);
    expect(_fixture['notice'], contains('Synthetic data, not Quranic data'));
  });

  group('rule tables match the shared fixture', () {
    test('rule id and separators', () {
      expect(kQuranWordCountRuleId, _spec['ruleId']);
      expect([kSpace, kNoBreakSpace], _spec['separators']);
    });

    test('letter ranges', () {
      expect(_ranges(kWordLetterRanges), _spec['letterRanges']);
    });

    test('rule -v2: U+0640 TATWEEL is not a letter, its neighbours are', () {
      expect(kQuranWordCountRuleId, 'words-kfgqpc-hafs-v2.0-v2');
      bool isLetter(int cp) =>
          kWordLetterRanges.any((r) => r.$1 <= cp && cp <= r.$2);
      expect(isLetter(0x0640), isFalse);
      expect(isLetter(0x063F), isTrue);
      expect(isLetter(0x0641), isTrue);
    });

    test('disallowed ranges (Zs, Zl, Zp, Cc, Cf minus the separators)', () {
      expect(_spec['unicodeVersion'], '15.1.0');
      expect(_ranges(kDisallowedCodePointRanges), _spec['disallowedRanges']);
    });
  });

  group('countQuranWords', () {
    for (final c in (_spec['cases'] as List).cast<Map<String, dynamic>>()) {
      final text = c['text'] as String;
      final error = c['expectError'] as Map<String, dynamic>?;
      test(c['description'], () {
        if (error == null) {
          expect(countQuranWords(text), c['expectWords']);
        } else {
          expect(
            () => countQuranWords(text),
            throwsA(
              isA<DisallowedCharacterException>()
                  .having((e) => e.codePoint, 'codePoint', error['codePoint'])
                  .having((e) => e.offset, 'offset', error['offset']),
            ),
          );
        }
      });

      final naive = c['naivePLetterSegments'] as int?;
      if (naive != null) {
        test('${c['description']}: a \\p{L} match would miscount', () {
          final segments = text
              .split(_separators)
              .where((s) => s.isNotEmpty && _anyUnicodeLetter.hasMatch(s))
              .length;
          expect(segments, naive);
          expect(countQuranWords(text), isNot(naive));
        });
      }
    }

    test(
      'fails on the first and last code point of every disallowed range',
      () {
        for (final (first, last) in kDisallowedCodePointRanges) {
          for (final codePoint in {first, last}) {
            final text = 'ثقص${String.fromCharCode(codePoint)}';
            expect(
              () => countQuranWords(text),
              throwsA(
                isA<DisallowedCharacterException>()
                    .having((e) => e.codePoint, 'codePoint', codePoint)
                    .having((e) => e.offset, 'offset', 3),
              ),
              reason: codePoint.toRadixString(16),
            );
          }
        }
      },
    );
  });
}
