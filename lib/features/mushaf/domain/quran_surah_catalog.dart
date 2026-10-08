/// Static surah identity (Arabic name, revelation, ayah count).
///
/// Start pages are NOT stored here — they come from the loaded Quran text
/// (authoritative `page` field per ayah) via `MushafNavigationIndex`.
class QuranSurahInfo {
  final int number;
  final String name;
  final bool isMeccan;
  final int ayahCount;

  const QuranSurahInfo({
    required this.number,
    required this.name,
    required this.isMeccan,
    required this.ayahCount,
  });

  String get revelationLabel => isMeccan ? 'مكية' : 'مدنية';
}

class QuranSurahCatalog {
  const QuranSurahCatalog._();

  static const int surahCount = 114;

  static bool isValidSurah(int number) => number >= 1 && number <= surahCount;

  /// Returns the surah for [number], or Al-Fatihah when out of range.
  static QuranSurahInfo of(int number) =>
      isValidSurah(number) ? all[number - 1] : all.first;

  static const List<QuranSurahInfo> all = [
    QuranSurahInfo(number: 1, name: 'الفاتحة', isMeccan: true, ayahCount: 7),
    QuranSurahInfo(number: 2, name: 'البقرة', isMeccan: false, ayahCount: 286),
    QuranSurahInfo(
      number: 3,
      name: 'آل عمران',
      isMeccan: false,
      ayahCount: 200,
    ),
    QuranSurahInfo(number: 4, name: 'النساء', isMeccan: false, ayahCount: 176),
    QuranSurahInfo(number: 5, name: 'المائدة', isMeccan: false, ayahCount: 120),
    QuranSurahInfo(number: 6, name: 'الأنعام', isMeccan: true, ayahCount: 165),
    QuranSurahInfo(number: 7, name: 'الأعراف', isMeccan: true, ayahCount: 206),
    QuranSurahInfo(number: 8, name: 'الأنفال', isMeccan: false, ayahCount: 75),
    QuranSurahInfo(number: 9, name: 'التوبة', isMeccan: false, ayahCount: 129),
    QuranSurahInfo(number: 10, name: 'يونس', isMeccan: true, ayahCount: 109),
    QuranSurahInfo(number: 11, name: 'هود', isMeccan: true, ayahCount: 123),
    QuranSurahInfo(number: 12, name: 'يوسف', isMeccan: true, ayahCount: 111),
    QuranSurahInfo(number: 13, name: 'الرعد', isMeccan: false, ayahCount: 43),
    QuranSurahInfo(number: 14, name: 'إبراهيم', isMeccan: true, ayahCount: 52),
    QuranSurahInfo(number: 15, name: 'الحجر', isMeccan: true, ayahCount: 99),
    QuranSurahInfo(number: 16, name: 'النحل', isMeccan: true, ayahCount: 128),
    QuranSurahInfo(number: 17, name: 'الإسراء', isMeccan: true, ayahCount: 111),
    QuranSurahInfo(number: 18, name: 'الكهف', isMeccan: true, ayahCount: 110),
    QuranSurahInfo(number: 19, name: 'مريم', isMeccan: true, ayahCount: 98),
    QuranSurahInfo(number: 20, name: 'طه', isMeccan: true, ayahCount: 135),
    QuranSurahInfo(
      number: 21,
      name: 'الأنبياء',
      isMeccan: true,
      ayahCount: 112,
    ),
    QuranSurahInfo(number: 22, name: 'الحج', isMeccan: false, ayahCount: 78),
    QuranSurahInfo(
      number: 23,
      name: 'المؤمنون',
      isMeccan: true,
      ayahCount: 118,
    ),
    QuranSurahInfo(number: 24, name: 'النور', isMeccan: false, ayahCount: 64),
    QuranSurahInfo(number: 25, name: 'الفرقان', isMeccan: true, ayahCount: 77),
    QuranSurahInfo(number: 26, name: 'الشعراء', isMeccan: true, ayahCount: 227),
    QuranSurahInfo(number: 27, name: 'النمل', isMeccan: true, ayahCount: 93),
    QuranSurahInfo(number: 28, name: 'القصص', isMeccan: true, ayahCount: 88),
    QuranSurahInfo(number: 29, name: 'العنكبوت', isMeccan: true, ayahCount: 69),
    QuranSurahInfo(number: 30, name: 'الروم', isMeccan: true, ayahCount: 60),
    QuranSurahInfo(number: 31, name: 'لقمان', isMeccan: true, ayahCount: 34),
    QuranSurahInfo(number: 32, name: 'السجدة', isMeccan: true, ayahCount: 30),
    QuranSurahInfo(number: 33, name: 'الأحزاب', isMeccan: false, ayahCount: 73),
    QuranSurahInfo(number: 34, name: 'سبأ', isMeccan: true, ayahCount: 54),
    QuranSurahInfo(number: 35, name: 'فاطر', isMeccan: true, ayahCount: 45),
    QuranSurahInfo(number: 36, name: 'يس', isMeccan: true, ayahCount: 83),
    QuranSurahInfo(number: 37, name: 'الصافات', isMeccan: true, ayahCount: 182),
    QuranSurahInfo(number: 38, name: 'ص', isMeccan: true, ayahCount: 88),
    QuranSurahInfo(number: 39, name: 'الزمر', isMeccan: true, ayahCount: 75),
    QuranSurahInfo(number: 40, name: 'غافر', isMeccan: true, ayahCount: 85),
    QuranSurahInfo(number: 41, name: 'فصلت', isMeccan: true, ayahCount: 54),
    QuranSurahInfo(number: 42, name: 'الشورى', isMeccan: true, ayahCount: 53),
    QuranSurahInfo(number: 43, name: 'الزخرف', isMeccan: true, ayahCount: 89),
    QuranSurahInfo(number: 44, name: 'الدخان', isMeccan: true, ayahCount: 59),
    QuranSurahInfo(number: 45, name: 'الجاثية', isMeccan: true, ayahCount: 37),
    QuranSurahInfo(number: 46, name: 'الأحقاف', isMeccan: true, ayahCount: 35),
    QuranSurahInfo(number: 47, name: 'محمد', isMeccan: false, ayahCount: 38),
    QuranSurahInfo(number: 48, name: 'الفتح', isMeccan: false, ayahCount: 29),
    QuranSurahInfo(number: 49, name: 'الحجرات', isMeccan: false, ayahCount: 18),
    QuranSurahInfo(number: 50, name: 'ق', isMeccan: true, ayahCount: 45),
    QuranSurahInfo(number: 51, name: 'الذاريات', isMeccan: true, ayahCount: 60),
    QuranSurahInfo(number: 52, name: 'الطور', isMeccan: true, ayahCount: 49),
    QuranSurahInfo(number: 53, name: 'النجم', isMeccan: true, ayahCount: 62),
    QuranSurahInfo(number: 54, name: 'القمر', isMeccan: true, ayahCount: 55),
    QuranSurahInfo(number: 55, name: 'الرحمن', isMeccan: false, ayahCount: 78),
    QuranSurahInfo(number: 56, name: 'الواقعة', isMeccan: true, ayahCount: 96),
    QuranSurahInfo(number: 57, name: 'الحديد', isMeccan: false, ayahCount: 29),
    QuranSurahInfo(
      number: 58,
      name: 'المجادلة',
      isMeccan: false,
      ayahCount: 22,
    ),
    QuranSurahInfo(number: 59, name: 'الحشر', isMeccan: false, ayahCount: 24),
    QuranSurahInfo(
      number: 60,
      name: 'الممتحنة',
      isMeccan: false,
      ayahCount: 13,
    ),
    QuranSurahInfo(number: 61, name: 'الصف', isMeccan: false, ayahCount: 14),
    QuranSurahInfo(number: 62, name: 'الجمعة', isMeccan: false, ayahCount: 11),
    QuranSurahInfo(
      number: 63,
      name: 'المنافقون',
      isMeccan: false,
      ayahCount: 11,
    ),
    QuranSurahInfo(number: 64, name: 'التغابن', isMeccan: false, ayahCount: 18),
    QuranSurahInfo(number: 65, name: 'الطلاق', isMeccan: false, ayahCount: 12),
    QuranSurahInfo(number: 66, name: 'التحريم', isMeccan: false, ayahCount: 12),
    QuranSurahInfo(number: 67, name: 'الملك', isMeccan: true, ayahCount: 30),
    QuranSurahInfo(number: 68, name: 'القلم', isMeccan: true, ayahCount: 52),
    QuranSurahInfo(number: 69, name: 'الحاقة', isMeccan: true, ayahCount: 52),
    QuranSurahInfo(number: 70, name: 'المعارج', isMeccan: true, ayahCount: 44),
    QuranSurahInfo(number: 71, name: 'نوح', isMeccan: true, ayahCount: 28),
    QuranSurahInfo(number: 72, name: 'الجن', isMeccan: true, ayahCount: 28),
    QuranSurahInfo(number: 73, name: 'المزمل', isMeccan: true, ayahCount: 20),
    QuranSurahInfo(number: 74, name: 'المدثر', isMeccan: true, ayahCount: 56),
    QuranSurahInfo(number: 75, name: 'القيامة', isMeccan: true, ayahCount: 40),
    QuranSurahInfo(number: 76, name: 'الإنسان', isMeccan: false, ayahCount: 31),
    QuranSurahInfo(number: 77, name: 'المرسلات', isMeccan: true, ayahCount: 50),
    QuranSurahInfo(number: 78, name: 'النبأ', isMeccan: true, ayahCount: 40),
    QuranSurahInfo(number: 79, name: 'النازعات', isMeccan: true, ayahCount: 46),
    QuranSurahInfo(number: 80, name: 'عبس', isMeccan: true, ayahCount: 42),
    QuranSurahInfo(number: 81, name: 'التكوير', isMeccan: true, ayahCount: 29),
    QuranSurahInfo(number: 82, name: 'الانفطار', isMeccan: true, ayahCount: 19),
    QuranSurahInfo(number: 83, name: 'المطففين', isMeccan: true, ayahCount: 36),
    QuranSurahInfo(number: 84, name: 'الانشقاق', isMeccan: true, ayahCount: 25),
    QuranSurahInfo(number: 85, name: 'البروج', isMeccan: true, ayahCount: 22),
    QuranSurahInfo(number: 86, name: 'الطارق', isMeccan: true, ayahCount: 17),
    QuranSurahInfo(number: 87, name: 'الأعلى', isMeccan: true, ayahCount: 19),
    QuranSurahInfo(number: 88, name: 'الغاشية', isMeccan: true, ayahCount: 26),
    QuranSurahInfo(number: 89, name: 'الفجر', isMeccan: true, ayahCount: 30),
    QuranSurahInfo(number: 90, name: 'البلد', isMeccan: true, ayahCount: 20),
    QuranSurahInfo(number: 91, name: 'الشمس', isMeccan: true, ayahCount: 15),
    QuranSurahInfo(number: 92, name: 'الليل', isMeccan: true, ayahCount: 21),
    QuranSurahInfo(number: 93, name: 'الضحى', isMeccan: true, ayahCount: 11),
    QuranSurahInfo(number: 94, name: 'الشرح', isMeccan: true, ayahCount: 8),
    QuranSurahInfo(number: 95, name: 'التين', isMeccan: true, ayahCount: 8),
    QuranSurahInfo(number: 96, name: 'العلق', isMeccan: true, ayahCount: 19),
    QuranSurahInfo(number: 97, name: 'القدر', isMeccan: true, ayahCount: 5),
    QuranSurahInfo(number: 98, name: 'البينة', isMeccan: false, ayahCount: 8),
    QuranSurahInfo(number: 99, name: 'الزلزلة', isMeccan: false, ayahCount: 8),
    QuranSurahInfo(
      number: 100,
      name: 'العاديات',
      isMeccan: true,
      ayahCount: 11,
    ),
    QuranSurahInfo(number: 101, name: 'القارعة', isMeccan: true, ayahCount: 11),
    QuranSurahInfo(number: 102, name: 'التكاثر', isMeccan: true, ayahCount: 8),
    QuranSurahInfo(number: 103, name: 'العصر', isMeccan: true, ayahCount: 3),
    QuranSurahInfo(number: 104, name: 'الهمزة', isMeccan: true, ayahCount: 9),
    QuranSurahInfo(number: 105, name: 'الفيل', isMeccan: true, ayahCount: 5),
    QuranSurahInfo(number: 106, name: 'قريش', isMeccan: true, ayahCount: 4),
    QuranSurahInfo(number: 107, name: 'الماعون', isMeccan: true, ayahCount: 7),
    QuranSurahInfo(number: 108, name: 'الكوثر', isMeccan: true, ayahCount: 3),
    QuranSurahInfo(number: 109, name: 'الكافرون', isMeccan: true, ayahCount: 6),
    QuranSurahInfo(number: 110, name: 'النصر', isMeccan: false, ayahCount: 3),
    QuranSurahInfo(number: 111, name: 'المسد', isMeccan: true, ayahCount: 5),
    QuranSurahInfo(number: 112, name: 'الإخلاص', isMeccan: true, ayahCount: 4),
    QuranSurahInfo(number: 113, name: 'الفلق', isMeccan: true, ayahCount: 5),
    QuranSurahInfo(number: 114, name: 'الناس', isMeccan: true, ayahCount: 6),
  ];
}
