import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/analytics_entities.dart';
import '../repositories/analytics_repository.dart';

@lazySingleton
class GetHalaqaAnalyticsUseCase
    extends UseCase<HalaqaAnalyticsEntity, HalaqaAnalyticsParams> {
  final AnalyticsRepository repository;

  GetHalaqaAnalyticsUseCase(this.repository);

  @override
  Future<Either<Failure, HalaqaAnalyticsEntity>> call(
    HalaqaAnalyticsParams params,
  ) => repository.getHalaqaAnalytics(
    halaqaId: params.halaqaId,
    from: params.from,
    to: params.to,
  );
}

@lazySingleton
class GetAtRiskStudentsUseCase
    extends UseCase<List<AtRiskStudentEntity>, HalaqaIdParams> {
  final AnalyticsRepository repository;

  GetAtRiskStudentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AtRiskStudentEntity>>> call(
    HalaqaIdParams params,
  ) => repository.getAtRiskStudents(params.halaqaId);
}

@lazySingleton
class GetTopStudentsUseCase
    extends UseCase<List<TopStudentEntity>, TopStudentsParams> {
  final AnalyticsRepository repository;

  GetTopStudentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<TopStudentEntity>>> call(
    TopStudentsParams params,
  ) =>
      repository.getTopStudents(halaqaId: params.halaqaId, limit: params.limit);
}

// ── Params ────────────────────────────────────────────────────────────────────

class HalaqaAnalyticsParams extends Equatable {
  final String halaqaId;
  final DateTime from;
  final DateTime to;

  const HalaqaAnalyticsParams({
    required this.halaqaId,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [halaqaId, from, to];
}

class HalaqaIdParams extends Equatable {
  final String halaqaId;

  const HalaqaIdParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

class TopStudentsParams extends Equatable {
  final String halaqaId;
  final int limit;

  const TopStudentsParams({required this.halaqaId, this.limit = 5});

  @override
  List<Object?> get props => [halaqaId, limit];
}
