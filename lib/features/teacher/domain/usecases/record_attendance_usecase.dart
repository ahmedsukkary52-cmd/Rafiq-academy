import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/attendance_record_entity.dart';
import '../repositories/teacher_repository.dart';

@lazySingleton
class RecordAttendanceUseCase extends UseCase<Unit, AttendanceRecordEntity> {
  final TeacherRepository repository;
  RecordAttendanceUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AttendanceRecordEntity params) =>
      repository.recordAttendance(params);
}
