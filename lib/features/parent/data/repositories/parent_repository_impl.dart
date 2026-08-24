import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_household.dart';
import '../../domain/parent_wallet.dart';
import '../../domain/repositories/parent_repositories.dart';
import '../data_source/parent_remote_datasource.dart';
import '../models/parent_model.dart';

@LazySingleton(as: ParentRepository)
class ParentRepositoryImpl implements ParentRepository {
  final ParentRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const ParentRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getChildrenIds(parentId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getParentIdsByStudentIds(studentIds));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getWeeklyReport(
          studentId: studentId,
          weekStart: weekStart,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<PaymentEntity>>> getPayments(
    String parentId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getPayments(parentId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.submitAbsenceRequest(
        AbsenceRequestModel(
          id: request.id,
          studentId: request.studentId,
          halaqaId: request.halaqaId,
          requestedBy: request.requestedBy,
          date: request.date,
          reason: request.reason,
          status: request.status,
          reviewedBy: request.reviewedBy,
        ),
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForParent(String parentId) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getAbsenceRequestsForParent(parentId),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ParentHalaqaOption>>> getHalaqatForStudent(
    String studentId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final rows = await remoteDatasource.getHalaqatForStudent(studentId);
      return Right([
        for (final row in rows) ParentHalaqaOption(id: row.id, name: row.name),
      ]);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  ) {
    // TODO: implement real-time stream لما نحتاجه في الـ UI
    return const Stream.empty();
  }

  @override
  Future<Either<Failure, PaymentInitiationEntity>> initiatePayment(
    String paymentId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final initiation = await remoteDatasource.initiatePayment(paymentId);
      return Right(initiation);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ParentWalletEntity>> getWallet(String parentId) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getWallet(parentId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> payPaymentFromWallet({
    required String parentId,
    required String paymentId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.payPaymentFromWallet(
        parentId: parentId,
        paymentId: paymentId,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      final message = e.message;
      if (message.contains('رصيد') ||
          message.contains('بالفعل') ||
          message.contains('غير مرتبطة') ||
          message.contains('غير صالح')) {
        return Left(ValidationFailure(message));
      }
      return Left(ServerFailure(message));
    }
  }

  @override
  Future<Either<Failure, Unit>> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.submitPaymentProof(
        parentId: parentId,
        paymentId: paymentId,
        localFilePath: localFilePath,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      final message = e.message;
      if (message.contains('بالفعل') ||
          message.contains('غير مرتبطة') ||
          message.contains('غير صالح') ||
          message.contains('غير موجود') ||
          message.contains('فارغ') ||
          message.contains('أكبر من')) {
        return Left(ValidationFailure(message));
      }
      return Left(ServerFailure(message));
    }
  }

  @override
  Future<Either<Failure, ParentHousehold>> getHousehold({
    required String parentId,
    required List<String> childrenIds,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getHousehold(
          parentId: parentId,
          childrenIds: childrenIds,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ParentAttendanceMark>>> getAttendanceMarks({
    required String studentId,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getAttendanceMarks(
          studentId: studentId,
          start: start,
          endExclusive: endExclusive,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
