import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/services/mushaf_audio_engine.dart';

/// just_audio-backed engine. The platform player is created on first use.
@LazySingleton(as: MushafAudioEngine)
class JustAudioMushafEngine implements MushafAudioEngine {
  final _snapshots = StreamController<MushafEngineSnapshot>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  AudioPlayer? _player;

  AudioPlayer get _p => _player ??= _create();

  AudioPlayer _create() {
    final player = AudioPlayer();
    _subs
      ..add(
        player.playerStateStream.listen((s) {
          _snapshots.add(
            MushafEngineSnapshot(
              playing: s.playing,
              phase: switch (s.processingState) {
                ProcessingState.idle => MushafEnginePhase.idle,
                ProcessingState.loading => MushafEnginePhase.loading,
                ProcessingState.buffering => MushafEnginePhase.buffering,
                ProcessingState.ready => MushafEnginePhase.ready,
                ProcessingState.completed => MushafEnginePhase.completed,
              },
            ),
          );
        }),
      )
      ..add(player.playbackEventStream.listen((_) {}, onError: _errors.add))
      ..add(player.positionStream.listen(_position.add))
      ..add(player.durationStream.listen(_duration.add));
    return player;
  }

  @override
  Stream<MushafEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration?> get duration => _duration.stream;

  @override
  Future<void> load(String url) async {
    await _p.setUrl(url);
  }

  @override
  void play() {
    unawaited(_p.play().catchError(_errors.add));
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player?.dispose();
    await _snapshots.close();
    await _errors.close();
    await _position.close();
    await _duration.close();
  }
}
