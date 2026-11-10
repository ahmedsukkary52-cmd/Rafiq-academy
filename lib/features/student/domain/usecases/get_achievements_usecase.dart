import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/achievement_entity.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class GetAchievementsUseCase
    extends UseCase<List<AchievementEntity>, StudentUidParams> {
  final StudentRepository repository;

  GetAchievementsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AchievementEntity>>> call(
    StudentUidParams params,
  ) => repository.getAchievements(params.uid);
}
