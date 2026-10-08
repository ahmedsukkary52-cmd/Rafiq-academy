/// Arabic labels for the 30 ajzā'. Start pages come from Quran text data.
class QuranJuzLabels {
  const QuranJuzLabels._();

  static const int juzCount = 30;

  static bool isValidJuz(int number) => number >= 1 && number <= juzCount;

  static const List<String> _ordinals = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'الثالث عشر',
    'الرابع عشر',
    'الخامس عشر',
    'السادس عشر',
    'السابع عشر',
    'الثامن عشر',
    'التاسع عشر',
    'العشرون',
    'الحادي والعشرون',
    'الثاني والعشرون',
    'الثالث والعشرون',
    'الرابع والعشرون',
    'الخامس والعشرون',
    'السادس والعشرون',
    'السابع والعشرون',
    'الثامن والعشرون',
    'التاسع والعشرون',
    'الثلاثون',
  ];

  /// e.g. `الجزء الأول`. Out-of-range values return an empty string.
  static String nameOf(int number) =>
      isValidJuz(number) ? 'الجزء ${_ordinals[number - 1]}' : '';
}
