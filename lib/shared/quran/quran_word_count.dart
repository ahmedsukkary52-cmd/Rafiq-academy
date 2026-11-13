/// Word-counting rule `words-kfgqpc-hafs-v2.0-v2`, algorithmic part
/// (plan §5.8 condition 2, items 2–4; `tool/quran_index/COUNTING_RULE.md`).
///
/// Phase 1A: the rule is fixed and tested on synthetic, non-Quranic text
/// only. Applying it to the licensed source is Phase 1B. Server mirror:
/// `functions/src/quran/quranWordCount.ts`.
///
/// Matching is by explicit code point ranges on purpose: `\s`, `\p{L}` and
/// other engine-defined classes may differ between Dart and JavaScript, and
/// `\p{L}` would count the U+FC00… verse-end symbols as words.
library;

/// Version id of this rule; any change to it needs a new id. `-v2` replaced
/// `-v1`, whose first range also covered U+0640 TATWEEL.
const String kQuranWordCountRuleId = 'words-kfgqpc-hafs-v2.0-v2';

/// The only separators: SPACE and NO-BREAK SPACE. Runs of them, and leading
/// or trailing ones, produce no words.
const int kSpace = 0x0020;
const int kNoBreakSpace = 0x00A0;

/// A segment is a word when it holds at least one code point in one of these
/// inclusive ranges. U+0640 TATWEEL is not a letter: a segment of tatweel
/// alone is not a word, and tatweel next to a letter adds nothing.
const List<(int, int)> kWordLetterRanges = [
  (0x0621, 0x063F),
  (0x0641, 0x064A),
  (0x0671, 0x06D3),
];

/// Code points of Unicode general categories Zs, Zl, Zp, Cc and Cf
/// (Unicode 15.1.0), except the two separators. Any of them fails the count.
const List<(int, int)> kDisallowedCodePointRanges = [
  (0x0000, 0x001F),
  (0x007F, 0x009F),
  (0x00AD, 0x00AD),
  (0x0600, 0x0605),
  (0x061C, 0x061C),
  (0x06DD, 0x06DD),
  (0x070F, 0x070F),
  (0x0890, 0x0891),
  (0x08E2, 0x08E2),
  (0x1680, 0x1680),
  (0x180E, 0x180E),
  (0x2000, 0x200F),
  (0x2028, 0x202F),
  (0x205F, 0x2064),
  (0x2066, 0x206F),
  (0x3000, 0x3000),
  (0xFEFF, 0xFEFF),
  (0xFFF9, 0xFFFB),
  (0x110BD, 0x110BD),
  (0x110CD, 0x110CD),
  (0x13430, 0x1343F),
  (0x1BCA0, 0x1BCA3),
  (0x1D173, 0x1D17A),
  (0xE0001, 0xE0001),
  (0xE0020, 0xE007F),
];

/// The text holds a code point the rule does not allow (a separator other
/// than [kSpace] / [kNoBreakSpace], or a control or format character).
class DisallowedCharacterException implements Exception {
  const DisallowedCharacterException(this.codePoint, this.offset);

  final int codePoint;

  /// UTF-16 code unit offset of [codePoint] in the text.
  final int offset;

  @override
  String toString() =>
      'DisallowedCharacterException: '
      'U+${codePoint.toRadixString(16).toUpperCase().padLeft(4, '0')} '
      'at offset $offset';
}

bool _inRanges(List<(int, int)> ranges, int codePoint) {
  for (final (first, last) in ranges) {
    if (codePoint >= first && codePoint <= last) return true;
  }
  return false;
}

/// Words in [text] under [kQuranWordCountRuleId]. The text is used as is
/// (no normalization): it is split on [kSpace] / [kNoBreakSpace] only, and a
/// segment counts once when it holds a letter from [kWordLetterRanges].
///
/// Throws [DisallowedCharacterException] at the first disallowed code point.
int countQuranWords(String text) {
  var words = 0;
  var segmentHasLetter = false;
  var offset = 0;
  for (final codePoint in text.runes) {
    if (codePoint == kSpace || codePoint == kNoBreakSpace) {
      if (segmentHasLetter) words++;
      segmentHasLetter = false;
    } else if (_inRanges(kDisallowedCodePointRanges, codePoint)) {
      throw DisallowedCharacterException(codePoint, offset);
    } else if (_inRanges(kWordLetterRanges, codePoint)) {
      segmentHasLetter = true;
    }
    offset += codePoint > 0xFFFF ? 2 : 1;
  }
  return segmentHasLetter ? words + 1 : words;
}
