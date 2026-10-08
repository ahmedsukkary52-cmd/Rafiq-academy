/// Mushaf page bounds (Uthmani Madinah mushaf pagination).
class MushafPageRange {
  const MushafPageRange._();

  static const int minPage = 1;
  static const int maxPage = 604;

  /// D23 first-open default.
  static const int alFatihahSurah = 1;
  static const int alFatihahAyah = 1;

  static bool isValidPage(int page) => page >= minPage && page <= maxPage;

  static int clampPage(int page) {
    if (page < minPage) return minPage;
    if (page > maxPage) return maxPage;
    return page;
  }
}
