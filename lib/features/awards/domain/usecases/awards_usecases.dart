import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/award_entities.dart';
import '../repositories/awards_repository.dart';

@lazySingleton
class GetAwardsStatsUseCase extends UseCase<AwardsStatsEntity, HalaqaIdParams> {
  final AwardsRepository repository;

  GetAwardsStatsUseCase(this.repository);

  @override
  Future<Either<Failure, AwardsStatsEntity>> call(HalaqaIdParams params) =>
      repository.getAwardsStats(params.halaqaId);
}

@lazySingleton
class GetGrantedAwardsUseCase
    extends UseCase<List<GrantedAwardEntity>, HalaqaIdParams> {
  final AwardsRepository repository;

  GetGrantedAwardsUseCase(this.repository);

  @override
  Future<Either<Failure, List<GrantedAwardEntity>>> call(
    HalaqaIdParams params,
  ) => repository.getGrantedAwards(params.halaqaId);
}

@lazySingleton
class GrantAwardUseCase extends UseCase<Unit, GrantedAwardEntity> {
  final AwardsRepository repository;

  GrantAwardUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(GrantedAwardEntity params) =>
      repository.grantAward(params);
}

@lazySingleton
class GenerateCertificatePdfUseCase
    extends UseCase<List<int>, CertificateDataEntity> {
  final AwardsRepository repository;

  GenerateCertificatePdfUseCase(this.repository);

  @override
  Future<Either<Failure, List<int>>> call(CertificateDataEntity params) =>
      repository.generateCertificatePdf(params);
}

// ── Params ────────────────────────────────────────────────────────────────────

class HalaqaIdParams extends Equatable {
  final String halaqaId;

  const HalaqaIdParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}
