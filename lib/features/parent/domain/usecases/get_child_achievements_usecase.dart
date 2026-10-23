import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/entities/achievement_entity.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../repositories/parent_repositories.dart';

/// Parent view of one linked child's achievements. The callable resolves the
/// parent from the auth token and rejects children not in their profile.
@lazySingleton
class GetChildAchievementsUseCase
    extends UseCase<List<AchievementEntity>, StudentUidParams> {
  final ParentRepository repository;

  GetChildAchievementsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AchievementEntity>>> call(
    StudentUidParams params,
  ) async {
    final studentId = params.uid.trim();
    if (studentId.isEmpty) {
      return const Left(ValidationFailure('معرّف الطالب مطلوب'));
    }
    return repository.getChildAchievements(studentId);
  }
}
