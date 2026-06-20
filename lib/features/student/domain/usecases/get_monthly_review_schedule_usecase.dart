import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/review_schedule_entity.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class GetMonthlyReviewScheduleUseCase
    extends UseCase<List<ReviewScheduleEntity>, MonthlyScheduleParams> {
  final StudentRepository repository;

  GetMonthlyReviewScheduleUseCase(this.repository);

  @override
  Future<Either<Failure, List<ReviewScheduleEntity>>> call(
    MonthlyScheduleParams params,
  ) => repository.getMonthlyReviewSchedule(
    studentId: params.studentId,
    month: params.month,
  );
}
