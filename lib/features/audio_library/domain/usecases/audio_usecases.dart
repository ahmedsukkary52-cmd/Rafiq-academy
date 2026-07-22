import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/audio_entities.dart';
import '../repositories/audio_library_repository.dart';
import '../../../../core/error/failure.dart';

/// Use Case: Get All Reciters
@injectable
class GetAllRecitersUseCase extends UseCase<List<ReciterEntity>, NoParams> {
  final AudioLibraryRepository repository;

  GetAllRecitersUseCase(this.repository);

  @override
  Future<Either<Failure, List<ReciterEntity>>> call(NoParams params) {
    return repository.getReciters();
  }
}

/// Use Case: Get Favorite Reciters
@injectable
class GetFavoriteRecitersUseCase
    extends UseCase<List<ReciterEntity>, NoParams> {
  final AudioLibraryRepository repository;

  GetFavoriteRecitersUseCase(this.repository);

  @override
  Future<Either<Failure, List<ReciterEntity>>> call(NoParams params) {
    return repository.getFavoriteReciters();
  }
}

/// Use Case: Toggle Follow Reciter
@injectable
class ToggleFollowReciterUseCase extends UseCase<Unit, ToggleFollowParams> {
  final AudioLibraryRepository repository;

  ToggleFollowReciterUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ToggleFollowParams params) {
    return repository.toggleFollowReciter(
      reciterId: params.reciterId,
      isFollowing: params.isFollowing,
    );
  }
}

class ToggleFollowParams {
  final String reciterId;
  final bool isFollowing;

  ToggleFollowParams({required this.reciterId, required this.isFollowing});
}

/// Use Case: Get Surah Audios
@injectable
class GetSurahAudiosUseCase
    extends UseCase<List<SurahAudioEntity>, GetSurahAudiosParams> {
  final AudioLibraryRepository repository;

  GetSurahAudiosUseCase(this.repository);

  @override
  Future<Either<Failure, List<SurahAudioEntity>>> call(
    GetSurahAudiosParams params,
  ) {
    return repository.getSurahAudios(reciterId: params.reciterId);
  }
}

class GetSurahAudiosParams {
  final String? reciterId;

  GetSurahAudiosParams({this.reciterId});
}

/// Use Case: Save Listening Progress
@injectable
class SaveListeningProgressUseCase
    extends UseCase<Unit, ListeningProgressEntity> {
  final AudioLibraryRepository repository;

  SaveListeningProgressUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ListeningProgressEntity params) {
    return repository.saveListeningProgress(progress: params);
  }
}

/// Use Case: Get Listening Progress
@injectable
class GetListeningProgressUseCase
    extends UseCase<ListeningProgressEntity?, String> {
  final AudioLibraryRepository repository;

  GetListeningProgressUseCase(this.repository);

  @override
  Future<Either<Failure, ListeningProgressEntity?>> call(String surahAudioId) {
    return repository.getListeningProgress(surahAudioId);
  }
}

/// Use Case: Get Continue Listening
@injectable
class GetContinueListeningUseCase extends UseCase<SurahAudioEntity?, NoParams> {
  final AudioLibraryRepository repository;

  GetContinueListeningUseCase(this.repository);

  @override
  Future<Either<Failure, SurahAudioEntity?>> call(NoParams params) {
    return repository.getContinueListening();
  }
}
