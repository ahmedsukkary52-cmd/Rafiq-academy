// Independent audit (2026-11-06) regression tests. Test fixtures only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_bloc.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_event.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_state.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_audio_bar.dart';
import 'package:rafiq_academy/features/mushaf/presentation/widgets/mushaf_reader_tokens.dart';

import 'support/fake_mushaf_audio.dart';

class _GatedPrefsEngine extends FakeMushafAudioEngine {
  Completer<void>? speedGate;
  bool throwPrefs = false;

  @override
  Future<void> setSpeed(double speed) async {
    final g = speedGate;
    if (g != null) await g.future;
    if (throwPrefs) throw Exception('platform setSpeed failed');
    return super.setSpeed(speed);
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (throwPrefs) throw Exception('platform setVolume failed');
    return super.setMuted(muted);
  }
}

const _f1 = MushafAudioPlayAyahEvent(surahNumber: 1, ayahNumberInSurah: 1);

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _GatedPrefsEngine engine;
  late MushafAudioBloc bloc;

  setUp(() {
    engine = _GatedPrefsEngine();
    bloc = MushafAudioBloc(networkInfo: FakeNetworkInfo(), engine: engine);
  });

  tearDown(() async {
    if (!bloc.isClosed) await bloc.close();
    await engine.dispose();
  });

  test('AUDIT-2: stop during resume-from-pause prefs is not overwritten', () async {
    bloc.add(_f1);
    await _settle();
    expect(bloc.state.status, MushafAudioStatus.playing);
    bloc.add(const MushafAudioPauseEvent());
    await _settle();
    expect(bloc.state.status, MushafAudioStatus.paused);
    final playsBefore = engine.playCalls;

    engine.speedGate = Completer<void>();
    bloc.add(_f1); // resume path awaits prefs
    await _settle();
    bloc.add(const MushafAudioStopEvent());
    await _settle();
    engine.speedGate!.complete();
    await _settle();

    expect(bloc.state.status, MushafAudioStatus.idle);
    expect(engine.playCalls, playsBefore, reason: 'stale resume must not play');
  });

  test('AUDIT-3: speed/mute platform failure does not strand loading', () async {
    engine.throwPrefs = true;
    bloc.add(_f1);
    await _settle();
    expect(bloc.state.status, MushafAudioStatus.playing);
    bloc.add(const MushafAudioCycleSpeedEvent());
    bloc.add(const MushafAudioToggleMuteEvent());
    await _settle();
    expect(bloc.state.playbackSpeed, 1.25);
    expect(bloc.state.isMuted, isTrue);
  });

  testWidgets('AUDIT-1: repeat toggle keeps original semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            child: SingleChildScrollView(
              child: MushafAudioOptionsSheet(
                tokens: MushafReaderTokens.night,
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
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('\u062a\u0643\u0631\u0627\u0631 \u0627\u0644\u0622\u064a\u0629'),
      findsOneWidget,
    );
    handle.dispose();
  });
}