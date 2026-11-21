import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/usecases/usecases.dart';
import 'package:rafiq_academy/features/audio_library/data/services/audio_player_service.dart';
import 'package:rafiq_academy/features/audio_library/domain/entities/audio_entities.dart';
import 'package:rafiq_academy/features/audio_library/domain/usecases/audio_usecases.dart';
import 'package:rafiq_academy/features/audio_library/presentation/bloc/audio_bloc.dart';
import 'package:rafiq_academy/features/audio_library/presentation/bloc/audio_event.dart';

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
}

class _Player extends AudioPlayerService {
  final states = StreamController<PlayerState>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration?>.broadcast();
  final playingController = StreamController<bool>.broadcast();
  final urls = <String>[];
  final seeks = <Duration>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  bool disposed = false;
  bool failPlay = false;
  ProcessingState currentProcessingState = ProcessingState.idle;

  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Stream<bool> get playingStream => playingController.stream;
  @override
  ProcessingState get processingState => currentProcessingState;

  @override
  Future<void> play(String url) async {
    if (failPlay) throw StateError('load failed');
    urls.add(url);
    playCalls++;
    currentProcessingState = ProcessingState.ready;
    states.add(PlayerState(true, ProcessingState.ready));
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    states.add(PlayerState(false, ProcessingState.ready));
    playingController.add(false);
  }

  @override
  Future<void> resume() => play('resume://loaded');

  @override
  Future<void> stop() async {
    stopCalls++;
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> dispose() async {
    disposed = true;
    await states.close();
    await positions.close();
    await durations.close();
    await playingController.close();
  }

  void complete() {
    currentProcessingState = ProcessingState.completed;
    states.add(PlayerState(false, ProcessingState.completed));
    playingController.add(false);
  }
}

class _Reciters extends Fake implements GetAllRecitersUseCase {
  @override
  Future<Either<Failure, List<ReciterEntity>>> call(NoParams p) async =>
      const Right([]);
}

class _Favorites extends Fake implements GetFavoriteRecitersUseCase {
  @override
  Future<Either<Failure, List<ReciterEntity>>> call(NoParams p) async =>
      const Right([]);
}

class _Follow extends Fake implements ToggleFollowReciterUseCase {
  @override
  Future<Either<Failure, Unit>> call(ToggleFollowParams p) async =>
      const Right(unit);
}

class _Audios extends Fake implements GetSurahAudiosUseCase {
  @override
  Future<Either<Failure, List<SurahAudioEntity>>> call(
    GetSurahAudiosParams p,
  ) async => const Right([]);
}

class _Continue extends Fake implements GetContinueListeningUseCase {
  @override
  Future<Either<Failure, SurahAudioEntity?>> call(NoParams p) async =>
      const Right(null);
}

class _SaveProgress extends Fake implements SaveListeningProgressUseCase {
  @override
  Future<Either<Failure, Unit>> call(ListeningProgressEntity p) async =>
      const Right(unit);
}

class _GetProgress extends Fake implements GetListeningProgressUseCase {
  @override
  Future<Either<Failure, ListeningProgressEntity?>> call(String id) async =>
      const Right(null);
}

const _one = SurahAudioEntity(
  id: 'one',
  surahNumber: 1,
  surahName: 'الفاتحة',
  reciterId: null,
  reciterName: 'قارئ',
  audioUrl: 'https://example.test/one.mp3',
  duration: Duration(seconds: 10),
  pageCount: 1,
);

const _two = SurahAudioEntity(
  id: 'two',
  surahNumber: 2,
  surahName: 'البقرة',
  reciterId: null,
  reciterName: 'قارئ',
  audioUrl: 'https://example.test/two.mp3',
  duration: Duration(seconds: 20),
  pageCount: 2,
);

AudioLibraryBloc _bloc(_Player player) => AudioLibraryBloc(
  getAllReciters: _Reciters(),
  getFavoriteReciters: _Favorites(),
  toggleFollowReciter: _Follow(),
  getSurahAudios: _Audios(),
  getContinueListening: _Continue(),
  saveListeningProgress: _SaveProgress(),
  getListeningProgress: _GetProgress(),
  audioPlayerService: player,
  firebaseAuth: _Auth(),
);

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _select(AudioLibraryBloc bloc, SurahAudioEntity surah) async {
  bloc.add(SelectSurahAudioEvent(surah));
  await _settle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial state is stopped', () async {
    final player = _Player();
    final bloc = _bloc(player);
    addTearDown(bloc.close);

    expect(bloc.state.selectedSurah, isNull);
    expect(bloc.state.isPlaying, isFalse);
    expect(bloc.state.isLoading, isFalse);
  });

  test('playing and paused state follows the player streams', () async {
    final player = _Player();
    final bloc = _bloc(player);
    addTearDown(bloc.close);

    await _select(bloc, _one);
    expect(bloc.state.isPlaying, isTrue);
    bloc.add(const PausePlaybackEvent());
    await _settle();
    expect(bloc.state.isPlaying, isFalse);
    expect(player.pauseCalls, 1);
  });

  test('completion resets UI position and reuses the player', () async {
    final player = _Player();
    final bloc = _bloc(player);
    addTearDown(bloc.close);

    await _select(bloc, _one);
    player.positions.add(const Duration(seconds: 9));
    await _settle();
    player.complete();
    await _settle();

    expect(bloc.state.isPlaying, isFalse);
    expect(bloc.state.position, Duration.zero);
    expect(player.seeks, contains(Duration.zero));
    expect(player.disposed, isFalse);

    bloc.add(const ResumePlaybackEvent());
    await _settle();
    expect(player.playCalls, 2);
    expect(player.disposed, isFalse);
  });

  test('track changes load the newly selected track', () async {
    final player = _Player();
    final bloc = _bloc(player);
    addTearDown(bloc.close);

    await _select(bloc, _one);
    await _select(bloc, _two);

    expect(bloc.state.selectedSurah, _two);
    expect(player.urls, [_one.audioUrl, _two.audioUrl]);
  });

  test('playback errors are surfaced and stop playing state', () async {
    final player = _Player()..failPlay = true;
    final bloc = _bloc(player);
    addTearDown(bloc.close);

    await _select(bloc, _one);

    expect(bloc.state.isPlaying, isFalse);
    expect(bloc.state.playbackError, isNotNull);
  });

  test(
    'close cancels subscriptions and does not dispose singleton player',
    () async {
      final player = _Player();
      final bloc = _bloc(player);
      expect(player.states.hasListener, isTrue);
      expect(player.positions.hasListener, isTrue);
      expect(player.durations.hasListener, isTrue);
      expect(player.playingController.hasListener, isTrue);

      await bloc.close();

      expect(player.states.hasListener, isFalse);
      expect(player.positions.hasListener, isFalse);
      expect(player.durations.hasListener, isFalse);
      expect(player.playingController.hasListener, isFalse);
      expect(player.stopCalls, 1);
      expect(player.disposed, isFalse);
      await player.dispose();
    },
  );
}
