import 'package:equatable/equatable.dart';

/// Single ayah from Quran text provider (presentation-agnostic).
class MushafAyah extends Equatable {
  final int globalNumber;
  final int numberInSurah;
  final String text;
  final int page;
  final int surahNumber;

  /// Juz (1..30) from the text provider; null when the source omits it.
  final int? juz;

  const MushafAyah({
    required this.globalNumber,
    required this.numberInSurah,
    required this.text,
    required this.page,
    required this.surahNumber,
    this.juz,
  });

  @override
  List<Object?> get props => [
    globalNumber,
    numberInSurah,
    text,
    page,
    surahNumber,
    juz,
  ];
}
