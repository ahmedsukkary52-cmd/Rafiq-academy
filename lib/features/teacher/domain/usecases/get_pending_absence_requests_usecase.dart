import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../repositories/teacher_repository.dart';

class PendingAbsenceRequestsParams extends Equatable {
  final String teacherId;
  final String halaqaId;
  final DateTime date;

  const PendingAbsenceRequestsParams({
    required this.teacherId,
    required this.halaqaId,
    required this.date,
  });

  @override
  List<Object?> get props => [teacherId, halaqaId, date];
}

/// Pending استئذان for one authorized halaqa + calendar day (W7 Slice 2).
///
/// Authorization: [halaqaId] must belong to [teacherId]'s active halaqat.
/// Does not read or write attendance.
@lazySingleton
class GetPendingAbsenceRequestsUseCase
    extends UseCase<List<AbsenceRequestEntity>, PendingAbsenceRequestsParams> {
  final TeacherRepository repository;

  GetPendingAbsenceRequestsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>> call(
    PendingAbsenceRequestsParams params,
  ) async {
    final teacherId = params.teacherId.trim();
    final halaqaId = params.halaqaId.trim();
    if (teacherId.isEmpty) {
      return const Left(ValidationFailure('معرّف المعلم مطلوب'));
    }
    if (halaqaId.isEmpty) {
      return const Left(ValidationFailure('معرّف الحلقة مطلوب'));
    }

    final owned = await repository.getTeacherHalaqat(teacherId);
    final ownedFailure = owned.fold<Failure?>((l) => l, (_) => null);
    if (ownedFailure != null) return Left(ownedFailure);

    final authorized = owned
        .getOrElse((_) => const [])
        .any((h) => h.id.trim() == halaqaId);
    if (!authorized) {
      return const Left(
        ValidationFailure('لا يمكن عرض طلبات استئذان لحلقة غير مسندة للمعلم'),
      );
    }

    final day = AttendancePolicy.dayStart(params.date);
    return repository.getPendingAbsenceRequests(halaqaId: halaqaId, date: day);
  }
}
