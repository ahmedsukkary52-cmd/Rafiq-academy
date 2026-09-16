/// C13.2 / WA-14 — frozen Arabic search normalization (query side).
///
/// This is a byte-for-byte mirror of
/// `functions/src/search/arabicNormalization.ts`. The projection is written
/// with the TypeScript implementation, so any divergence here would silently
/// stop prefix queries from matching. The shared vectors in
/// [arabicNormalizationVectors] pin both sides.
///
/// `ؤ` (U+0624) and `ئ` (U+0626) are deliberately NOT folded — the frozen
/// contract keeps the existing project precedent, which unifies alef only.
class ArabicSearchNormalizer {
  const ArabicSearchNormalizer._();

  /// Bumped only when the steps below change; stored on every projection.
  static const int version = 1;

  /// Step 3 — tashkeel/harakat plus superscript alef.
  static final RegExp _tashkeel = RegExp(r'[\u064B-\u065F\u0670]');

  /// Step 4 — tatweel (kashida).
  static final RegExp _tatweel = RegExp(r'\u0640');

  /// Step 5 — أ إ آ ٱ → ا
  static final RegExp _alefVariants = RegExp(r'[\u0622\u0623\u0625\u0671]');

  /// Step 6 — ى → ي
  static final RegExp _alefMaqsura = RegExp(r'\u0649');

  /// Step 7 — ة → ه
  static final RegExp _tehMarbuta = RegExp(r'\u0629');

  /// Step 8 — collapse internal whitespace runs.
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// Frozen nine-step normalization.
  static String normalize(String? raw) {
    if (raw == null) return '';
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(_tashkeel, '')
        .replaceAll(_tatweel, '')
        .replaceAll(_alefVariants, '\u0627')
        .replaceAll(_alefMaqsura, '\u064A')
        .replaceAll(_tehMarbuta, '\u0647')
        .replaceAll(_whitespaceRun, ' ')
        .trim();
  }
}

/// Cross-language contract vectors, mirroring
/// `ARABIC_NORMALIZATION_VECTORS` in the TypeScript writer.
const List<({String label, String input, String expected})>
arabicNormalizationVectors = [
  (label: 'tashkeel', input: 'مُحَمَّدٌ', expected: 'محمد'),
  (label: 'superscript alef', input: 'رَحْمَٰن', expected: 'رحمن'),
  (label: 'alef hamza above', input: 'أحمد', expected: 'احمد'),
  (label: 'alef hamza below', input: 'إبراهيم', expected: 'ابراهيم'),
  (label: 'alef madda', input: 'آمنة', expected: 'امنه'),
  (label: 'alef wasla', input: 'ٱسماعيل', expected: 'اسماعيل'),
  (label: 'tatweel', input: 'مـــحـمد', expected: 'محمد'),
  (label: 'alef maqsura', input: 'يحيى', expected: 'يحيي'),
  (label: 'teh marbuta', input: 'فاطمة', expected: 'فاطمه'),
  (
    label: 'whitespace collapse',
    input: '  محمد\t\tعلي  ',
    expected: 'محمد علي',
  ),
  (label: 'latin lowercase', input: 'Ahmed ALI', expected: 'ahmed ali'),
  (label: 'waw hamza preserved', input: 'مؤمن', expected: 'مؤمن'),
  (label: 'yeh hamza preserved', input: 'رئيس', expected: 'رئيس'),
  (label: 'empty', input: '', expected: ''),
  (label: 'whitespace only', input: '   \t \n ', expected: ''),
  (
    label: 'combined',
    input: '  أحـمَد   بنُ  عَلِيّة ',
    expected: 'احمد بن عليه',
  ),
];
