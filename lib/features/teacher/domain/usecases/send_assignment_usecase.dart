import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../repositories/teacher_repository.dart';

@lazySingleton
class SendAssignmentUseCase
    extends UseCase<AcademyEventPublication, SendAssignmentParams> {
  final TeacherRepository repository;
  SendAssignmentUseCase(this.repository);

  @override
  Future<Either<Failure, AcademyEventPublication>> call(
    SendAssignmentParams params,
  ) => repository.sendAssignment(
    halaqaId: params.halaqaId,
    newMemorizationRange: params.newMemorizationRange,
    reviewRange: params.reviewRange,
    dueDate: params.dueDate,
    teacherId: params.teacherId,
  );
}
