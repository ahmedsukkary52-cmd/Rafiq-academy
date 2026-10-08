import '../mushaf_page_range.dart';
import '../quran_juz_labels.dart';
import '../quran_surah_catalog.dart';
import 'quran_text_bundle.dart';

class MushafSurahEntry {
  final QuranSurahInfo info;
  final int startPage;

  const MushafSurahEntry({required this.info, required this.startPage});

  int get number => info.number;
}

class MushafJuzEntry {
  final int number;
  final int startPage;

  const MushafJuzEntry({required this.number, required this.startPage});

  String get label => QuranJuzLabels.nameOf(number);
}

/// Read-only surah/juz/page lookup derived once from the loaded Quran text.
///
/// Entries whose start page is out of range (or, for juz, not strictly
/// increasing) are dropped rather than guessed.
class MushafNavigationIndex {
  final List<MushafSurahEntry> surahs;
  final List<MushafJuzEntry> juzs;
  final Map<int, int> _surahByPage;
  final Map<int, int> _surahStart;
  final Map<int, int> _juzStart;

  const MushafNavigationIndex._({
    required this.surahs,
    required this.juzs,
    required Map<int, int> surahByPage,
    required Map<int, int> surahStart,
    required Map<int, int> juzStart,
  }) : _surahByPage = surahByPage,
       _surahStart = surahStart,
       _juzStart = juzStart;

  static const empty = MushafNavigationIndex._(
    surahs: [],
    juzs: [],
    surahByPage: {},
    surahStart: {},
    juzStart: {},
  );

  factory MushafNavigationIndex.fromBundle(QuranTextBundle bundle) {
    final surahs = <MushafSurahEntry>[];
    final surahStart = <int, int>{};
    for (final info in QuranSurahCatalog.all) {
      final page = bundle.surahStartPage[info.number];
      if (page == null || !MushafPageRange.isValidPage(page)) continue;
      surahs.add(MushafSurahEntry(info: info, startPage: page));
      surahStart[info.number] = page;
    }

    final juzs = <MushafJuzEntry>[];
    final juzStart = <int, int>{};
    var previous = 0;
    for (var n = 1; n <= QuranJuzLabels.juzCount; n++) {
      final page = bundle.juzStartPage[n];
      if (page == null || !MushafPageRange.isValidPage(page)) continue;
      if (page <= previous) continue;
      previous = page;
      juzs.add(MushafJuzEntry(number: n, startPage: page));
      juzStart[n] = page;
    }

    final surahByPage = <int, int>{
      for (final page in bundle.pagesByIndex)
        if (page.isNotEmpty) page.first.page: page.first.surahNumber,
    };

    return MushafNavigationIndex._(
      surahs: List.unmodifiable(surahs),
      juzs: List.unmodifiable(juzs),
      surahByPage: Map.unmodifiable(surahByPage),
      surahStart: Map.unmodifiable(surahStart),
      juzStart: Map.unmodifiable(juzStart),
    );
  }

  bool get hasJuzData => juzs.isNotEmpty;

  int? pageForSurah(int surahNumber) => _surahStart[surahNumber];

  int? pageForJuz(int juzNumber) => _juzStart[juzNumber];

  /// Surah of the first ayah on [page]; null when unknown.
  int? surahForPage(int page) {
    final surah = _surahByPage[page];
    return surah != null && QuranSurahCatalog.isValidSurah(surah)
        ? surah
        : null;
  }

  /// Juz whose start page is the latest at or before [page]; null when unknown.
  int? juzForPage(int page) {
    if (!MushafPageRange.isValidPage(page)) return null;
    int? current;
    for (final juz in juzs) {
      if (juz.startPage > page) break;
      current = juz.number;
    }
    return current;
  }
}
