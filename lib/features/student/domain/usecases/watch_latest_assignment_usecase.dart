import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/assignment_entity.dart';
import '../repositories/student_repository.dart';

class WatchLatestAssignmentUseCase
    extends StreamUseCase<AssignmentEntity?, StudentUidParams> {
  final StudentRepository repository;

  WatchLatestAssignmentUseCase(this.repository);

  @override
  Stream<Either<Failure, AssignmentEntity?>> call(StudentUidParams params) =>
      repository.watchLatestAssignment(params.uid);
}

class StudentUidParams extends Equatable {
  final String uid;

  const StudentUidParams(this.uid);

  @override
  List<Object?> get props => [uid];
}

class MonthlyScheduleParams extends Equatable {
  final String studentId;
  final DateTime month;

  const MonthlyScheduleParams({required this.studentId, required this.month});

  @override
  List<Object?> get props => [studentId, month];
}

class HalaqaIdParams extends Equatable {
  final String halaqaId;

  const HalaqaIdParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}
