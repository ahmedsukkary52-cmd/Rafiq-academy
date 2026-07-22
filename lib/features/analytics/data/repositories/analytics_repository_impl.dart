import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/analytics_entities.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_remote_datasource.dart';

@LazySingleton(as: AnalyticsRepository)
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const AnalyticsRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, HalaqaAnalyticsEntity>> getHalaqaAnalytics({
    required String halaqaId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final result = await remoteDatasource.getHalaqaAnalytics(
        halaqaId: halaqaId,
        from: from,
        to: to,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AtRiskStudentEntity>>> getAtRiskStudents(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final result = await remoteDatasource.getAtRiskStudents(halaqaId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<TopStudentEntity>>> getTopStudents({
    required String halaqaId,
    int limit = 5,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final result = await remoteDatasource.getTopStudents(
        halaqaId: halaqaId,
        limit: limit,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
