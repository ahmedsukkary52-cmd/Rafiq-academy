import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/audio_entities.dart';

abstract class AudioLibraryRepository {
  /// Get all reciters
  Future<Either<Failure, List<ReciterEntity>>> getReciters();

  /// Get favorite reciters for current user
  Future<Either<Failure, List<ReciterEntity>>> getFavoriteReciters();

  /// Toggle follow/unfollow reciter
  Future<Either<Failure, Unit>> toggleFollowReciter({
    required String reciterId,
    required bool isFollowing,
  });

  /// Get all surah audio files, optionally filtered by reciter
  Future<Either<Failure, List<SurahAudioEntity>>> getSurahAudios({
    String? reciterId,
  });

  /// Get surah audio by ID
  Future<Either<Failure, SurahAudioEntity?>> getSurahAudioById(String id);

  /// Save/Update listening progress for a surah
  Future<Either<Failure, Unit>> saveListeningProgress({
    required ListeningProgressEntity progress,
  });

  /// Get listening progress for a surah (for current user)
  Future<Either<Failure, ListeningProgressEntity?>> getListeningProgress(
    String surahAudioId,
  );

  /// Get latest/continue listening surah (for featured card)
  Future<Either<Failure, SurahAudioEntity?>> getContinueListening();
}
