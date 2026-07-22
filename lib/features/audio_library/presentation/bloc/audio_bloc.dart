import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/usecases/usecases.dart';
import '../../domain/entities/audio_entities.dart';
import '../../domain/usecases/audio_usecases.dart';
import '../../data/datasources/mp3quran_catalog_service.dart';
import '../../data/services/audio_player_service.dart';
import 'audio_event.dart';
import 'audio_state.dart';

@injectable
class AudioLibraryBloc extends Bloc<AudioLibraryEvent, AudioLibraryState> {
  final GetAllRecitersUseCase getAllReciters;
  final GetFavoriteRecitersUseCase getFavoriteReciters;
  final ToggleFollowReciterUseCase toggleFollowReciter;
  final GetSurahAudiosUseCase getSurahAudios;
  final GetContinueListeningUseCase getContinueListening;
  final SaveListeningProgressUseCase saveListeningProgress;
  final GetListeningProgressUseCase getListeningProgress;
  final AudioPlayerService audioPlayerService;
  final FirebaseAuth firebaseAuth;

  static const _lastReciterKey = 'last_selected_reciter_id';
  static const _recentRecitersKey = 'recent_audio_reciter_ids';

  /// mp3quran reciter id for مشاري راشد العفاسي (حفص - مرتل).
  static const _defaultReciterId = kDefaultReciterId;

  static const _loadingWatchdogTimeout = Duration(seconds: 12);
  static const _playbackErrorMessage =
      'تعذر تحميل الصوت، تحقق من اتصال الإنترنت';

  late final StreamSubscription<PlayerState> _playerStateSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<bool> _playingSub;
  Timer? _progressSaveTimer;
  Timer? _loadingWatchdog;

  /// True while [play]/[resume] awaits network load — prevents the stream
  /// from clearing [isLoading] during setAudioSource (playing is still false).
  bool _playRequestInFlight = false;

  AudioLibraryBloc({
    required this.getAllReciters,
    required this.getFavoriteReciters,
    required this.toggleFollowReciter,
    required this.getSurahAudios,
    required this.getContinueListening,
    required this.saveListeningProgress,
    required this.getListeningProgress,
    required this.audioPlayerService,
    required this.firebaseAuth,
  }) : super(AudioLibraryState.initial()) {
    // Subscribe to audio player streams
    _playerStateSub = audioPlayerService.playerStateStream.listen((
      playerState,
    ) {
      final buffering =
          playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering;

      // Mid-load pause/stop can leave processingState on buffering with
      // playing=false. Clear the spinner unless we ourselves are still
      // awaiting play()/resume().
      final isLoading = _playRequestInFlight
          ? true
          : buffering && playerState.playing;

      add(_UpdatePlaybackStateEvent(isLoading: isLoading));
    });

    _positionSub = audioPlayerService.positionStream.listen((position) {
      add(_UpdatePositionEvent(position));
    });

    _durationSub = audioPlayerService.durationStream.listen((duration) {
      add(_UpdateDurationEvent(duration));
    });

    _playingSub = audioPlayerService.playingStream.listen((isPlaying) {
      add(_UpdateIsPlayingEvent(isPlaying));
    });

    on<LoadAudioLibraryEvent>(_onLoadAudioLibrary);
    on<ToggleFollowReciterEvent>(_onToggleFollowReciter);
    on<SelectSurahAudioEvent>(_onSelectSurahAudio);
    on<PlaySurahAudioEvent>(_onPlaySurah);
    on<PausePlaybackEvent>(_onPause);
    on<ResumePlaybackEvent>(_onResume);
    on<SeekToPositionEvent>(_onSeek);
    on<SearchAudioLibraryEvent>(_onSearch);
    on<SelectReciterEvent>(_onSelectReciter);
    on<_UpdatePlaybackStateEvent>(_onUpdatePlaybackState);
    on<_UpdatePositionEvent>(_onUpdatePosition);
    on<_UpdateDurationEvent>(_onUpdateDuration);
    on<_UpdateIsPlayingEvent>(_onUpdateIsPlaying);
    on<_ForceStopLoadingEvent>(_onForceStopLoading);
  }

