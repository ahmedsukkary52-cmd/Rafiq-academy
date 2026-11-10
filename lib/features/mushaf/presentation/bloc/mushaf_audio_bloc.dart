import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/network/network_info.dart';
import '../../domain/mushaf_reciter.dart';
import '../../domain/services/mushaf_audio_engine.dart';
import 'mushaf_audio_event.dart';
import 'mushaf_audio_state.dart';

/// Owns Mushaf ayah playback (everyayah via [MushafAudioEngine]).
///
/// Auto-advance is OFF: completion either repeats the same ayah (loop) or
/// returns to idle. Reader position / last-read stay in `MushafBloc`.
@lazySingleton
class MushafAudioBloc extends Bloc<MushafAudioEvent, MushafAudioState> {
  final NetworkInfo networkInfo;
  final MushafAudioEngine engine;

  static const offlineMessage = 'التلاوة تحتاج اتصالاً بالإنترنت';
  static const loadFailedMessage = 'تعذر تحميل التلاوة';
  static const interruptedMessage = 'انقطعت التلاوة';

  /// Bumped by every command that supersedes an in-flight load.
  int _request = 0;
  bool _loadInFlight = false;
  bool _enginePlaying = false;
  final List<StreamSubscription<dynamic>> _subs = [];

  MushafAudioBloc({required this.networkInfo, required this.engine})
    : super(const MushafAudioState()) {
    on<MushafAudioSelectReciterEvent>(_onSelectReciter);
    on<MushafAudioSetTargetEvent>(_onSetTarget);
    on<MushafAudioPlayAyahEvent>(_onPlay);
    on<MushafAudioPauseEvent>(_onPause);
    on<MushafAudioStopEvent>(_onStop);
    on<MushafAudioToggleLoopEvent>(_onToggleLoop);
    on<MushafAudioCycleSpeedEvent>(_onCycleSpeed);
    on<MushafAudioToggleMuteEvent>(_onToggleMute);
    on<MushafAudioClearErrorEvent>(_onClearError);
    on<MushafAudioEngineSnapshotEvent>(_onSnapshot);
    on<MushafAudioEngineErrorEvent>(_onEngineError);

    _subs
      ..add(
        engine.snapshots.listen((s) => add(MushafAudioEngineSnapshotEvent(s))),
      )
      ..add(
        engine.errors.listen((_) => add(const MushafAudioEngineErrorEvent())),
      );
  }

  Stream<Duration> get positionStream => engine.position;

  Stream<Duration?> get durationStream => engine.duration;

  /// Invalidates any in-flight load and silences the engine.
  ///
  /// Handlers run concurrently, so callers emit their new state *before*
  /// awaiting this — a late emit would overwrite a newer command's state.
  Future<void> _halt() async {
    _request++;
    _loadInFlight = false;
    try {
      await engine.stop();
    } catch (_) {}
  }

  Future<void> _onSelectReciter(
    MushafAudioSelectReciterEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    final reciter = MushafReciters.byId(event.reciterId);
    if (reciter == null || reciter.id == state.reciter.id) return;
    final wasEngaged = state.isActive || state.hasError;
    emit(
      state.copyWith(
        reciter: reciter,
        status: wasEngaged ? MushafAudioStatus.idle : null,
        clearError: true,
      ),
    );
    if (wasEngaged) await _halt();
  }

  Future<void> _onSetTarget(
    MushafAudioSetTargetEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    if (state.isTarget(event.surahNumber, event.ayahNumberInSurah)) return;
    final wasActive = state.isActive;
    emit(
      state.copyWith(
        status: MushafAudioStatus.idle,
        clearError: true,
        surahNumber: event.surahNumber,
        ayahNumberInSurah: event.ayahNumberInSurah,
      ),
    );
    if (wasActive) await _halt();
  }

  Future<void> _onPlay(
    MushafAudioPlayAyahEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    final surah = event.surahNumber;
    final ayah = event.ayahNumberInSurah;
    final url = MushafReciters.ayahUrl(state.reciter, surah, ayah);
    if (url == null) return;

    if (state.isTarget(surah, ayah)) {
      if (state.isLoading || state.isPlaying) return;
      if (state.isPaused) {
        final resumeRequest = ++_request;
        await _applyPlaybackPrefs();
        // Audit fix: a Stop/target change during the await must win.
        if (resumeRequest != _request || !state.isPaused) return;
        engine.play();
        emit(state.copyWith(status: MushafAudioStatus.playing));
        return;
      }
    }

    final request = ++_request;
    emit(
      state.copyWith(
        status: MushafAudioStatus.loading,
        clearError: true,
        surahNumber: surah,
        ayahNumberInSurah: ayah,
      ),
    );

    final connected = await networkInfo.isConnected;
    if (request != _request) return;
    if (!connected) {
      emit(
        state.copyWith(
          status: MushafAudioStatus.error,
          errorMessage: offlineMessage,
        ),
      );
      return;
    }

    _loadInFlight = true;
    try {
      await engine.stop();
      await engine.load(url);
    } catch (_) {
      if (request != _request) return;
      _loadInFlight = false;
      emit(
        state.copyWith(
          status: MushafAudioStatus.error,
          errorMessage: loadFailedMessage,
        ),
      );
      try {
        await engine.stop();
      } catch (_) {}
      return;
    }
    if (request != _request) return;
    _loadInFlight = false;

    await _applyPlaybackPrefs();
    if (request != _request) return;
    engine.play();
    emit(state.copyWith(status: MushafAudioStatus.playing));
  }

