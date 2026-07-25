import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/attendance_record_entity.dart';
import '../repositories/teacher_repository.dart';

@lazySingleton
class SaveDayAttendanceUseCase
    extends UseCase<Unit, List<AttendanceRecordEntity>> {
  final TeacherRepository repository;

  SaveDayAttendanceUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(List<AttendanceRecordEntity> params) =>
      repository.saveDayAttendance(params);
}
