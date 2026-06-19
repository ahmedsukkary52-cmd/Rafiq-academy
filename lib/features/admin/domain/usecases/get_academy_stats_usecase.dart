import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/academy_stats_entity.dart';
import '../repositories/admin_repository.dart';

class GetAcademyStatsUseCase extends UseCase<AcademyStatsEntity, NoParams> {
  final AdminRepository repository;

  GetAcademyStatsUseCase(this.repository);

  @override
  Future<Either<Failure, AcademyStatsEntity>> call(NoParams params) =>
      repository.getAcademyStats();
}
