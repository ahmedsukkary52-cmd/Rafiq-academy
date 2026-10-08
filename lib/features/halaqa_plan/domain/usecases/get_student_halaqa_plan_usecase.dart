import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/halaqa_plan.dart';
import '../repositories/halaqa_plan_repository.dart';

class StudentHalaqaPlanParams extends Equatable {
  final String studentId;
  final String? halaqaId;

  const StudentHalaqaPlanParams({required this.studentId, this.halaqaId});

  @override
  List<Object?> get props => [studentId, halaqaId];
}

@lazySingleton
class GetStudentHalaqaPlanUseCase
    extends UseCase<HalaqaPlan, StudentHalaqaPlanParams> {
  final HalaqaPlanRepository repository;
  GetStudentHalaqaPlanUseCase(this.repository);

  @override
  Future<Either<Failure, HalaqaPlan>> call(StudentHalaqaPlanParams params) {
    if (params.studentId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('تعذر تحديد الطالب')));
    }
    return repository.getStudentPlan(
      studentId: params.studentId.trim(),
      halaqaId: params.halaqaId,
    );
  }
}
