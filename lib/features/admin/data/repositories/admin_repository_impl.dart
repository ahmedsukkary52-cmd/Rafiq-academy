import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/academy_stats_entity.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/financial_summary_entity.dart';
import '../../domain/entities/teacher_activity_entity.dart';
import '../../domain/entities/teacher_management_entity.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

@LazySingleton(as: AdminRepository)
class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const AdminRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, AcademyStatsEntity>> getAcademyStats() async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getAcademyStats());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, FinancialSummaryEntity>> getFinancialSummary() async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getFinancialSummary());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> approveNewStudent({
    required String studentId,
    required String halaqaId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.approveNewStudent(
        studentId: studentId,
        halaqaId: halaqaId,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleAccountStatus({
    required String uid,
    required bool isActive,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.toggleAccountStatus(uid: uid, isActive: isActive);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ComplaintEntity>>> getComplaints() async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getComplaints());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> respondToComplaint({
    required String complaintId,
    required String response,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.respondToComplaint(
        complaintId: complaintId,
        response: response,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendBroadcastNotification({
    required String title,
    required String body,
    required String targetRole,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.sendBroadcastNotification(
        title: title,
        body: body,
        targetRole: targetRole,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<
      Either<Failure, List<TeacherManagementEntity>>> getAllTeachers() async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getAllTeachers());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateTeacherPerformance({
    required String teacherId,
    required double rating,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.updateTeacherPerformance(
        teacherId: teacherId,
        rating: rating,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateTeacherQuota({
    required String teacherId,
    required int weeklyQuota,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.updateTeacherQuota(
        teacherId: teacherId,
        weeklyQuota: weeklyQuota,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TeacherActivityEntity>> getTeacherActivityLog({
    required String teacherId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getTeacherActivityLog(
        teacherId: teacherId,
        from: from,
        to: to,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}