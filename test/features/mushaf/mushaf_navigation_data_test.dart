import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/mushaf/data/datasources/quran_text_remote_datasource.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_ayah.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_navigation_index.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/quran_text_bundle.dart';
import 'package:rafiq_academy/features/mushaf/domain/mushaf_navigation_query.dart';
import 'package:rafiq_academy/features/mushaf/domain/quran_juz_labels.dart';
import 'package:rafiq_academy/features/mushaf/domain/quran_surah_catalog.dart';

import 'support/quran_fixture.dart';

void main() {
  group('A. Surah catalog', () {
    test('has exactly 114 surahs numbered 1..114 in order', () {
      expect(QuranSurahCatalog.all, hasLength(114));
      for (var i = 0; i < 114; i++) {
        expect(QuranSurahCatalog.all[i].number, i + 1);
      }
    });

    test('Arabic names at anchors are correct', () {
      expect(QuranSurahCatalog.of(1).name, 'الفاتحة');
      expect(QuranSurahCatalog.of(2).name, 'البقرة');
      expect(QuranSurahCatalog.of(18).name, 'الكهف');
      expect(QuranSurahCatalog.of(36).name, 'يس');
      expect(QuranSurahCatalog.of(67).name, 'الملك');
      expect(QuranSurahCatalog.of(78).name, 'النبأ');
      expect(QuranSurahCatalog.of(114).name, 'الناس');
    });

    test('ayah counts total 6236 and 86 surahs are Meccan', () {
      final total = QuranSurahCatalog.all.fold<int>(
        0,
        (sum, s) => sum + s.ayahCount,
      );
      expect(total, 6236);
      expect(QuranSurahCatalog.all.where((s) => s.isMeccan), hasLength(86));
      expect(QuranSurahCatalog.of(1).revelationLabel, 'مكية');
      expect(QuranSurahCatalog.of(2).revelationLabel, 'مدنية');
    });

    test('names are unique and non-empty', () {
      final names = QuranSurahCatalog.all.map((s) => s.name).toSet();
      expect(names, hasLength(114));
      expect(names.any((n) => n.trim().isEmpty), isFalse);
    });

    test('out-of-range lookups fall back safely', () {
      expect(QuranSurahCatalog.isValidSurah(0), isFalse);
      expect(QuranSurahCatalog.isValidSurah(115), isFalse);
      expect(QuranSurahCatalog.of(0).number, 1);
      expect(QuranSurahCatalog.of(999).number, 1);
    });
  });

  group('Quran text parsing (authoritative page/juz fields)', () {
    final bundle = QuranTextRemoteDatasourceImpl.parseBundle(
      buildQuranFixtureJson(),
    );

    test('surah start pages come from the first ayah page', () {
      expect(bundle.surahStartPage[1], 1);
      expect(bundle.surahStartPage[2], 2);
      expect(bundle.surahStartPage[3], 50);
      expect(bundle.surahStartPage[78], 582);
      expect(bundle.surahStartPage[113], 604);
      expect(bundle.surahStartPage[114], 604);
    });

    test('juz start pages come from the first ayah of each juz', () {
      expect(bundle.juzStartPage[1], 1);
      expect(bundle.juzStartPage[2], 22);
      expect(bundle.juzStartPage[3], 42);
      expect(bundle.juzStartPage[29], 581);
      expect(bundle.juzStartPage[30], 582);
    });

    test('ayah juz field is parsed; Quran text is untouched', () {
      final first = bundle.ayahs.first;
      expect(first.juz, 1);
      expect(first.text, 'آية 1:1');
      expect(first.globalNumber, 1);
      final baqarah142 = bundle.ayahs.firstWhere(
        (a) => a.surahNumber == 2 && a.numberInSurah == 142,
      );
      expect(baqarah142.juz, 2);
      expect(baqarah142.globalNumber, 149);
    });

    test('payload without juz yields empty juz map (no guessing)', () {
      final noJuz = QuranTextRemoteDatasourceImpl.parseBundle(
        buildQuranFixtureJson(includeJuz: false),
      );
      expect(noJuz.juzStartPage, isEmpty);
      expect(noJuz.ayahs.first.juz, isNull);
      expect(noJuz.surahStartPage[114], 604);
    });
  });

  group('B/C. Navigation index', () {
    final nav = MushafNavigationIndex.fromBundle(
      QuranTextRemoteDatasourceImpl.parseBundle(buildQuranFixtureJson()),
    );

    test('surah navigation resolves start pages', () {
      expect(nav.pageForSurah(1), 1);
      expect(nav.pageForSurah(2), 2);
      expect(nav.pageForSurah(114), 604);
      expect(nav.pageForSurah(0), isNull);
      expect(nav.pageForSurah(115), isNull);
      expect(nav.surahs.first.info.name, 'الفاتحة');
      expect(nav.surahs.last.info.name, 'الناس');
    });

    test('juz 1, juz 30, middle and boundaries', () {
      expect(nav.pageForJuz(1), 1);
      expect(nav.pageForJuz(30), 582);
      expect(nav.pageForJuz(2), 22);
      expect(nav.pageForJuz(3), 42);
      expect(nav.pageForJuz(0), isNull);
      expect(nav.pageForJuz(31), isNull);
      expect(nav.pageForJuz(-1), isNull);
    });

    test('missing juz metadata is reported, not invented', () {
      expect(nav.pageForJuz(15), isNull);
      expect(nav.juzs.map((j) => j.number), [1, 2, 3, 29, 30]);
      final empty = MushafNavigationIndex.fromBundle(
        QuranTextRemoteDatasourceImpl.parseBundle(
          buildQuranFixtureJson(includeJuz: false),
        ),
      );
      expect(empty.hasJuzData, isFalse);
      expect(empty.pageForJuz(1), isNull);
    });

    test('juzForPage uses the latest juz start at or before the page', () {
      expect(nav.juzForPage(1), 1);
      expect(nav.juzForPage(21), 1);
      expect(nav.juzForPage(22), 2);
      expect(nav.juzForPage(41), 2);
      expect(nav.juzForPage(42), 3);
      expect(nav.juzForPage(604), 30);
      expect(nav.juzForPage(0), isNull);
      expect(nav.juzForPage(605), isNull);
    });

    test('surahForPage uses the first ayah on the page', () {
      expect(nav.surahForPage(1), 1);
      expect(nav.surahForPage(22), 2);
      expect(nav.surahForPage(582), 78);
      expect(nav.surahForPage(604), 113);
      expect(nav.surahForPage(999), isNull);
    });

    test('out-of-range or non-increasing start pages are dropped', () {
      const a = MushafAyah(
        globalNumber: 1,
        numberInSurah: 1,
        text: 'x',
        page: 1,
        surahNumber: 1,
      );
      final corrupt = MushafNavigationIndex.fromBundle(
        const QuranTextBundle(
          ayahs: [a],
          pagesByIndex: [
            [a],
          ],
          surahStartPage: {1: 1, 2: 0, 3: 700},
          juzStartPage: {1: 1, 2: 50, 3: 40, 4: 999},
        ),
      );
      expect(corrupt.surahs.map((s) => s.number), [1]);
      expect(corrupt.juzs.map((j) => j.number), [1, 2]);
      expect(corrupt.pageForJuz(3), isNull);
      expect(corrupt.pageForJuz(4), isNull);
    });

    test('juz labels are Arabic for all 30', () {
      expect(QuranJuzLabels.nameOf(1), 'الجزء الأول');
      expect(QuranJuzLabels.nameOf(15), 'الجزء الخامس عشر');
      expect(QuranJuzLabels.nameOf(30), 'الجزء الثلاثون');
      expect(QuranJuzLabels.nameOf(0), '');
      expect(QuranJuzLabels.nameOf(31), '');
      final labels = List.generate(30, (i) => QuranJuzLabels.nameOf(i + 1));
      expect(labels.toSet(), hasLength(30));
    });
  });

  group('B. Page input', () {
    test('accepts bounds and Arabic-Indic / Persian digits', () {
      expect(MushafPageInput.parse('1'), 1);
      expect(MushafPageInput.parse('604'), 604);
      expect(MushafPageInput.parse(' 42 '), 42);
      expect(MushafPageInput.parse('٦٠٤'), 604);
      expect(MushafPageInput.parse('١'), 1);
      expect(MushafPageInput.parse('۱۲'), 12);
    });

    test('rejects invalid input without throwing', () {
      for (final raw in ['', '  ', '0', '605', '-3', 'abc', '1.5', '99999']) {
        expect(MushafPageInput.parse(raw), isNull, reason: raw);
      }
    });
  });

  group('Surah search', () {
    final nav = MushafNavigationIndex.fromBundle(
      QuranTextRemoteDatasourceImpl.parseBundle(buildQuranFixtureJson()),
    );

    List<int> search(String q) =>
        MushafSurahSearch.filter(nav.surahs, q).map((s) => s.number).toList();

    test('empty query returns all', () {
      expect(search(''), nav.surahs.map((s) => s.number).toList());
    });

    test('matches normalized Arabic names', () {
      expect(search('البقرة'), [2]);
      expect(search('بقره'), [2]);
      expect(search('سورة الناس'), [114]);
      expect(search('آل عمران'), [3]);
      expect(search('ال عمران'), [3]);
      expect(search('عمران'), [3]);
    });

    test('matches surah numbers in either digit system', () {
      expect(search('114'), [114]);
      expect(search('١١٤'), [114]);
      expect(search('55'), isEmpty);
    });

    test('no match returns empty', () {
      expect(search('zzz'), isEmpty);
    });
  });
}
