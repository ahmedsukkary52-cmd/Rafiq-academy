import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../repositories/parent_repository.dart';

class SupervisedAbsenceRequestsParams extends Equatable {
  final String supervisorId;
  final DateTime date;

  const SupervisedAbsenceRequestsParams({
    required this.supervisorId,
    required this.date,
  });

  @override
  List<Object?> get props => [supervisorId, date];
}

/// Read-only استئذان projection for supervised halaqat (W7 Rule 2 / D-W7-7).
///
/// Derives from existing `absenceRequests` docs only — no review writes,
/// no attendance I/O, no new workflow state.
@lazySingleton
class GetSupervisedAbsenceRequestsUseCase
    extends
        UseCase<List<AbsenceRequestEntity>, SupervisedAbsenceRequestsParams> {
  final SupervisorRepository repository;

  GetSupervisedAbsenceRequestsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>> call(
    SupervisedAbsenceRequestsParams params,
  ) async {
    final supervisorId = params.supervisorId.trim();
    if (supervisorId.isEmpty) {
      return const Left(ValidationFailure('معرّف المشرف مطلوب'));
    }

    final halaqatEither = await repository.getSupervisedHalaqat(supervisorId);
    final halaqatFailure = halaqatEither.fold<Failure?>((l) => l, (_) => null);
    if (halaqatFailure != null) return Left(halaqatFailure);

    final halaqaIds = halaqatEither
        .getOrElse((_) => const [])
        .map((h) => h.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (halaqaIds.isEmpty) return const Right([]);

    final day = AttendancePolicy.dayStart(params.date);
    return repository.getAbsenceRequestsForHalaqatOnDate(
      halaqaIds: halaqaIds,
      date: day,
    );
  }
}
