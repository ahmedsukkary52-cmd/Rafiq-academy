import 'dart:async';

import 'package:rafiq_academy/core/network/network_info.dart';
import 'package:rafiq_academy/features/mushaf/domain/services/mushaf_audio_engine.dart';

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.connected = true});

  bool connected;

  /// When set, `isConnected` waits for it (simulates a slow check).
  Completer<void>? gate;

  @override
  Future<bool> get isConnected async {
    final g = gate;
    if (g != null) await g.future;
    return connected;
  }
}

/// Scriptable [MushafAudioEngine]. Records every call; loads can be held
/// open or failed to simulate slow / broken networks.
class FakeMushafAudioEngine implements MushafAudioEngine {
  final _snapshots = StreamController<MushafEngineSnapshot>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();

  final List<String> loads = [];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<Duration> seeks = [];
  bool disposed = false;

  /// Next loads throw.
  bool failLoads = false;

  /// When true, each load waits on its own completer in [pendingLoads].
  bool holdLoads = false;
  final List<Completer<void>> pendingLoads = [];

  int get listenerCount =>
      (_snapshots.hasListener ? 1 : 0) + (_errors.hasListener ? 1 : 0);

  void emitSnapshot(MushafEnginePhase phase, {required bool playing}) =>
      _snapshots.add(MushafEngineSnapshot(playing: playing, phase: phase));

  void emitError([Object error = 'network dropped']) => _errors.add(error);

  void emitProgress(Duration position, Duration total) {
    _duration.add(total);
    _position.add(position);
  }

  void completeLoad(int index) => pendingLoads[index].complete();

  void failLoad(int index) =>
      pendingLoads[index].completeError(Exception('load failed'));

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
    loads.add(url);
    if (holdLoads) {
      final c = Completer<void>();
      pendingLoads.add(c);
      await c.future;
      return;
    }
    if (failLoads) throw Exception('404');
  }

  @override
  void play() => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _snapshots.close();
    await _errors.close();
    await _position.close();
    await _duration.close();
  }
}
