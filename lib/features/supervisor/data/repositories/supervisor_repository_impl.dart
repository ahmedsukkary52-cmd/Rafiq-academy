import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/payment_review_params.dart';
import '../../domain/entities/supervisor_report_entity.dart';
import '../../domain/repositories/parent_repository.dart';
import '../data_sources/supervisor_remote_datasource.dart';

@LazySingleton(as: SupervisorRepository)
class SupervisorRepositoryImpl implements SupervisorRepository {
  final SupervisorRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const SupervisorRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getSupervisedHalaqat(
    String supervisorId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getSupervisedHalaqat(supervisorId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> issueAchievement(
    AchievementIssueEntity data,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.issueAchievement(data);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> submitReport(
    SupervisorReportEntity report,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.submitReport(report);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> admitStudentToHalaqa({
    required String supervisorId,
    required String halaqaId,
    required String studentId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.admitStudentToHalaqa(
        supervisorId: supervisorId,
        halaqaId: halaqaId,
        studentId: studentId,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> transferStudentBetweenHalaqat({
    required String supervisorId,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.transferStudentBetweenHalaqat(
        supervisorId: supervisorId,
        studentId: studentId,
        sourceHalaqaId: sourceHalaqaId,
        targetHalaqaId: targetHalaqaId,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> getUserDisplayNames(
    List<String> userIds,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getUserDisplayNames(userIds));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getAbsenceRequestsForHalaqatOnDate(
          halaqaIds: halaqaIds,
          date: date,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PaymentEntity>>> getPaymentsForStudents({
    required String supervisorId,
    required List<String> studentIds,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getPaymentsForStudents(
          supervisorId: supervisorId,
          studentIds: studentIds,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> reviewPaymentProof(
    PaymentReviewParams params,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.reviewPaymentProof(params);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
