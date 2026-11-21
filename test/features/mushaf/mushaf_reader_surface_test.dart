import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_page_surface.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_states.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_tokens.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_top_chrome.dart';

void main() {
  group('MushafReaderTokens', () {
    test('Paper and Night are distinct reader-local palettes', () {
      expect(MushafReaderTokens.paper.isNight, isFalse);
      expect(MushafReaderTokens.night.isNight, isTrue);
      expect(
        MushafReaderTokens.paper.canvas,
        isNot(MushafReaderTokens.night.canvas),
      );
    });

    test('responsive margins grow with width and cap text measure', () {
      expect(MushafReaderTokens.horizontalMargin(320), lessThanOrEqualTo(20));
      expect(
        MushafReaderTokens.horizontalMargin(400),
        greaterThanOrEqualTo(20),
      );
      expect(
        MushafReaderTokens.horizontalMargin(800),
        greaterThanOrEqualTo(32),
      );
      expect(MushafReaderTokens.maxTextWidth(900), lessThanOrEqualTo(640));
    });

    test('body line height targets sustained reading comfort', () {
      final style = MushafReaderTokens.paper.bodyStyle(fontSize: 23);
      expect(style.height, closeTo(1.45, 0.01));
      expect(style.letterSpacing, 0);
    });

    test('styleOf maps preset ids', () {
      expect(MushafReaderTokens.styleOf('paper'), MushafReaderTokens.paper);
      expect(MushafReaderTokens.styleOf('night'), MushafReaderTokens.night);
      expect(MushafReaderTokens.styleOf('emerald'), MushafReaderTokens.emerald);
      expect(MushafReaderTokens.styleOf('sepia'), MushafReaderTokens.sepia);
      expect(MushafReaderTokens.styleOf('unknown'), MushafReaderTokens.paper);
    });
  });

  group('Reader surface widgets', () {
    testWidgets('Paper mode canvas and Arabic page number render', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MushafPageSurface(
              tokens: MushafReaderTokens.paper,
              pageNumber: 1,
              child: Text(
                'بِسْمِ اللَّهِ',
                style: MushafReaderTokens.paper.bodyStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      );

      expect(find.text('بِسْمِ اللَّهِ'), findsOneWidget);
      expect(find.text(MushafReaderTokens.arabicDigits(1)), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == MushafReaderTokens.paper.canvas,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Night mode uses night canvas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MushafPageSurface(
            tokens: MushafReaderTokens.night,
            pageNumber: 2,
            child: SizedBox.shrink(),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == MushafReaderTokens.night.canvas,
        ),
        findsOneWidget,
      );
    });

    testWidgets('top chrome night toggle updates callback', (tester) async {
      var night = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colors.white)),
                  MushafReaderTopChrome(
                    tokens: MushafReaderTokens.of(isNight: night),
                    surahName: 'الفاتحة',
                    pageNumber: 1,
                    visible: true,
                    onToggleNight: () => setState(() => night = !night),
                    onOpenNavigation: () {},
                    onOpenSettings: () {},
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.textContaining('صفحة'), findsOneWidget);
      await tester.tap(find.byTooltip('الوضع الليلي'));
      await tester.pumpAndSettle();
      expect(night, isTrue);
    });

    testWidgets('hidden chrome does not remove underlying Quran content', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Positioned.fill(child: Center(child: Text('محتوى المصحف'))),
              MushafReaderTopChrome(
                tokens: MushafReaderTokens.paper,
                surahName: 'البقرة',
                pageNumber: 2,
                visible: false,
                onToggleNight: () {},
                onOpenNavigation: () {},
                onOpenSettings: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('محتوى المصحف'), findsOneWidget);
    });

    testWidgets('loading state is Arabic and reader-consistent', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MushafReaderLoading(tokens: MushafReaderTokens.paper),
        ),
      );
      expect(find.textContaining('جاري تحميل'), findsOneWidget);
      expect(find.textContaining('Coming Soon'), findsNothing);
    });

    testWidgets('error state is Arabic and retry works', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MushafReaderError(
            tokens: MushafReaderTokens.paper,
            message: 'تعذر الاتصال',
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text('تعذر تحميل نص المصحف'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, isTrue);
    });

    testWidgets('surah header is calm without progress chrome', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MushafSurahHeader(
              tokens: MushafReaderTokens.paper,
              surahName: 'يس',
              surahNumber: 36,
              surahType: 'مكية',
            ),
          ),
        ),
      );
      expect(find.textContaining('سورة يس'), findsOneWidget);
      expect(find.textContaining('مكية'), findsOneWidget);
      expect(find.textContaining('Coming Soon'), findsNothing);
    });

    testWidgets('narrow and wide widths do not overflow reader surface', (
      tester,
    ) async {
      for (final width in [320.0, 390.0, 800.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: width,
              height: 700,
              child: MushafPageSurface(
                tokens: MushafReaderTokens.paper,
                pageNumber: 100,
                child: Text(
                  'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
                  style: MushafReaderTokens.paper.bodyStyle(fontSize: 22),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });
  });

  test('reader widgets + page have no Coming Soon or memorization progress', () {
    final paths = [
      'lib/features/mushaf/presentation/widgets/mushaf_reader_tokens.dart',
      'lib/features/mushaf/presentation/widgets/mushaf_reader_top_chrome.dart',
      'lib/features/mushaf/presentation/widgets/mushaf_page_surface.dart',
      'lib/features/mushaf/presentation/widgets/mushaf_reader_states.dart',
      'lib/features/student/presentation/pages/student_mushaf_page.dart',
    ];
    for (final path in paths) {
      final text = File(path).readAsStringSync();
      expect(text.contains('Coming Soon'), isFalse, reason: path);
      expect(text.contains('overallProgressPercent'), isFalse, reason: path);
    }
  });

  test('immersive reader: no permanent AppBar ModeSelector strip', () {
    final page = File(
      'lib/features/student/presentation/pages/student_mushaf_page.dart',
    ).readAsStringSync();
    expect(page.contains('MushafReaderTopChrome'), isTrue);
    expect(page.contains('MushafPageSurface'), isTrue);
    expect(page.contains('class _ModeSelector'), isFalse);
    expect(page.contains('appBar: AppBar('), isFalse);
  });
}
