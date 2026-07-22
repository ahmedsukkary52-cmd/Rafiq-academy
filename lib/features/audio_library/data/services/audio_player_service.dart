import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';

@LazySingleton()
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Cancels an in-flight [play] when a newer request or [stop]/[pause] wins.
  int _loadGeneration = 0;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<bool> get playingStream => _player.playingStream;

  ProcessingState get processingState => _player.processingState;

  bool get playing => _player.playing;

  bool get isBufferingOrLoading =>
      processingState == ProcessingState.loading ||
      processingState == ProcessingState.buffering;

  /// Loads [url] then starts playback.
  ///
  /// just_audio can leave [processingState] stuck on [ProcessingState.buffering]
  /// if [AudioPlayer.pause] is called mid-load. Callers should prefer [pause]
  /// from this service (which stops when still buffering) rather than calling
  /// the raw player.
  Future<void> play(String url) async {
    final generation = ++_loadGeneration;

    try {
      // Drop any previous incomplete load so its buffering state cannot linger.
      if (_player.processingState != ProcessingState.idle) {
        await _player.stop();
      }
      if (generation != _loadGeneration) return;

      await _player
          .setAudioSource(AudioSource.uri(Uri.parse(url)))
          .timeout(const Duration(seconds: 15));
      if (generation != _loadGeneration) return;

      await _player.play();
    } on TimeoutException {
      await _safeStop();
      rethrow;
    } catch (_) {
      await _safeStop();
      rethrow;
    }
  }

  /// Pauses if media is ready; [stop]s if still loading/buffering so the
  /// player cannot stay stuck with [ProcessingState.buffering] forever.
  Future<void> pause() async {
    _loadGeneration++;

    if (isBufferingOrLoading) {
      await _safeStop();
      return;
    }

    await _player.pause();
  }

  Future<void> resume() async {
    if (isBufferingOrLoading) {
      // Resume after a mid-load stop needs a fresh play() with the URL.
      return;
    }
    await _player.play();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    _loadGeneration++;
    await _safeStop();
  }

  Future<void> dispose() async {
    _loadGeneration++;
    await _player.dispose();
  }

  Future<void> _safeStop() async {
    try {
      await _player.stop();
    } catch (_) {
      // Ignore stop errors while recovering from a failed/cancelled load.
    }
  }
}
