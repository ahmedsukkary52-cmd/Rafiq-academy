import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/mushaf/data/datasources/quran_text_remote_datasource.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/mushaf_position.dart';
import 'package:rafiq_academy/features/mushaf/domain/entities/quran_text_bundle.dart';
import 'package:rafiq_academy/features/mushaf/domain/mushaf_reciter.dart';
import 'package:rafiq_academy/features/mushaf/domain/repositories/mushaf_reading_repository.dart';
import 'package:rafiq_academy/features/mushaf/domain/repositories/quran_text_repository.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/load_quran_text_usecase.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/resolve_mushaf_open_position_usecase.dart';
import 'package:rafiq_academy/features/mushaf/domain/usecases/save_mushaf_position_usecase.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_bloc.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_state.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_bloc.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_event.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_audio_bar.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_page_surface.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_tokens.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_top_chrome.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_mushaf_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_mushaf_audio.dart';
import 'support/quran_fixture.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Page 1: Al-Fatihah 1–7. Page 2: Al-Baqarah 1–5.
QuranTextBundle _twoPageQuran() => QuranTextRemoteDatasourceImpl.parseBundle(
  buildQuranFixtureJson(
    ayahs: [
      for (var a = 1; a <= 7; a++) (1, a, 1, 1),
      for (var a = 1; a <= 5; a++) (2, a, 2, 1),
    ],
  ),
);

class _QuranRepo implements QuranTextRepository {
  final bundle = _twoPageQuran();

  @override
  Future<Either<Failure, QuranTextBundle>> loadQuranText() async =>
      Right(bundle);
}

class _ReadingRepo implements MushafReadingRepository {
  final Map<String, MushafPosition> stored = {};
  final List<(String, MushafPosition)> saves = [];

  @override
  Future<Either<Failure, MushafPosition?>> getLastRead(String id) async =>
      Right(stored[id]);

