import 'package:equatable/equatable.dart';

import 'mushaf_ayah.dart';

/// Parsed Quran corpus grouped for mushaf page navigation.
class QuranTextBundle extends Equatable {
  final List<MushafAyah> ayahs;

  /// Index 0 ⇒ mushaf page 1.
  final List<List<MushafAyah>> pagesByIndex;

  /// Surah number → first mushaf page.
  final Map<int, int> surahStartPage;

  /// Juz number → first mushaf page. Empty when the source lacks juz data.
  final Map<int, int> juzStartPage;

  const QuranTextBundle({
    required this.ayahs,
    required this.pagesByIndex,
    required this.surahStartPage,
    this.juzStartPage = const {},
  });

  int get pageCount => pagesByIndex.length;

  List<MushafAyah> ayahsOnPage(int pageNumber) {
    final index = pageNumber - 1;
    if (index < 0 || index >= pagesByIndex.length) return const [];
    return pagesByIndex[index];
  }

  int? pageForSurah(int surahNumber) => surahStartPage[surahNumber];

  int? pageForJuz(int juzNumber) => juzStartPage[juzNumber];

  @override
  List<Object?> get props => [
    ayahs,
    pagesByIndex,
    surahStartPage,
    juzStartPage,
  ];
}
