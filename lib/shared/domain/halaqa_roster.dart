import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failure.dart';
import '../../core/usecases/usecases.dart';
import 'halaqa_students_summary_entity.dart';

/// Read side of a Halaqa roster (`halaqat.studentIds` + `studentProfiles`),
/// listed by the Halaqa's teacher, its supervisor and the staff profile pages.
abstract interface class HalaqaRosterReader {
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  );
}

class HalaqaStudentsParams extends Equatable {
  final String halaqaId;

  const HalaqaStudentsParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

@lazySingleton
class GetHalaqaStudentsUseCase
    extends UseCase<List<HalaqaStudentSummaryEntity>, HalaqaStudentsParams> {
  final HalaqaRosterReader repository;
  GetHalaqaStudentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> call(
    HalaqaStudentsParams params,
  ) => repository.getHalaqaStudents(params.halaqaId);
}
