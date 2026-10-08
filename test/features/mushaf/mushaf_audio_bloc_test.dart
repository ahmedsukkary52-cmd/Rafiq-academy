import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/mushaf/domain/mushaf_reciter.dart';
import 'package:rafiq_academy/features/mushaf/domain/services/mushaf_audio_engine.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_bloc.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_event.dart';
import 'package:rafiq_academy/features/mushaf/presentation/bloc/mushaf_audio_state.dart';

import 'support/fake_mushaf_audio.dart';

const _fatihah1 = MushafAudioPlayAyahEvent(
  surahNumber: 1,
  ayahNumberInSurah: 1,
);
const _fatihah2 = MushafAudioPlayAyahEvent(
  surahNumber: 1,
  ayahNumberInSurah: 2,
);

String _url(String dir, String file) =>
    'https://everyayah.com/data/$dir/$file.mp3';

void main() {
  late FakeNetworkInfo network;
  late FakeMushafAudioEngine engine;
  late MushafAudioBloc bloc;
  late List<MushafAudioState> states;
  late StreamSubscription<MushafAudioState> sub;

  setUp(() {
    network = FakeNetworkInfo();
    engine = FakeMushafAudioEngine();
    bloc = MushafAudioBloc(networkInfo: network, engine: engine);
    states = [];
    sub = bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await sub.cancel();
    if (!bloc.isClosed) await bloc.close();
    await engine.dispose();
  });

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> playFatihah1() async {
    bloc.add(_fatihah1);
    await settle();
    expect(bloc.state.status, MushafAudioStatus.playing);
  }

  group('A. Play', () {
    test('loads the verified URL, then reports playing', () async {
      bloc.add(_fatihah1);
      await settle();

      expect(states.first.status, MushafAudioStatus.loading);
      expect(bloc.state.status, MushafAudioStatus.playing);
      expect(bloc.state.isTarget(1, 1), isTrue);
      expect(engine.loads, [_url('Minshawy_Murattal_128kbps', '001001')]);
      expect(engine.playCalls, 1);
    });

    test('play of the currently playing ayah is ignored', () async {
      await playFatihah1();
      bloc.add(_fatihah1);
      bloc.add(_fatihah1);
      await settle();
      expect(engine.loads, hasLength(1));
      expect(engine.playCalls, 1);
    });

    test('invalid ayah (1:8) is rejected without a request', () async {
      bloc.add(
        const MushafAudioPlayAyahEvent(surahNumber: 1, ayahNumberInSurah: 8),
      );
      await settle();
      expect(engine.loads, isEmpty);
      expect(bloc.state.status, MushafAudioStatus.idle);
    });
  });

  group('B. Pause', () {
    test('pause then resume reuses the loaded track', () async {
      await playFatihah1();
      bloc.add(const MushafAudioPauseEvent());
      await settle();
      expect(bloc.state.status, MushafAudioStatus.paused);
      expect(engine.pauseCalls, 1);

      bloc.add(_fatihah1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
      expect(engine.loads, hasLength(1), reason: 'resume must not reload');
      expect(engine.playCalls, 2);
    });

    test('pause while idle does nothing', () async {
      bloc.add(const MushafAudioPauseEvent());
      await settle();
      expect(states, isEmpty);
      expect(engine.pauseCalls, 0);
    });

    test('external pause (audio focus loss) is reflected as paused', () async {
      await playFatihah1();
      engine.emitSnapshot(MushafEnginePhase.ready, playing: true);
      await settle();
      engine.emitSnapshot(MushafEnginePhase.ready, playing: false);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.paused);
    });
  });

  group('C. Stop and completion', () {
    test(
      'stop returns to idle, keeps the selection, silences engine',
      () async {
        await playFatihah1();
        final stopsBefore = engine.stopCalls;
        bloc.add(const MushafAudioStopEvent());
        await settle();
        expect(bloc.state.status, MushafAudioStatus.idle);
        expect(bloc.state.isTarget(1, 1), isTrue);
        expect(engine.stopCalls, greaterThan(stopsBefore));
      },
    );

    test('stop with clearTarget forgets the ayah', () async {
      await playFatihah1();
      bloc.add(const MushafAudioStopEvent(clearTarget: true));
      await settle();
      expect(bloc.state.hasTarget, isFalse);
      expect(bloc.state.status, MushafAudioStatus.idle);
    });

    test('completion returns to idle; no auto-advance', () async {
      await playFatihah1();
      engine.emitSnapshot(MushafEnginePhase.completed, playing: true);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.idle);
      expect(bloc.state.isTarget(1, 1), isTrue);
      expect(engine.loads, hasLength(1));
    });

    test('repeat-ayah replays the same ayah in place', () async {
      bloc.add(const MushafAudioToggleLoopEvent());
      await playFatihah1();
      engine.emitSnapshot(MushafEnginePhase.completed, playing: true);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
      expect(engine.seeks, [Duration.zero]);
      expect(engine.playCalls, 2);
      expect(engine.loads, hasLength(1));
    });
  });

  group('D. Loading', () {
    test('stays loading until the source is ready', () async {
      engine.holdLoads = true;
      bloc.add(_fatihah1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.loading);
      expect(engine.playCalls, 0);

      engine.completeLoad(0);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
    });

    test('pause while loading cancels; the late load is discarded', () async {
      engine.holdLoads = true;
      bloc.add(_fatihah1);
      await settle();
      bloc.add(const MushafAudioPauseEvent());
      await settle();
      expect(bloc.state.status, MushafAudioStatus.idle);

      engine.completeLoad(0);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.idle);
      expect(engine.playCalls, 0);
    });

    test('buffering mid-play shows loading, then playing again', () async {
      await playFatihah1();
      engine.emitSnapshot(MushafEnginePhase.buffering, playing: true);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.loading);
      engine.emitSnapshot(MushafEnginePhase.ready, playing: true);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
    });
  });

  group('E. Errors', () {
    test('offline: truthful Arabic error, no request made', () async {
      network.connected = false;
      bloc.add(_fatihah1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.error);
      expect(bloc.state.errorMessage, MushafAudioBloc.offlineMessage);
      expect(engine.loads, isEmpty);
    });

    test('load failure shows error; retry recovers', () async {
      engine.failLoads = true;
      bloc.add(_fatihah1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.error);
      expect(bloc.state.errorMessage, MushafAudioBloc.loadFailedMessage);
      expect(engine.playCalls, 0);

      engine.failLoads = false;
      bloc.add(_fatihah1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
      expect(bloc.state.errorMessage, isNull);
    });

    test('engine error mid-play clears playing state', () async {
      await playFatihah1();
      engine.emitError();
      await settle();
      expect(bloc.state.status, MushafAudioStatus.error);
      expect(bloc.state.errorMessage, MushafAudioBloc.interruptedMessage);
    });

    test('clear error returns to idle', () async {
      network.connected = false;
      bloc.add(_fatihah1);
      await settle();
      bloc.add(const MushafAudioClearErrorEvent());
      await settle();
      expect(bloc.state.status, MushafAudioStatus.idle);
      expect(bloc.state.errorMessage, isNull);
    });
  });

  group('F. Rapid interaction', () {
    test('a newer play supersedes a slow one; only the last plays', () async {
      engine.holdLoads = true;
      bloc.add(_fatihah1);
      await settle();
      bloc.add(_fatihah2);
      await settle();

      engine.completeLoad(0);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.loading);
      expect(engine.playCalls, 0, reason: 'stale ayah must never start');

      engine.completeLoad(1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
      expect(bloc.state.isTarget(1, 2), isTrue);
      expect(engine.playCalls, 1);
    });

    test('stale load failure does not surface an error', () async {
      engine.holdLoads = true;
      bloc.add(_fatihah1);
      await settle();
      bloc.add(_fatihah2);
      await settle();
      engine.failLoad(0);
      engine.completeLoad(1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
      expect(bloc.state.isTarget(1, 2), isTrue);
    });

    test('stop during the network check prevents any request', () async {
      network.gate = Completer<void>();
      bloc.add(_fatihah1);
      await settle();
      bloc.add(const MushafAudioStopEvent());
      await settle();
      network.gate!.complete();
      await settle();
      expect(engine.loads, isEmpty);
      expect(bloc.state.status, MushafAudioStatus.idle);
    });

    test('rapid ayah selection while playing ends on the last ayah', () async {
      await playFatihah1();
      for (var a = 2; a <= 6; a++) {
        bloc.add(
          MushafAudioSetTargetEvent(surahNumber: 1, ayahNumberInSurah: a),
        );
      }
      await settle();
      expect(bloc.state.isTarget(1, 6), isTrue);
      expect(bloc.state.status, MushafAudioStatus.idle);
      expect(engine.loads, hasLength(1), reason: 'selection never prefetches');
    });

    test('play / pause spam settles consistently', () async {
      for (var i = 0; i < 5; i++) {
        bloc.add(_fatihah1);
        bloc.add(const MushafAudioPauseEvent());
      }
      bloc.add(_fatihah1);
      await settle();
      expect(bloc.state.status, MushafAudioStatus.playing);
      expect(engine.playCalls, lessThanOrEqualTo(engine.loads.length));
    });

    test('close cancels engine listeners', () async {
      expect(engine.listenerCount, 2);
      await bloc.close();
      expect(engine.listenerCount, 0);
    });
  });

  group('G. Reciters', () {
    test('only verified reciters, labelled in Arabic', () {
      expect(MushafReciters.all.map((r) => r.id), [
        'minshawi',
        'husary',
        'afasy',
      ]);
      for (final r in MushafReciters.all) {
        expect(RegExp(r'^[\u0600-\u06FF ]+$').hasMatch(r.name), isTrue);
      }
      expect(MushafReciters.byId('basit'), isNull);
    });

    test('URL bounds follow the surah catalog', () {
      expect(
        MushafReciters.ayahUrl(kDefaultMushafReciter, 114, 6),
        _url('Minshawy_Murattal_128kbps', '114006'),
      );
      expect(MushafReciters.ayahUrl(kDefaultMushafReciter, 114, 7), isNull);
      expect(MushafReciters.ayahUrl(kDefaultMushafReciter, 0, 1), isNull);
    });

    test('switching while idle loads nothing; next play uses it', () async {
      bloc.add(const MushafAudioSelectReciterEvent('husary'));
      await settle();
      expect(bloc.state.reciter.id, 'husary');
      expect(engine.loads, isEmpty);

      bloc.add(_fatihah1);
      await settle();
      expect(engine.loads.single, _url('Husary_128kbps', '001001'));
    });

    test('switching while playing stops the old recitation', () async {
      await playFatihah1();
      bloc.add(const MushafAudioSelectReciterEvent('afasy'));
      await settle();
      expect(bloc.state.status, MushafAudioStatus.idle);
      expect(bloc.state.reciter.id, 'afasy');
      expect(bloc.state.isTarget(1, 1), isTrue);
      expect(engine.loads, hasLength(1), reason: 'no automatic reload');
    });

    test('unknown or unchanged reciter is ignored', () async {
      bloc.add(const MushafAudioSelectReciterEvent('fake'));
      bloc.add(MushafAudioSelectReciterEvent(kDefaultMushafReciter.id));
      await settle();
      expect(states, isEmpty);
    });
  });
}
