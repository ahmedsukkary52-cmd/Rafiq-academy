import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/achievement_entity.dart';
import '../../domain/entities/assignment_entity.dart';
import '../../domain/entities/halaqa_entity.dart';
import '../../domain/entities/recitation_record_entity.dart';
import '../../domain/entities/review_schedule_entity.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../../domain/repositories/student_repository.dart';
import '../data_source/student_remote_datasource.dart';

@LazySingleton(as: StudentRepository)
class StudentRepositoryImpl implements StudentRepository {
  final StudentRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const StudentRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, StudentProfileEntity>> getStudentProfile(
    String uid,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDatasource.getStudentProfile(uid);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ReviewScheduleEntity>>> getMonthlyReviewSchedule({
    required String studentId,
    required DateTime month,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDatasource.getMonthlyReviewSchedule(
        studentId: studentId,
        month: month,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDatasource.getRecitationRecords(studentId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AchievementEntity>>> getAchievements(
    String studentId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDatasource.getAchievements(studentId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, AssignmentEntity?>> getLatestAssignment(
    String studentId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDatasource.getLatestAssignment(studentId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, HalaqaEntity>> getStudentHalaqa(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDatasource.getStudentHalaqa(halaqaId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, AssignmentEntity?>> watchLatestAssignment(
    String studentId,
  ) {
    return remoteDatasource
        .watchLatestAssignment(studentId)
        .map<Either<Failure, AssignmentEntity?>>(
          (assignment) => Right(assignment),
        )
        .handleError((e) => Left(ServerFailure(e.toString())));
  }

  @override
  Future<Either<Failure, Unit>> updateAvatarSelection({
    required String studentId,
    required String avatarId,
    required List<String> unlockedAvatarIds,
    required int coins,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.updateAvatarSelection(
        studentId: studentId,
        avatarId: avatarId,
        unlockedAvatarIds: unlockedAvatarIds,
        coins: coins,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