  @override
  Future<Either<Failure, Unit>> saveLastRead({
    required String studentId,
    required MushafPosition position,
  }) async {
    saves.add((studentId, position));
    stored[studentId] = position;
    return const Right(unit);
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _rtlHost(Widget child, {double width = 390}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

MushafAudioBar _bar(
  MushafReaderTokens tokens,
  MushafAudioState state, {
  VoidCallback? onPrimary,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
}) => MushafAudioBar(
  tokens: tokens,
  state: state,
  surahName: 'البقرة',
  ayahNumber: 255,
  positionStream: const Stream.empty(),
  durationStream: const Stream.empty(),
  onPrimary: onPrimary ?? () {},
  onOptions: () {},
  onClose: () {},
  onPrevious: onPrevious ?? () {},
  onNext: onNext ?? () {},
);

const _targeted = MushafAudioState(surahNumber: 2, ayahNumberInSurah: 255);

void main() {
  // -------------------------------------------------------------------------
  group('H. Reader integration', () {
    late _ReadingRepo reading;
    late MushafBloc mushaf;
    late FakeMushafAudioEngine engine;
    late MushafAudioBloc audio;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    // Blocs are built inside the test body so their async work runs on the
    // widget tester's fake clock.
    Future<void> openReader(WidgetTester tester) async {
      reading = _ReadingRepo();
      mushaf = MushafBloc(
        loadQuranText: LoadQuranTextUseCase(_QuranRepo()),
        resolveOpenPosition: ResolveMushafOpenPositionUseCase(reading),
        savePosition: SaveMushafPositionUseCase(reading),
      );
      engine = FakeMushafAudioEngine();
      audio = MushafAudioBloc(networkInfo: FakeNetworkInfo(), engine: engine);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<MushafBloc>.value(value: mushaf),
            BlocProvider<MushafAudioBloc>.value(value: audio),
          ],
          child: const MaterialApp(home: StudentMushafPage()),
        ),
      );
      mushaf.add(const InitializeMushafEvent(studentId: 'A'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(mushaf.state.status, SectionStatus.loaded);
    }

    Future<void> closeReader(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 700));
      unawaited(audio.close());
      unawaited(mushaf.close());
      unawaited(engine.dispose());
      await tester.pump(const Duration(milliseconds: 50));
    }

    void tapAyah(WidgetTester tester, int surah, int ayah) {
      final label = 'آية $surah:$ayah';
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        TapGestureRecognizer? hit;
        rt.text.visitChildren((span) {
          if (span is TextSpan &&
              (span.text?.contains(label) ?? false) &&
              span.recognizer is TapGestureRecognizer) {
            hit = span.recognizer! as TapGestureRecognizer;
            return false;
          }
          return true;
        });
        if (hit != null) {
          hit!.onTap!();
          return;
        }
      }
      fail('ayah $label not rendered');
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    testWidgets('first open: no ayah selected, no audio bar, no request', (
      tester,
    ) async {
      await openReader(tester);
      expect(audio.state.hasTarget, isFalse);
      expect(mushaf.state.selectedAyah, isNull);
      expect(find.byType(MushafAudioBar), findsNothing);
      expect(engine.loads, isEmpty);
      await closeReader(tester);
    });

    testWidgets('tapping an ayah selects it without loading audio', (
      tester,
    ) async {
      await openReader(tester);
      tapAyah(tester, 1, 3);
      await settle(tester);

      expect(mushaf.state.selectedAyah?.numberInSurah, 3);
      expect(audio.state.isTarget(1, 3), isTrue);
      expect(audio.state.status, MushafAudioStatus.idle);
      expect(engine.loads, isEmpty);
      expect(find.text('سورة الفاتحة · الآية ٣'), findsOneWidget);
      expect(find.byTooltip('تشغيل التلاوة'), findsOneWidget);
      await closeReader(tester);
    });

    testWidgets('play / pause / next reflect bloc state in the bar', (
      tester,
    ) async {
      await openReader(tester);
      tapAyah(tester, 1, 3);
      await settle(tester);

      await tester.tap(find.byTooltip('تشغيل التلاوة'));
      await settle(tester);
      expect(audio.state.status, MushafAudioStatus.playing);
      expect(engine.loads.single, endsWith('/001003.mp3'));
      expect(find.byTooltip('إيقاف مؤقت'), findsOneWidget);

      await tester.tap(find.byTooltip('إيقاف مؤقت'));
      await settle(tester);
      expect(audio.state.status, MushafAudioStatus.paused);
      expect(find.textContaining('متوقفة مؤقتاً'), findsOneWidget);

      await tester.tap(find.byTooltip('الآية التالية'));
      await settle(tester);
      expect(audio.state.isTarget(1, 4), isTrue);
      expect(audio.state.status, MushafAudioStatus.playing);
      expect(mushaf.state.selectedAyah?.numberInSurah, 4);
      expect(find.text('سورة الفاتحة · الآية ٤'), findsOneWidget);
      await closeReader(tester);
    });

    testWidgets('audio state changes never rebuild the Quran PageView', (
      tester,
    ) async {
      await openReader(tester);
      tapAyah(tester, 1, 3);
      await settle(tester);
      final surface = tester.widget(find.byType(MushafPageSurface));

      await tester.tap(find.byTooltip('تشغيل التلاوة'));
      await settle(tester);
      engine.emitProgress(
        const Duration(seconds: 1),
        const Duration(seconds: 4),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('إيقاف مؤقت'));
      await settle(tester);

      expect(audio.state.status, MushafAudioStatus.paused);
      expect(
        identical(surface, tester.widget(find.byType(MushafPageSurface))),
        isTrue,
        reason: 'page subtree must not rebuild on play / progress / pause',
      );
      await closeReader(tester);
    });

    testWidgets('next across a page boundary moves the reader page', (
      tester,
    ) async {
      await openReader(tester);
      tapAyah(tester, 1, 7);
      await settle(tester);
      await tester.tap(find.byTooltip('الآية التالية'));
      await settle(tester);

      expect(audio.state.isTarget(2, 1), isTrue);
      expect(mushaf.state.position.pageNumber, 2);
      expect(find.text('سورة البقرة · الآية ١'), findsOneWidget);
      await closeReader(tester);
    });

    testWidgets('closing audio never rewrites last-read (C15)', (tester) async {
      await openReader(tester);
      tapAyah(tester, 1, 5);
      await settle(tester);
      await tester.tap(find.byTooltip('تشغيل التلاوة'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 700));
      final savesBefore = List.of(reading.saves);
      final positionBefore = mushaf.state.position;

      await tester.tap(find.byTooltip('إغلاق التلاوة'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 700));

      expect(audio.state.status, MushafAudioStatus.idle);
      expect(audio.state.hasTarget, isFalse);
      expect(reading.saves, savesBefore);
      expect(mushaf.state.position, positionBefore);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MushafAudioBar), findsNothing);
      await closeReader(tester);
    });

