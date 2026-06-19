import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/teacher_repository.dart';

class SendAssignmentUseCase extends UseCase<Unit, SendAssignmentParams> {
  final TeacherRepository repository;

  SendAssignmentUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SendAssignmentParams params) =>
      repository.sendAssignment(
        halaqaId: params.halaqaId,
        newMemorizationRange: params.newMemorizationRange,
        reviewRange: params.reviewRange,
        dueDate: params.dueDate,
        teacherId: params.teacherId,
      );
}