  Future<void> _onLoadAudioLibrary(
    LoadAudioLibraryEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    print('[AudioLibraryBloc] Loading audio library');
    emit(
      state.copyWith(
        recitersStatus: SectionStatus.loading,
        surahAudiosStatus: SectionStatus.loading,
        continueListeningStatus: SectionStatus.loading,
      ),
    );

    // جيب آخر شيخ محفوظ محلياً
    final prefs = await SharedPreferences.getInstance();
    final savedReciterId = prefs.getString(_lastReciterKey);
    final normalizedSavedId = normalizeReciterId(savedReciterId);
    final recentReciterIds =
        (prefs.getStringList(_recentRecitersKey) ?? const [])
            .map(normalizeReciterId)
            .toList();
    emit(state.copyWith(recentReciterIds: recentReciterIds));

    final results = await Future.wait([
      getAllReciters(const NoParams()),
      getFavoriteReciters(const NoParams()),
      getSurahAudios(GetSurahAudiosParams()),
      getContinueListening(const NoParams()),
    ]);

    final recitersResult = results[0] as dynamic;
    final favoritesResult = results[1] as dynamic;
    final surahsResult = results[2] as dynamic;
    final continueResult = results[3] as dynamic;

    recitersResult.fold(
      (failure) => emit(
        state.copyWith(
          recitersStatus: SectionStatus.error,
          recitersError: failure.message,
        ),
      ),
      (reciters) {
        print('[AudioLibraryBloc] Loaded ${reciters.length} all reciters');

        // حدد القارئ الافتراضي:
        // 1) لو فيه شيخ محفوظ من قبل ولسه موجود -> استخدمه
        // 2) غير كده، مشاري (mp3quran id: 123) هو الافتراضي
        String? initialReciterId;
        final savedStillExists =
            savedReciterId != null &&
            reciters.any((r) => r.id == normalizedSavedId);
        if (savedStillExists) {
          initialReciterId = normalizedSavedId;
        } else if (reciters.any((r) => r.id == _defaultReciterId)) {
          initialReciterId = _defaultReciterId;
        }

        emit(
          state.copyWith(
            recitersStatus: SectionStatus.loaded,
            allReciters: reciters,
            selectedReciterId: initialReciterId,
          ),
        );
      },
    );

    // ... باقي الفانكشن زي ما هي من غير تغيير
    // Emit favorites state
    favoritesResult.fold(
      (failure) => emit(state.copyWith(recitersError: failure.message)),
      (favorites) {
        print(
          '[AudioLibraryBloc] Loaded ${favorites.length} favorite reciters',
        );
        emit(state.copyWith(favoriteReciters: favorites));
      },
    );

    // Emit surah audios state
    surahsResult.fold(
      (failure) => emit(
        state.copyWith(
          surahAudiosStatus: SectionStatus.error,
          surahAudiosError: failure.message,
        ),
      ),
      (surahs) {
        print('[AudioLibraryBloc] Loaded ${surahs.length} surah audios');
        emit(
          state.copyWith(
            surahAudiosStatus: SectionStatus.loaded,
            surahAudios: surahs,
          ),
        );
      },
    );

    // Emit continue listening state
    continueResult.fold(
      (failure) => emit(
        state.copyWith(
          continueListeningStatus: SectionStatus.error,
          continueListeningError: failure.message,
        ),
      ),
      (surah) {
        final reciterId = surah?.reciterId;
        final recentIds = reciterId == null
            ? state.recentReciterIds
            : _prependUnique(state.recentReciterIds, reciterId);
        emit(
          state.copyWith(
            continueListeningStatus: SectionStatus.loaded,
            continueListening: surah,
            recentReciterIds: recentIds,
          ),
        );
        if (reciterId != null) {
          unawaited(prefs.setStringList(_recentRecitersKey, recentIds));
        }
      },
    );
  }

