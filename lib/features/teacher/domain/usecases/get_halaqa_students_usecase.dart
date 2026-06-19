import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/halaqa_students_summary_entity.dart';
import '../repositories/teacher_repository.dart';

class GetHalaqaStudentsUseCase
    extends UseCase<List<HalaqaStudentSummaryEntity>, HalaqaStudentsParams> {
  final TeacherRepository repository;

  GetHalaqaStudentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> call(
    HalaqaStudentsParams params,
  ) => repository.getHalaqaStudents(params.halaqaId);
}