    testWidgets('leaving the reader silences the audio singleton', (
      tester,
    ) async {
      await openReader(tester);
      tapAyah(tester, 1, 2);
      await settle(tester);
      await tester.tap(find.byTooltip('تشغيل التلاوة'));
      await settle(tester);
      expect(audio.state.isPlaying, isTrue);

      await closeReader(tester);
      expect(audio.state.status, MushafAudioStatus.idle);
      expect(audio.state.hasTarget, isFalse);
    });

    test('audio code is independent of memorization progress', () {
      final files = [
        'lib/features/mushaf/presentation/bloc/mushaf_audio_bloc.dart',
        'lib/features/mushaf/presentation/bloc/mushaf_audio_state.dart',
        'lib/features/mushaf/presentation/bloc/mushaf_audio_event.dart',
        'lib/features/mushaf/presentation/widgets/mushaf_audio_bar.dart',
        'lib/features/mushaf/domain/mushaf_reciter.dart',
        'lib/features/mushaf/domain/services/mushaf_audio_engine.dart',
        'lib/features/mushaf/data/audio/just_audio_mushaf_engine.dart',
      ];
      for (final path in files) {
        final imports = File(
          path,
        ).readAsLinesSync().where((l) => l.startsWith('import ')).join('\n');
        expect(imports, isNot(contains('memoriz')), reason: path);
        expect(imports, isNot(contains('progress')), reason: path);
        expect(imports, isNot(contains('mushaf_bloc')), reason: path);
      }
    });