  Future<void> _onToggleFollowReciter(
    ToggleFollowReciterEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    final previousAll = state.allReciters;
    final previousFavorites = state.favoriteReciters;

    // Optimistic update
    final updatedAll = state.allReciters.map((r) {
      if (r.id == event.reciterId) {
        return r.copyWith(isFollowing: event.isFollowing);
      }
      return r;
    }).toList();

    final selected = updatedAll.where((r) => r.id == event.reciterId);
    final updatedFavorites = event.isFollowing
        ? [
            ...selected,
            ...state.favoriteReciters.where((r) => r.id != event.reciterId),
          ]
        : state.favoriteReciters.where((r) => r.id != event.reciterId).toList();

    emit(
      state.copyWith(
        allReciters: updatedAll,
        favoriteReciters: updatedFavorites,
      ),
    );

    // Make API call
    final result = await toggleFollowReciter(
      ToggleFollowParams(
        reciterId: event.reciterId,
        isFollowing: event.isFollowing,
      ),
    );

    result.fold((failure) {
      emit(
        state.copyWith(
          allReciters: previousAll,
          favoriteReciters: previousFavorites,
        ),
      );
    }, (_) {});
  }

  Future<void> _onSelectSurahAudio(
    SelectSurahAudioEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    final reciterId = event.surah.reciterId;
    final recentIds = reciterId == null
        ? state.recentReciterIds
        : _prependUnique(state.recentReciterIds, reciterId);
    emit(
      state.copyWith(selectedSurah: event.surah, recentReciterIds: recentIds),
    );
    if (reciterId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentRecitersKey, recentIds);
    }

    // Get saved progress for this surah
    final userId = firebaseAuth.currentUser?.uid;
    if (userId != null) {
      final result = await getListeningProgress(event.surah.id);
      result.fold((failure) {}, (progress) {
        if (progress != null && !progress.isCompleted) {
          // Seek to saved position after loading
          Future.delayed(const Duration(milliseconds: 500), () {
            add(SeekToPositionEvent(progress.position));
          });
        }
      });
    }

