import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'repositories/teacher_repository.dart';

/// Shared teacher↔halaqa ownership check for write use cases.
Future<Either<Failure, Unit>> ensureTeacherOwnsHalaqa({
  required TeacherRepository repository,
  required String teacherId,
  required String halaqaId,
}) async {
  final tid = teacherId.trim();
  final hid = halaqaId.trim();
  if (tid.isEmpty) {
    return const Left(ValidationFailure('معرّف المعلم مطلوب'));
  }
  if (hid.isEmpty) {
    return const Left(ValidationFailure('معرّف الحلقة مطلوب'));
  }

  final owned = await repository.getTeacherHalaqat(tid);
  final ownedFailure = owned.fold<Failure?>((l) => l, (_) => null);
  if (ownedFailure != null) return Left(ownedFailure);

  final authorized = owned
      .getOrElse((_) => const [])
      .any((h) => h.id.trim() == hid);
  if (!authorized) {
    return const Left(
      ValidationFailure('لا يمكن تنفيذ العملية على حلقة غير مسندة للمعلم'),
    );
  }
  return const Right(unit);
}
