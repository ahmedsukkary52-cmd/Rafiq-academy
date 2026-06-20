import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/achievement_issue_entity.dart';
import '../repositories/parent_repository.dart';

@lazySingleton
class IssueAchievementUseCase extends UseCase<Unit, AchievementIssueEntity> {
  final SupervisorRepository repository;

  IssueAchievementUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AchievementIssueEntity params) =>
      repository.issueAchievement(params);
}
