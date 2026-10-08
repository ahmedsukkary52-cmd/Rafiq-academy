import 'dart:convert';

import 'package:rafiq_academy/features/mushaf/domain/quran_surah_catalog.dart';

/// (surah, ayahInSurah, page, juz) — real Madani-mushaf values as served by
/// alquran.cloud `quran-uthmani`, sampled at surah/juz boundaries.
const List<(int, int, int, int)> kBoundaryAyahs = [
  (1, 1, 1, 1),
  (1, 7, 1, 1),
  (2, 1, 2, 1),
  (2, 141, 21, 1),
  (2, 142, 22, 2),
  (2, 252, 41, 2),
  (2, 253, 42, 3),
  (3, 1, 50, 3),
  (77, 50, 581, 29),
  (78, 1, 582, 30),
  (113, 1, 604, 30),
  (114, 1, 604, 30),
  (114, 6, 604, 30),
];

int globalAyahNumber(int surah, int ayah) {
  var total = 0;
  for (var s = 1; s < surah; s++) {
    total += QuranSurahCatalog.of(s).ayahCount;
  }
  return total + ayah;
}

/// Builds a payload in the exact shape of the alquran.cloud response.
String buildQuranFixtureJson({
  List<(int, int, int, int)> ayahs = kBoundaryAyahs,
  bool includeJuz = true,
}) {
  final bySurah = <int, List<Map<String, dynamic>>>{};
  for (final (surah, ayah, page, juz) in ayahs) {
    bySurah.putIfAbsent(surah, () => []).add({
      'number': globalAyahNumber(surah, ayah),
      'text': 'آية $surah:$ayah',
      'numberInSurah': ayah,
      'page': page,
      if (includeJuz) 'juz': juz,
      'manzil': 1,
      'ruku': 1,
      'hizbQuarter': 1,
      'sajda': false,
    });
  }
  return json.encode({
    'code': 200,
    'status': 'OK',
    'data': {
      'surahs': [
        for (final entry in bySurah.entries)
          {
            'number': entry.key,
            'name': QuranSurahCatalog.of(entry.key).name,
            'revelationType': QuranSurahCatalog.of(entry.key).isMeccan
                ? 'Meccan'
                : 'Medinan',
            'ayahs': entry.value,
          },
      ],
    },
  });
}
