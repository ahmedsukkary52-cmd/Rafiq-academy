import 'package:equatable/equatable.dart';

import '../mushaf_page_range.dart';

/// C15 / D23 reading position — independent of memorization progress (D11).
class MushafPosition extends Equatable {
  final int pageNumber;
  final int surahNumber;
  final int ayahNumber;

  const MushafPosition({
    required this.pageNumber,
    required this.surahNumber,
    required this.ayahNumber,
  });

  /// First-open / safe fallback — Al-Fatihah.
  static const MushafPosition alFatihah = MushafPosition(
    pageNumber: MushafPageRange.minPage,
    surahNumber: MushafPageRange.alFatihahSurah,
    ayahNumber: MushafPageRange.alFatihahAyah,
  );

  bool get isValid =>
      MushafPageRange.isValidPage(pageNumber) &&
      surahNumber >= 1 &&
      surahNumber <= 114 &&
      ayahNumber >= 1;

  MushafPosition copyWith({
    int? pageNumber,
    int? surahNumber,
    int? ayahNumber,
  }) {
    return MushafPosition(
      pageNumber: pageNumber ?? this.pageNumber,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
    );
  }

  @override
  List<Object?> get props => [pageNumber, surahNumber, ayahNumber];
}
