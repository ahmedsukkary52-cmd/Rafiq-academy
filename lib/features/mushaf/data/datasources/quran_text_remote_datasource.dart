import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exception.dart';
import '../../domain/entities/mushaf_ayah.dart';
import '../../domain/entities/quran_text_bundle.dart';

abstract class QuranTextLocalCache {
  Future<String?> readCachedJson();
  Future<void> writeCachedJson(String json);
}

@LazySingleton(as: QuranTextLocalCache)
class QuranTextSharedPreferencesCache implements QuranTextLocalCache {
  static const cacheKey = 'cached_entire_quran';

  @override
  Future<String?> readCachedJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(cacheKey);
  }

  @override
  Future<void> writeCachedJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, json);
  }
}

abstract class QuranTextRemoteDatasource {
  Future<QuranTextBundle> fetchQuranText();
}

@LazySingleton(as: QuranTextRemoteDatasource)
class QuranTextRemoteDatasourceImpl implements QuranTextRemoteDatasource {
  static const _endpoint = 'https://api.alquran.cloud/v1/quran/quran-uthmani';

  final QuranTextLocalCache cache;

  QuranTextRemoteDatasourceImpl(this.cache);

  @override
  Future<QuranTextBundle> fetchQuranText() async {
    final cached = await cache.readCachedJson();
    if (cached != null && cached.isNotEmpty) {
      try {
        return _parse(cached);
      } catch (_) {
        // Fall through to network if cache is corrupt.
      }
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_endpoint));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw const ServerException('تعذر تحميل نص المصحف');
      }
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      await cache.writeCachedJson(body);
      return _parse(body);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('تعذر تحميل نص المصحف: $e');
    }
  }

  QuranTextBundle _parse(String jsonBody) => parseBundle(jsonBody);

  /// Parses the alquran.cloud `quran-uthmani` payload. Surah and juz start
  /// pages are taken from the per-ayah `page`/`juz` fields of the source.
  static QuranTextBundle parseBundle(String jsonBody) {
    final decoded = json.decode(jsonBody) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahsList = data['surahs'] as List<dynamic>;

    final ayahs = <MushafAyah>[];
    final surahStartPage = <int, int>{};
    final juzStartPage = <int, int>{};

    for (final surahJson in surahsList) {
      final surahMap = surahJson as Map<String, dynamic>;
      final surahNum = surahMap['number'] as int;
      final ayahsList = surahMap['ayahs'] as List<dynamic>;

      for (var i = 0; i < ayahsList.length; i++) {
        final ayahJson = ayahsList[i] as Map<String, dynamic>;
        final ayah = MushafAyah(
          globalNumber: ayahJson['number'] as int,
          numberInSurah: ayahJson['numberInSurah'] as int,
          text: ayahJson['text'] as String,
          page: ayahJson['page'] as int,
          surahNumber: surahNum,
          juz: (ayahJson['juz'] as num?)?.toInt(),
        );
        ayahs.add(ayah);
        if (i == 0) {
          surahStartPage[surahNum] = ayah.page;
        }
        final juz = ayah.juz;
        if (juz != null && juz >= 1 && juz <= 30) {
          juzStartPage.putIfAbsent(juz, () => ayah.page);
        }
      }
    }

    final pageMap = <int, List<MushafAyah>>{};
    for (final ayah in ayahs) {
      pageMap.putIfAbsent(ayah.page, () => []).add(ayah);
    }
    final sortedPages = pageMap.keys.toList()..sort();
    final pagesByIndex = sortedPages.map((p) => pageMap[p]!).toList();

    return QuranTextBundle(
      ayahs: ayahs,
      pagesByIndex: pagesByIndex,
      surahStartPage: surahStartPage,
      juzStartPage: juzStartPage,
    );
  }
}
