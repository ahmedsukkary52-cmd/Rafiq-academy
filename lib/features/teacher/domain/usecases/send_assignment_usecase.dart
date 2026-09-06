import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../repositories/teacher_repository.dart';
import '../teacher_halaqa_ownership.dart';

@lazySingleton
class SendAssignmentUseCase
    extends UseCase<AcademyEventPublication, SendAssignmentParams> {
  final TeacherRepository repository;
  SendAssignmentUseCase(this.repository);

  @override
  Future<Either<Failure, AcademyEventPublication>> call(
    SendAssignmentParams params,
  ) async {
    final ownership = await ensureTeacherOwnsHalaqa(
      repository: repository,
      teacherId: params.teacherId,
      halaqaId: params.halaqaId,
    );
    final blocked = ownership.fold<Failure?>((l) => l, (_) => null);
    if (blocked != null) return Left(blocked);

    return repository.sendAssignment(
      halaqaId: params.halaqaId,
      newMemorizationRange: params.newMemorizationRange,
      reviewRange: params.reviewRange,
      dueDate: params.dueDate,
      teacherId: params.teacherId,
    );
  }
}
