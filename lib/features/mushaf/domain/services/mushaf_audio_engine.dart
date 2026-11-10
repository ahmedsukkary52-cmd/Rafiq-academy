enum MushafEnginePhase { idle, loading, buffering, ready, completed }

class MushafEngineSnapshot {
  final bool playing;
  final MushafEnginePhase phase;

  const MushafEngineSnapshot({required this.playing, required this.phase});
}

/// Single-track ayah player used by MushafAudioBloc.
abstract class MushafAudioEngine {
  Stream<MushafEngineSnapshot> get snapshots;

  /// Errors raised while a loaded track is playing (e.g. network drop).
  Stream<Object> get errors;

  Stream<Duration> get position;

  Stream<Duration?> get duration;

  /// Throws when the source cannot be loaded.
  Future<void> load(String url);

  /// Starts playback without waiting for the track to finish.
  void play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  /// Playback rate (1.0, 1.25, 1.5, 2.0). Restored from legacy reader UX.
  Future<void> setSpeed(double speed);

  /// When true, volume is 0 while keeping the loaded track.
  Future<void> setMuted(bool muted);

  Future<void> dispose();
}