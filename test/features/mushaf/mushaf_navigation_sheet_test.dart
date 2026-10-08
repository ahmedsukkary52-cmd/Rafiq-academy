import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/mushaf/data/datasources/quran_text_remote_datasource.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_navigation_index.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_position.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_navigation_sheet.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_tokens.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_top_chrome.dart';

import 'support/quran_fixture.dart';

final _nav = MushafNavigationIndex.fromBundle(
  QuranTextRemoteDatasourceImpl.parseBundle(buildQuranFixtureJson()),
);

const _baqarah = MushafPosition(
  pageNumber: 22,
  surahNumber: 2,
  ayahNumber: 142,
);

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<List<MushafNavigationTarget>> _pumpSheet(
  WidgetTester tester, {
  MushafReaderTokens tokens = MushafReaderTokens.paper,
  MushafNavigationIndex? navigation,
  MushafPosition current = MushafPosition.alFatihah,
  MushafPosition? lastRead,
}) async {
  final selected = <MushafNavigationTarget>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MushafNavigationSheet(
            tokens: tokens,
            navigation: navigation ?? _nav,
            current: current,
            lastRead: lastRead,
            onSelected: selected.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return selected;
}

void main() {
  group('E. Navigation sheet content', () {
    testWidgets('shows Arabic sections and no placeholder copy', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      await _pumpSheet(tester);

      expect(find.text('التنقّل في المصحف'), findsOneWidget);
      expect(find.text('آخر موضع قراءة'), findsOneWidget);
      expect(find.text('الانتقال إلى صفحة'), findsOneWidget);
      expect(find.text('السور'), findsOneWidget);
      expect(find.text('الأجزاء'), findsOneWidget);
      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.text('البقرة'), findsOneWidget);
      expect(find.textContaining('Coming Soon'), findsNothing);
      expect(find.textContaining('قريباً'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('first open shows the start of the mushaf as last read', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      await _pumpSheet(tester);
      expect(find.text('بداية المصحف · سورة الفاتحة'), findsOneWidget);
      expect(find.text('أنت هنا'), findsOneWidget);
    });

    testWidgets('selecting a surah reports that surah', (tester) async {
      _useSize(tester, const Size(390, 900));
      final selected = await _pumpSheet(tester);
      await tester.tap(find.byKey(const ValueKey('mushaf-surah-2')));
      expect(selected.single, isA<MushafNavigateToSurah>());
      expect((selected.single as MushafNavigateToSurah).surahNumber, 2);
    });

    testWidgets('juz tab lists Arabic juz labels and reports selection', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      final selected = await _pumpSheet(tester, current: _baqarah);
      await tester.tap(find.text('الأجزاء'));
      await tester.pumpAndSettle();

      expect(find.text('الجزء الأول'), findsOneWidget);
      expect(find.text('الجزء الثلاثون'), findsOneWidget);
      expect(find.text('يبدأ في سورة النبأ'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mushaf-juz-30')));
      expect((selected.single as MushafNavigateToJuz).juzNumber, 30);
    });

    testWidgets('page jump rejects out-of-range input and accepts valid', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      final selected = await _pumpSheet(tester);
      final input = find.byKey(const ValueKey('mushaf-page-jump-input'));
      final go = find.byKey(const ValueKey('mushaf-page-jump-go'));

      await tester.enterText(input, '٦٠٥');
      await tester.tap(go);
      await tester.pump();
      expect(find.text('أدخل رقم صفحة من ١ إلى ٦٠٤'), findsOneWidget);
      expect(selected, isEmpty);

      await tester.enterText(input, 'abc');
      await tester.tap(go);
      await tester.pump();
      expect(selected, isEmpty);

      await tester.enterText(input, '٣٠');
      await tester.tap(go);
      await tester.pump();
      expect((selected.single as MushafNavigateToPage).pageNumber, 30);
    });

    testWidgets('surah search filters and shows an Arabic empty state', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      await _pumpSheet(tester);
      final search = find.byKey(const ValueKey('mushaf-surah-search'));

      await tester.enterText(search, 'بقره');
      await tester.pump();
      expect(find.byKey(const ValueKey('mushaf-surah-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('mushaf-surah-1')), findsNothing);

      await tester.enterText(search, 'zzz');
      await tester.pump();
      expect(find.text('لا توجد سورة بهذا الاسم'), findsOneWidget);
    });

    testWidgets('last-read row reports resume with saved position', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      final selected = await _pumpSheet(tester, lastRead: _baqarah);
      expect(find.text('سورة البقرة · الآية ١٤٢'), findsOneWidget);
      expect(find.text('صفحة ٢٢'), findsOneWidget);
      await tester.tap(find.text('آخر موضع قراءة'));
      expect(selected.single, isA<MushafNavigateToLastRead>());
    });

    testWidgets('missing juz data shows a calm message instead of guesses', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      final noJuz = MushafNavigationIndex.fromBundle(
        QuranTextRemoteDatasourceImpl.parseBundle(
          buildQuranFixtureJson(includeJuz: false),
        ),
      );
      await _pumpSheet(tester, navigation: noJuz);
      await tester.tap(find.text('الأجزاء'));
      await tester.pumpAndSettle();
      expect(find.text('بيانات الأجزاء غير متاحة حالياً'), findsOneWidget);
    });

    testWidgets('night tokens and narrow / wide widths render cleanly', (
      tester,
    ) async {
      for (final size in const [Size(320, 640), Size(1024, 768)]) {
        _useSize(tester, size);
        await _pumpSheet(tester, tokens: MushafReaderTokens.night);
        expect(tester.takeException(), isNull, reason: '$size');
        final sheet = tester.getSize(find.byType(MushafNavigationSheet));
        expect(sheet.width <= size.width, isTrue);
      }
    });

    testWidgets('is right-to-left', (tester) async {
      _useSize(tester, const Size(390, 900));
      await _pumpSheet(tester);
      final dir = Directionality.of(
        tester.element(find.text('التنقّل في المصحف')),
      );
      expect(dir, TextDirection.rtl);
    });
  });

  group('E. Opening and closing', () {
    testWidgets('sheet opens, closes on selection and returns the target', (
      tester,
    ) async {
      _useSize(tester, const Size(390, 900));
      MushafNavigationTarget? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showMushafNavigationSheet(
                      context: context,
                      tokens: MushafReaderTokens.paper,
                      navigation: _nav,
                      current: MushafPosition.alFatihah,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafNavigationSheet), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mushaf-surah-114')));
      await tester.pumpAndSettle();
      expect(find.byType(MushafNavigationSheet), findsNothing);
      expect((result! as MushafNavigateToSurah).surahNumber, 114);
    });

    testWidgets('dismissing returns null', (tester) async {
      _useSize(tester, const Size(390, 900));
      var closed = false;
      MushafNavigationTarget? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: () async {
                    result = await showMushafNavigationSheet(
                      context: context,
                      tokens: MushafReaderTokens.paper,
                      navigation: _nav,
                      current: MushafPosition.alFatihah,
                    );
                    closed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });
  });

  group('E. Chrome entry points', () {
    Future<List<String>> pumpChrome(WidgetTester tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: MushafReaderTopChrome(
                tokens: MushafReaderTokens.paper,
                surahName: 'البقرة',
                pageNumber: 22,
                visible: true,
                onToggleNight: () {},
                onOpenNavigation: () => calls.add('nav'),
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      return calls;
    }

    testWidgets('navigation button opens navigation', (tester) async {
      final calls = await pumpChrome(tester);
      await tester.tap(find.byTooltip('التنقّل'));
      expect(calls, ['nav']);
    });

    testWidgets('tapping the surah title opens navigation', (tester) async {
      final calls = await pumpChrome(tester);
      await tester.tap(find.byKey(const ValueKey('mushaf-chrome-title')));
      expect(calls, ['nav']);
    });
  });

  test('reader page wires the navigation sheet and drops the old picker', () {
    final src = File(
      'lib/features/student/presentation/pages/student_mushaf_page.dart',
    ).readAsStringSync();
    expect(src.contains('showMushafNavigationSheet('), isTrue);
    expect(src.contains('MushafGoToJuzEvent('), isTrue);
    expect(src.contains('_showSurahPicker'), isFalse);
    expect(src.contains('_surahCatalog'), isFalse);
    expect(src.contains("'اختر سورة'"), isFalse);
    expect(src.contains('Coming Soon'), isFalse);
  });

  test('reader page source is valid UTF-8 Arabic (no mojibake)', () {
    final src = File(
      'lib/features/student/presentation/pages/student_mushaf_page.dart',
    ).readAsStringSync();
    expect(src.contains('ط§ظ„'), isFalse);
    expect(src.contains('â€'), isFalse);
    expect(src.codeUnitAt(0) == 0xFEFF, isFalse);
    expect(src.contains('وضع التسميع'), isTrue);
    expect(src.contains('تعذر تحميل المصحف'), isTrue);
  });
}
