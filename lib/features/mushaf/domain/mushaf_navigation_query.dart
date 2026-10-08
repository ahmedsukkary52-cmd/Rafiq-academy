import '../../../shared/domain/arabic_search_normalizer.dart';
import 'entities/mushaf_navigation_index.dart';
import 'mushaf_page_range.dart';

/// Parses user-typed page numbers (Latin, Arabic-Indic or Persian digits).
class MushafPageInput {
  const MushafPageInput._();

  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  static String toLatinDigits(String raw) {
    final out = StringBuffer();
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      final a = _arabicIndic.indexOf(ch);
      final p = _persian.indexOf(ch);
      if (a >= 0) {
        out.write(a);
      } else if (p >= 0) {
        out.write(p);
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }

  /// Returns a page in 1..604, or null for empty/non-numeric/out-of-range input.
  static int? parse(String raw) {
    final latin = toLatinDigits(raw.trim());
    if (latin.isEmpty || latin.length > 4) return null;
    final value = int.tryParse(latin);
    if (value == null || !MushafPageRange.isValidPage(value)) return null;
    return value;
  }
}

/// Lightweight surah filter over the 114 names (no Quran text is searched).
class MushafSurahSearch {
  const MushafSurahSearch._();

  static final RegExp _surahPrefix = RegExp(r'^سوره\s+');

  static String _normalize(String raw) =>
      ArabicSearchNormalizer.normalize(raw).replaceFirst(_surahPrefix, '');

  static List<MushafSurahEntry> filter(
    List<MushafSurahEntry> surahs,
    String query,
  ) {
    final q = _normalize(query);
    if (q.isEmpty) return surahs;

    final number = int.tryParse(MushafPageInput.toLatinDigits(q));
    if (number != null) {
      return [
        for (final s in surahs)
          if (s.number == number) s,
      ];
    }

    return [
      for (final s in surahs)
        if (_normalize(s.info.name).contains(q)) s,
    ];
  }
}
