import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/utils/absence_request_ids.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../entities/parent_entities.dart';
import '../repositories/parent_repositories.dart';

/// Submits an استئذان as **contextual information only** (W7 Pre-Slice).
///
/// - Normalizes calendar day via [AttendancePolicy.dayStart]
/// - Assigns deterministic id via [AbsenceRequestIds.documentId]
/// - Authorizes `requestedBy` → `studentId` via existing children list
/// - Never reads or writes `attendanceRecords` (D-W7-2 / D-W7-3)
@lazySingleton
class SubmitAbsenceRequestUseCase extends UseCase<Unit, AbsenceRequestEntity> {
  final ParentRepository repository;

  SubmitAbsenceRequestUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AbsenceRequestEntity params) async {
    final studentId = params.studentId.trim();
    final halaqaId = params.halaqaId.trim();
    final requestedBy = params.requestedBy.trim();
    final reason = params.reason.trim();

    if (studentId.isEmpty) {
      return const Left(ValidationFailure('معرّف الطالب مطلوب'));
    }
    if (halaqaId.isEmpty) {
      return const Left(ValidationFailure('معرّف الحلقة مطلوب'));
    }
    if (requestedBy.isEmpty) {
      return const Left(ValidationFailure('معرّف ولي الأمر مطلوب'));
    }
    if (reason.isEmpty) {
      return const Left(ValidationFailure('سبب الاستئذان مطلوب'));
    }

    final childrenEither = await repository.getChildrenIds(requestedBy);
    final childrenFailure = childrenEither.fold<Failure?>(
      (l) => l,
      (_) => null,
    );
    if (childrenFailure != null) return Left(childrenFailure);

    final children = childrenEither
        .getOrElse((_) => const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (!children.contains(studentId)) {
      return const Left(
        ValidationFailure('لا يمكن تقديم استئذان لطالب غير مرتبط بولي الأمر'),
      );
    }

    final day = AttendancePolicy.dayStart(params.date);
    final id = AbsenceRequestIds.documentId(
      halaqaId: halaqaId,
      studentId: studentId,
      date: day,
    );

    final normalized = AbsenceRequestEntity(
      id: id,
      studentId: studentId,
      halaqaId: halaqaId,
      requestedBy: requestedBy,
      date: day,
      reason: reason,
      status: AbsenceRequestStatus.pending,
    );

    return repository.submitAbsenceRequest(normalized);
  }
}
