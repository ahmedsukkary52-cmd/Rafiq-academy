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
  Future<Either<Failure, WeeklyReportEntity>> call(WeeklyReportParams params) =>
      repository.getWeeklyReport(
        studentId: params.studentId,
        weekStart: params.weekStart,
      );
}
