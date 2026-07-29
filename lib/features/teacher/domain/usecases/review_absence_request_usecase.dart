import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../repositories/teacher_repository.dart';

class ReviewAbsenceRequestParams extends Equatable {
  final String requestId;
  final String halaqaId;
  final String teacherId;
  final AbsenceRequestStatus decision;

  const ReviewAbsenceRequestParams({
    required this.requestId,
    required this.halaqaId,
    required this.teacherId,
    required this.decision,
  });

  @override
  List<Object?> get props => [requestId, halaqaId, teacherId, decision];
}

/// Classifies an استئذان as approved/rejected (W7 Rule 1 / D-W7-3).
///
/// Updates **only** the request document. Never reads or writes attendance.
@lazySingleton
class ReviewAbsenceRequestUseCase
    extends UseCase<Unit, ReviewAbsenceRequestParams> {
  final TeacherRepository repository;

  ReviewAbsenceRequestUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ReviewAbsenceRequestParams params) async {
    final requestId = params.requestId.trim();
    final halaqaId = params.halaqaId.trim();
    final teacherId = params.teacherId.trim();

    if (requestId.isEmpty) {
      return const Left(ValidationFailure('معرّف الطلب مطلوب'));
    }
    if (halaqaId.isEmpty) {
      return const Left(ValidationFailure('معرّف الحلقة مطلوب'));
    }
    if (teacherId.isEmpty) {
      return const Left(ValidationFailure('معرّف المعلم مطلوب'));
    }
    if (params.decision == AbsenceRequestStatus.pending) {
      return const Left(
        ValidationFailure('قرار المراجعة يجب أن يكون قبولاً أو رفضاً'),
      );
    }

    final owned = await repository.getTeacherHalaqat(teacherId);
    final ownedFailure = owned.fold<Failure?>((l) => l, (_) => null);
    if (ownedFailure != null) return Left(ownedFailure);

    final authorized = owned
        .getOrElse((_) => const [])
        .any((h) => h.id.trim() == halaqaId);
    if (!authorized) {
      return const Left(
        ValidationFailure('لا يمكن مراجعة طلب استئذان لحلقة غير مسندة للمعلم'),
      );
    }

    return repository.reviewAbsenceRequest(
      requestId: requestId,
      expectedHalaqaId: halaqaId,
      teacherId: teacherId,
      decision: params.decision,
    );
  }
}
