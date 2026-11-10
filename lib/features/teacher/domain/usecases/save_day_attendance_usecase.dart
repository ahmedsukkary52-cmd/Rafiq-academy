import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../../../../shared/domain/attendance_record_entity.dart';
import '../repositories/teacher_repository.dart';
import '../teacher_halaqa_ownership.dart';

@lazySingleton
class SaveDayAttendanceUseCase
    extends UseCase<AcademyEventPublication, List<AttendanceRecordEntity>> {
  final TeacherRepository repository;

  SaveDayAttendanceUseCase(this.repository);

  @override
  Future<Either<Failure, AcademyEventPublication>> call(
    List<AttendanceRecordEntity> params,
  ) async {
    if (params.isEmpty) {
      return const Left(ValidationFailure('لا توجد سجلات حضور للحفظ'));
    }

    final first = params.first;
    final ownership = await ensureTeacherOwnsHalaqa(
      repository: repository,
      teacherId: first.recordedBy,
      halaqaId: first.halaqaId,
    );
    final blocked = ownership.fold<Failure?>((l) => l, (_) => null);
    if (blocked != null) return Left(blocked);

    final sameHalaqa = params.every(
      (r) => r.halaqaId.trim() == first.halaqaId.trim(),
    );
    if (!sameHalaqa) {
      return const Left(
        ValidationFailure('سجلات الحضور يجب أن تكون لنفس الحلقة'),
      );
    }

    return repository.saveDayAttendance(params);
  }
}
