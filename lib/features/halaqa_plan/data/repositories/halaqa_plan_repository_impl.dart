import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/halaqa_plan.dart';
import '../../domain/repositories/halaqa_plan_repository.dart';
import '../datasources/halaqa_plan_remote_datasource.dart';

@LazySingleton(as: HalaqaPlanRepository)
class HalaqaPlanRepositoryImpl implements HalaqaPlanRepository {
  final HalaqaPlanRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const HalaqaPlanRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, HalaqaPlan>> getStudentPlan({
    required String studentId,
    String? halaqaId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final assignments = await remoteDatasource.getLessonAssignments(
        studentId,
      );
      return Right(HalaqaPlan.fromAssignments(assignments, halaqaId: halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
