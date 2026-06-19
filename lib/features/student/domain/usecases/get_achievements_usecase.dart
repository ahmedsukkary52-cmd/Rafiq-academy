import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/achievement_entity.dart';
import '../repositories/student_repository.dart';

class GetAchievementsUseCase
    extends UseCase<List<AchievementEntity>, StudentUidParams> {
  final StudentRepository repository;

  GetAchievementsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AchievementEntity>>> call(
    StudentUidParams params,
  ) => repository.getAchievements(params.uid);
}
