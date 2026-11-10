import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/assignment_entity.dart';
import '../../../../shared/domain/id_params.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class WatchLatestAssignmentUseCase
    extends StreamUseCase<AssignmentEntity?, StudentUidParams> {
  final StudentRepository repository;

  WatchLatestAssignmentUseCase(this.repository);

  @override
  Stream<Either<Failure, AssignmentEntity?>> call(StudentUidParams params) =>
      repository.watchLatestAssignment(params.uid);
}

class MonthlyScheduleParams extends Equatable {
  final String studentId;
  final DateTime month;

  const MonthlyScheduleParams({required this.studentId, required this.month});

  @override
  List<Object?> get props => [studentId, month];
}