    add(const PlaySurahAudioEvent());
  }

  Future<void> _onPlaySurah(
    PlaySurahAudioEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    final surah = state.selectedSurah;
    if (surah == null) return;

    emit(state.copyWith(isLoading: true, playbackError: null));
    _playRequestInFlight = true;
    _armLoadingWatchdog();
    try {
      await audioPlayerService
          .play(surah.audioUrl)
          .timeout(const Duration(seconds: 15));
      _startProgressSaving();
    } on TimeoutException {
      _cancelLoadingWatchdog();
      emit(
        state.copyWith(isLoading: false, playbackError: _playbackErrorMessage),
      );
    } catch (e) {
      _cancelLoadingWatchdog();
      emit(
        state.copyWith(isLoading: false, playbackError: _playbackErrorMessage),
      );
    } finally {
      _playRequestInFlight = false;
    }
  }

  Future<void> _onPause(
    PausePlaybackEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    _playRequestInFlight = false;
    _cancelLoadingWatchdog();
    await audioPlayerService.pause();
    // pause() may stop mid-buffer; clear spinner immediately rather than
    // waiting for a stream event that might never leave buffering.
    emit(state.copyWith(isLoading: false));
    _saveProgress();
  }

  Future<void> _onResume(
    ResumePlaybackEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    final surah = state.selectedSurah;
    // After a mid-load stop(), resume must re-play the URL — play() alone
    // on an idle/stopped source will not restart network buffering correctly.
    if (surah != null &&
        (audioPlayerService.processingState == ProcessingState.idle ||
            audioPlayerService.processingState == ProcessingState.completed)) {
      add(const PlaySurahAudioEvent());
      return;
    }

    emit(state.copyWith(isLoading: true, playbackError: null));
    _playRequestInFlight = true;
    _armLoadingWatchdog();
    try {
      await audioPlayerService.resume();
      _startProgressSaving();
    } catch (_) {
      _cancelLoadingWatchdog();
      emit(
        state.copyWith(isLoading: false, playbackError: _playbackErrorMessage),
      );
    } finally {
      _playRequestInFlight = false;
    }
  }

  Future<void> _onSeek(
    SeekToPositionEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    await audioPlayerService.seek(event.position);
  }

  void _onSearch(
    SearchAudioLibraryEvent event,
    Emitter<AudioLibraryState> emit,
  ) {
    print('[AudioLibraryBloc] Searching for: "${event.query}"');
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onSelectReciter(
    SelectReciterEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    final normalizedId = event.reciterId != null
        ? normalizeReciterId(event.reciterId)
        : null;
    emit(state.copyWith(selectedReciterId: normalizedId));

    final prefs = await SharedPreferences.getInstance();
    if (event.reciterId != null) {
      await prefs.setString(
        _lastReciterKey,
        normalizeReciterId(event.reciterId),
      );
    } else {
      await prefs.remove(_lastReciterKey);
    }
  }

  void _onUpdatePlaybackState(
    _UpdatePlaybackStateEvent event,
    Emitter<AudioLibraryState> emit,
  ) {
    final wasLoading = state.isLoading;
    emit(state.copyWith(isLoading: event.isLoading));
    if (event.isLoading) {
      // Arm only on rising edge so stream spam doesn't reset the timeout.
      if (!wasLoading) _armLoadingWatchdog();
    } else {
      _cancelLoadingWatchdog();
    }
  }

  Future<void> _onForceStopLoading(
    _ForceStopLoadingEvent event,
    Emitter<AudioLibraryState> emit,
  ) async {
    _playRequestInFlight = false;
    _cancelLoadingWatchdog();
    try {
      await audioPlayerService.stop();
    } catch (_) {}
    emit(
      state.copyWith(
        isLoading: false,
        isPlaying: false,
        playbackError: _playbackErrorMessage,
      ),
    );
  }

  void _armLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = Timer(_loadingWatchdogTimeout, () {
      if (!isClosed && state.isLoading) {
        add(const _ForceStopLoadingEvent());
      }
    });
  }

  void _cancelLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = null;
  }

  void _onUpdatePosition(
    _UpdatePositionEvent event,
    Emitter<AudioLibraryState> emit,
  ) {
    emit(state.copyWith(position: event.position));
  }

  void _onUpdateDuration(
    _UpdateDurationEvent event,
    Emitter<AudioLibraryState> emit,
  ) {
    emit(state.copyWith(duration: event.duration));
  }

  void _onUpdateIsPlaying(
    _UpdateIsPlayingEvent event,
    Emitter<AudioLibraryState> emit,
  ) {
    emit(state.copyWith(isPlaying: event.isPlaying));
    if (!event.isPlaying) {
      _saveProgress();
    }
  }

  void _startProgressSaving() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    final surah = state.selectedSurah;
    final userId = firebaseAuth.currentUser?.uid;
    if (surah == null || userId == null) return;

    final isCompleted =
        state.duration != null &&
        state.position.inSeconds >= state.duration!.inSeconds - 2;

    final progress = ListeningProgressEntity(
      id: '',
      userId: userId,
      surahAudioId: surah.id,
      position: state.position,
      lastUpdated: DateTime.now(),
      isCompleted: isCompleted,
    );

    await saveListeningProgress(progress);
  }

  @override
  Future<void> close() {
    _playerStateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _playingSub.cancel();
    _progressSaveTimer?.cancel();
    _cancelLoadingWatchdog();
    _saveProgress();
    audioPlayerService.dispose();
    return super.close();
  }

  List<String> _prependUnique(List<String> ids, String id) {
    return [id, ...ids.where((existing) => existing != id)].take(25).toList();
  }
}

// Internal events
class _UpdatePlaybackStateEvent extends AudioLibraryEvent {
  final bool isLoading;

  const _UpdatePlaybackStateEvent({required this.isLoading});

  @override
  List<Object?> get props => [isLoading];
}

class _UpdatePositionEvent extends AudioLibraryEvent {
  final Duration position;

  const _UpdatePositionEvent(this.position);

  @override
  List<Object?> get props => [position];
}

class _UpdateDurationEvent extends AudioLibraryEvent {
  final Duration? duration;

  const _UpdateDurationEvent(this.duration);

  @override
  List<Object?> get props => [duration];
}

class _UpdateIsPlayingEvent extends AudioLibraryEvent {
  final bool isPlaying;

  const _UpdateIsPlayingEvent(this.isPlaying);

  @override
  List<Object?> get props => [isPlaying];
}

/// Fired by the loading watchdog when buffering/loading exceeds the timeout.
class _ForceStopLoadingEvent extends AudioLibraryEvent {
  const _ForceStopLoadingEvent();
}
