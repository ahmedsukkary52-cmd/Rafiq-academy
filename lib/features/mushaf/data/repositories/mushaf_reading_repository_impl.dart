import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/mushaf_position.dart';
import '../../domain/repositories/mushaf_reading_repository.dart';
import '../datasources/mushaf_reading_remote_datasource.dart';

@LazySingleton(as: MushafReadingRepository)
class MushafReadingRepositoryImpl implements MushafReadingRepository {
  final MushafReadingRemoteDatasource remote;
  final NetworkInfo networkInfo;

  MushafReadingRepositoryImpl({
    required this.remote,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, MushafPosition?>> getLastRead(String studentId) async {
    try {
      // Allow offline legacy mirror / cached firestore via SDK; still try.
      final position = await remote.getLastRead(studentId);
      return Right(position);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveLastRead({
    required String studentId,
    required MushafPosition position,
  }) async {
    try {
      // Datasource always writes local mirror; Firestore when reachable.
      await remote.saveLastRead(studentId: studentId, position: position);
      return const Right(unit);
    } on ServerException catch (e) {
      // Local mirror may still have succeeded before Firestore threw.
      if (!await networkInfo.isConnected) {
        return const Right(unit);
      }
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