  Future<void> _onPause(
    MushafAudioPauseEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    if (state.isLoading) {
      // Nothing audible yet — cancel the load instead of pausing it.
      emit(state.copyWith(status: MushafAudioStatus.idle));
      await _halt();
      return;
    }
    if (!state.isPlaying) return;
    emit(state.copyWith(status: MushafAudioStatus.paused));
    try {
      await engine.pause();
    } catch (_) {}
  }

  Future<void> _onStop(
    MushafAudioStopEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    emit(
      state.copyWith(
        status: MushafAudioStatus.idle,
        clearError: true,
        clearTarget: event.clearTarget,
      ),
    );
    await _halt();
  }

  static const List<double> _speeds = [1.0, 1.25, 1.5, 2.0];

  /// Best effort: a platform speed/volume failure must never strand playback.
  Future<void> _applyPlaybackPrefs() async {
    try {
      await engine.setSpeed(state.playbackSpeed);
    } catch (_) {}
    try {
      await engine.setMuted(state.isMuted);
    } catch (_) {}
  }

  Future<void> _onCycleSpeed(
    MushafAudioCycleSpeedEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    final idx = _speeds.indexOf(state.playbackSpeed);
    final next = _speeds[((idx < 0 ? 0 : idx) + 1) % _speeds.length];
    emit(state.copyWith(playbackSpeed: next));
    try {
      await engine.setSpeed(next);
    } catch (_) {}
  }

  Future<void> _onToggleMute(
    MushafAudioToggleMuteEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    final next = !state.isMuted;
    emit(state.copyWith(isMuted: next));
    try {
      await engine.setMuted(next);
    } catch (_) {}
  }

  void _onToggleLoop(
    MushafAudioToggleLoopEvent event,
    Emitter<MushafAudioState> emit,
  ) {
    emit(state.copyWith(isLooping: !state.isLooping));
  }

  void _onClearError(
    MushafAudioClearErrorEvent event,
    Emitter<MushafAudioState> emit,
  ) {
    if (!state.hasError) return;
    emit(state.copyWith(clearError: true, status: MushafAudioStatus.idle));
  }

  Future<void> _onSnapshot(
    MushafAudioEngineSnapshotEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    final s = event.snapshot;
    final wasPlaying = _enginePlaying;
    _enginePlaying = s.playing;

    if (state.status != MushafAudioStatus.playing &&
        state.status != MushafAudioStatus.loading) {
      return;
    }

    switch (s.phase) {
      case MushafEnginePhase.completed:
        if (!state.isPlaying) return;
        if (state.isLooping) {
          final request = _request;
          try {
            await engine.seek(Duration.zero);
          } catch (_) {}
          if (request == _request && state.isPlaying) engine.play();
          return;
        }
        emit(state.copyWith(status: MushafAudioStatus.idle));
        await _halt();
      case MushafEnginePhase.buffering:
      case MushafEnginePhase.loading:
        if (s.playing && state.isPlaying) {
          emit(state.copyWith(status: MushafAudioStatus.loading));
        }
      case MushafEnginePhase.ready:
        if (s.playing && state.isLoading && !_loadInFlight) {
          emit(state.copyWith(status: MushafAudioStatus.playing));
        } else if (!s.playing && wasPlaying && state.isPlaying) {
          // Paused outside the app (audio focus loss, headphones removed).
          emit(state.copyWith(status: MushafAudioStatus.paused));
        }
      case MushafEnginePhase.idle:
        break;
    }
  }

  Future<void> _onEngineError(
    MushafAudioEngineErrorEvent event,
    Emitter<MushafAudioState> emit,
  ) async {
    if (!state.isPlaying && !state.isLoading) return;
    // A load in flight reports its own failure through `load()`.
    if (_loadInFlight) return;
    emit(
      state.copyWith(
        status: MushafAudioStatus.error,
        errorMessage: interruptedMessage,
      ),
    );
    await _halt();
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    try {
      await engine.stop();
    } catch (_) {}
    return super.close();
  }
}
