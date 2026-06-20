import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/parent_entities.dart';
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
  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  ) {
    // TODO: implement real-time stream لما نحتاجه في الـ UI
    return const Stream.empty();
  }
}