    test('reader page no longer owns a playback AudioPlayer', () {
      final page = File(
        'lib/features/student/presentation/pages/student_mushaf_page.dart',
      ).readAsStringSync();
      expect(page.contains('_audioPlayer'), isFalse);
      expect(page.contains('everyayah.com'), isFalse);
      expect(page.contains('Abdul_Basit_Murattal_128kbps'), isFalse);
      expect(page.contains('MushafAudioBloc'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('I. Visual / RTL', () {
    for (final tokens in [MushafReaderTokens.paper, MushafReaderTokens.night]) {
      final mode = tokens.isNight ? 'Night' : 'Paper';

      testWidgets('$mode bar renders Arabic labels on reader chrome', (
        tester,
      ) async {
        await tester.pumpWidget(_rtlHost(_bar(tokens, _targeted)));
        expect(find.text('سورة البقرة · الآية ٢٥٥'), findsOneWidget);
        expect(find.text(kDefaultMushafReciter.name), findsOneWidget);
        for (final tip in [
          'خيارات التلاوة',
          'الآية السابقة',
          'تشغيل التلاوة',
          'الآية التالية',
          'إغلاق التلاوة',
        ]) {
          expect(find.byTooltip(tip), findsOneWidget, reason: tip);
        }
        final surface = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(MushafAudioBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(surface.color, tokens.chrome, reason: 'opaque over Quran text');
      });

      test('$mode contrast: controls and error text stay legible', () {
        expect(_contrast(tokens.onAccent, tokens.accent), greaterThan(3.0));
        expect(_contrast(tokens.chromeInk, tokens.chrome), greaterThan(7.0));
        expect(_contrast(tokens.error, tokens.chrome), greaterThan(4.5));
        expect(_contrast(tokens.chromeMuted, tokens.chrome), greaterThan(3.0));
      });
    }

    testWidgets('previous sits on the reading-start (right) side in RTL', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      await tester.pumpWidget(
        _rtlHost(_bar(MushafReaderTokens.paper, _targeted), width: 800),
      );
      final prev = tester.getCenter(find.byTooltip('الآية السابقة'));
      final play = tester.getCenter(find.byTooltip('تشغيل التلاوة'));
      final next = tester.getCenter(find.byTooltip('الآية التالية'));
      final title = tester.getCenter(find.text('سورة البقرة · الآية ٢٥٥'));
      expect(prev.dx, greaterThan(play.dx));
      expect(next.dx, lessThan(play.dx));
      expect(title.dx, greaterThan(prev.dx), reason: 'info leads in RTL');
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('narrow bar stacks ayah / status above the controls', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 400));
      await tester.pumpWidget(
        _rtlHost(
          _bar(
            MushafReaderTokens.paper,
            _targeted.copyWith(
              status: MushafAudioStatus.error,
              errorMessage: MushafAudioBloc.offlineMessage,
            ),
          ),
          width: 320,
        ),
      );
      final status = find.byKey(const ValueKey('mushaf-audio-status'));
      final play = find.byTooltip('إعادة المحاولة');
      expect(
        tester.getBottomLeft(status).dy,
        lessThan(tester.getTopLeft(play).dy),
      );
      expect(
        tester.getCenter(find.byTooltip('الآية السابقة')).dx,
        greaterThan(tester.getCenter(play).dx),
      );
      // The status line owns the full row width instead of ~90 px beside
      // five controls (the test font is wider than real Arabic glyphs).
      expect(tester.getSize(status).width, greaterThan(280));
      await tester.binding.setSurfaceSize(null);
    });

    test('directional icons: media icons fixed, chevrons mirrored', () {
      // Media glyphs are not auto-mirrored, so the bar picks them explicitly:
      // previous ▶▶| points right (toward reading start) in RTL.
      expect(Icons.skip_next_rounded.matchTextDirection, isFalse);
      expect(Icons.skip_previous_rounded.matchTextDirection, isFalse);
      expect(Icons.play_arrow_rounded.matchTextDirection, isFalse);
      expect(Icons.arrow_back_ios_new_rounded.matchTextDirection, isTrue);
      final bar = File(
        'lib/features/mushaf/presentation/widgets/mushaf_audio_bar.dart',
      ).readAsStringSync();
      expect(
        bar.indexOf('Icons.skip_next_rounded'),
        lessThan(bar.indexOf("'الآية السابقة'")),
      );
      expect(
        bar.indexOf('Icons.skip_previous_rounded'),
        lessThan(bar.indexOf("'الآية التالية'")),
      );
    });

    testWidgets('top chrome back arrow points right (→) in RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: MushafReaderTopChrome(
                    tokens: MushafReaderTokens.paper,
                    surahName: 'الفاتحة',
                    pageNumber: 1,
                    visible: true,
                    onBack: () {},
                    onToggleNight: () {},
                    onOpenNavigation: () {},
                    onOpenSettings: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('رجوع'),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.arrow_back_ios_new_rounded);
      final back = tester.getCenter(find.byTooltip('رجوع'));
      expect(back.dx, greaterThan(400), reason: 'leading edge is right in RTL');
    });

    testWidgets('primary button icon and label follow status', (tester) async {
      final cases = <MushafAudioStatus, (IconData?, String)>{
        MushafAudioStatus.idle: (Icons.play_arrow_rounded, 'تشغيل التلاوة'),
        MushafAudioStatus.playing: (Icons.pause_rounded, 'إيقاف مؤقت'),
        MushafAudioStatus.paused: (Icons.play_arrow_rounded, 'متابعة التلاوة'),
        MushafAudioStatus.error: (Icons.refresh_rounded, 'إعادة المحاولة'),
        MushafAudioStatus.loading: (null, 'إلغاء التحميل'),
      };
      for (final entry in cases.entries) {
        await tester.pumpWidget(
          _rtlHost(
            MushafAudioPrimaryButton(
              tokens: MushafReaderTokens.paper,
              status: entry.key,
              onPressed: () {},
            ),
          ),
        );
        final icon = entry.value.$1;
        if (icon != null) expect(find.byIcon(icon), findsOneWidget);
        expect(find.byTooltip(entry.value.$2), findsOneWidget);
        expect(
          find.byType(CircularProgressIndicator),
          entry.key == MushafAudioStatus.loading
              ? findsOneWidget
              : findsNothing,
        );
      }
    });

    testWidgets('status line is truthful for loading, paused and error', (
      tester,
    ) async {
      const tokens = MushafReaderTokens.night;
      await tester.pumpWidget(
        _rtlHost(
          _bar(tokens, _targeted.copyWith(status: MushafAudioStatus.loading)),
        ),
      );
      expect(find.text('جارٍ تحميل التلاوة…'), findsOneWidget);

      await tester.pumpWidget(
        _rtlHost(
          _bar(tokens, _targeted.copyWith(status: MushafAudioStatus.paused)),
        ),
      );
      expect(find.textContaining('متوقفة مؤقتاً'), findsOneWidget);

      await tester.pumpWidget(
        _rtlHost(
          _bar(
            tokens,
            _targeted.copyWith(
              status: MushafAudioStatus.error,
              errorMessage: MushafAudioBloc.offlineMessage,
            ),
          ),
        ),
      );
      final status = tester.widget<Text>(
        find.byKey(const ValueKey('mushaf-audio-status')),
      );
      expect(status.data, MushafAudioBloc.offlineMessage);
      expect(status.style?.color, tokens.error);
    });

    testWidgets('disabled previous / next at the ends of the mushaf', (
      tester,
    ) async {
      await tester.pumpWidget(
        _rtlHost(
          MushafAudioBar(
            tokens: MushafReaderTokens.paper,
            state: _targeted,
            surahName: 'الفاتحة',
            ayahNumber: 1,
            positionStream: const Stream.empty(),
            durationStream: const Stream.empty(),
            onPrimary: () {},
            onOptions: () {},
            onClose: () {},
          ),
        ),
      );
      final prev = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.skip_next_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(prev.onPressed, isNull);
    });

    testWidgets('narrow (320) and wide (1024) widths do not overflow', (
      tester,
    ) async {
      for (final width in [320.0, 1024.0]) {
        await tester.binding.setSurfaceSize(Size(width, 400));
        await tester.pumpWidget(
          _rtlHost(
            _bar(
              MushafReaderTokens.paper,
              _targeted.copyWith(
                status: MushafAudioStatus.error,
                errorMessage: MushafAudioBloc.loadFailedMessage,
              ),
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('options sheet lists verified reciters and repeat toggle', (
      tester,
    ) async {
      String? picked;
      bool? looping;
      await tester.pumpWidget(
        _rtlHost(
          MushafAudioOptionsSheet(
            tokens: MushafReaderTokens.night,
            selectedReciterId: 'minshawi',
            isLooping: false,
              playbackSpeed: 1.0,
              isMuted: false,
            onSelectReciter: (id) => picked = id,
            onLoopChanged: (v) => looping = v,
              onCycleSpeed: () {},
              onToggleMute: () {},
          ),
        ),
      );
      expect(find.text('خيارات التلاوة'), findsOneWidget);
      for (final r in MushafReciters.all) {
        expect(find.text(r.name), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.textContaining('تلقائياً'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mushaf-reciter-husary')));
      expect(picked, 'husary');
      await tester.tap(find.byKey(const ValueKey('mushaf-audio-loop')));
      await tester.pump();
      expect(looping, isTrue);

      var speedTaps = 0;
      var muteTaps = 0;
      await tester.pumpWidget(
        _rtlHost(
          MushafAudioOptionsSheet(
            key: const ValueKey('options-speed-mute-fixture'),
            tokens: MushafReaderTokens.night,
            selectedReciterId: 'minshawi',
            isLooping: true,
            playbackSpeed: 1.25,
            isMuted: true,
            onSelectReciter: (_) {},
            onLoopChanged: (_) {},
            onCycleSpeed: () => speedTaps++,
            onToggleMute: () => muteTaps++,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('mushaf-audio-speed')), findsOneWidget);
      expect(find.byKey(const ValueKey('mushaf-audio-mute')), findsOneWidget);
      expect(find.text('x1.25'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mushaf-audio-speed')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mushaf-audio-mute')));
      await tester.pump();
      expect(speedTaps, 1);
      expect(muteTaps, 1);
      // Sheet keeps local chrome in sync (not stuck on constructor speed).
      expect(find.byKey(const ValueKey('mushaf-audio-speed-chip')), findsOneWidget);
      expect(find.text('x1.5'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('options sheet speed chip cycles locally and mute icon flips', (
      tester,
    ) async {
      await tester.pumpWidget(
        _rtlHost(
          MushafAudioOptionsSheet(
            tokens: MushafReaderTokens.paper,
            selectedReciterId: 'minshawi',
            isLooping: false,
            playbackSpeed: 1.0,
            isMuted: false,
            onSelectReciter: (_) {},
            onLoopChanged: (_) {},
            onCycleSpeed: () {},
            onToggleMute: () {},
          ),
        ),
      );
      expect(find.text('x1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mushaf-audio-speed')));
      await tester.pump();
      expect(find.text('x1.25'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mushaf-audio-speed')));
      await tester.pump();
      expect(find.text('x1.5'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mushaf-audio-mute')));
      await tester.pump();
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });
  });
}
