import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/parent_entities.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class GetWeeklyReportUseCase
    extends UseCase<WeeklyReportEntity, WeeklyReportParams> {
  final ParentRepository repository;

  GetWeeklyReportUseCase(this.repository);

  @override
  Future<Either<Failure, WeeklyReportEntity>> call(
    WeeklyReportParams params,
  ) async {
    final parentId = params.parentId.trim();
    final studentId = params.studentId.trim();
    if (parentId.isEmpty) {
      return const Left(ValidationFailure('معرّف ولي الأمر مطلوب'));
    }
    if (studentId.isEmpty) {
      return const Left(ValidationFailure('معرّف الطالب مطلوب'));
    }

    final childrenEither = await repository.getChildrenIds(parentId);
    final childrenFailure = childrenEither.fold<Failure?>(
      (l) => l,
      (_) => null,
    );
    if (childrenFailure != null) return Left(childrenFailure);

    final children = childrenEither
        .getOrElse((_) => const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (!children.contains(studentId)) {
      return const Left(
        ValidationFailure('لا يمكن عرض تقرير طالب غير مرتبط بولي الأمر'),
      );
    }

    return repository.getWeeklyReport(
      studentId: studentId,
      weekStart: params.weekStart,
    );
  }
}
