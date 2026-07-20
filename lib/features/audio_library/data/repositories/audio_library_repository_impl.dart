import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/audio_entities.dart';
import '../../domain/repositories/audio_library_repository.dart';
import '../datasources/audio_library_remote_datasource.dart';
import '../models/audio_models.dart';

@LazySingleton(as: AudioLibraryRepository)
class AudioLibraryRepositoryImpl implements AudioLibraryRepository {
  final AudioLibraryRemoteDatasource remoteDatasource;
  final FirebaseAuth firebaseAuth;

  AudioLibraryRepositoryImpl({
    required this.remoteDatasource,
    required this.firebaseAuth,
  });

  String get _userId {
    final uid = firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw const ServerException('User not authenticated');
    }
    return uid;
  }

  @override
  Future<Either<Failure, List<ReciterEntity>>> getReciters() async {
    try {
      print('[Repository] Getting reciters');
      // Get all reciters
      final reciters = await remoteDatasource.getReciters();
      print(
        '[Repository] Got ${reciters.length} reciters from remote datasource',
      );
      // Get followed reciter IDs
      final followedIds = await remoteDatasource.getFollowedReciterIds(_userId);
      print('[Repository] Followed reciter IDs: $followedIds');

      // Just update the isFollowing flag
      final recitersWithFollowing = reciters.map((reciter) {
        return reciter.copyWith(isFollowing: followedIds.contains(reciter.id));
      }).toList();

      print(
        '[Repository] Returning ${recitersWithFollowing.length} reciters with isFollowing updated',
      );
      return Right(recitersWithFollowing);
    } on ServerException catch (e) {
      print('[Repository] Error getting reciters: $e');
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ReciterEntity>>> getFavoriteReciters() async {
    try {
      final reciters = await remoteDatasource.getFavoriteReciters(_userId);
      return Right(reciters);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleFollowReciter({
    required String reciterId,
    required bool isFollowing,
  }) async {
    try {
      await remoteDatasource.toggleFollowReciter(
        userId: _userId,
        reciterId: reciterId,
        isFollowing: isFollowing,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<SurahAudioEntity>>> getSurahAudios({
    String? reciterId,
  }) async {
    try {
      final audios = await remoteDatasource.getSurahAudios(
        reciterId: reciterId,
      );
      return Right(audios);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, SurahAudioEntity?>> getSurahAudioById(
    String id,
  ) async {
    try {
      final audio = await remoteDatasource.getSurahAudioById(id);
      return Right(audio);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveListeningProgress({
    required ListeningProgressEntity progress,
  }) async {
    try {
      await remoteDatasource.saveListeningProgress(
        ListeningProgressModel.fromEntity(progress),
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ListeningProgressEntity?>> getListeningProgress(
    String surahAudioId,
  ) async {
    try {
      final progress = await remoteDatasource.getListeningProgress(
        userId: _userId,
        surahAudioId: surahAudioId,
      );
      return Right(progress);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, SurahAudioEntity?>> getContinueListening() async {
    try {
      final audio = await remoteDatasource.getContinueListening(_userId);
      return Right(audio);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
