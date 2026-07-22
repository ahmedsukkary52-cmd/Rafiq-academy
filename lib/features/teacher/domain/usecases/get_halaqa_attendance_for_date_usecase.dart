import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/attendance_record_entity.dart';
import '../repositories/teacher_repository.dart';

class HalaqaAttendanceDateParams extends Equatable {
  final String halaqaId;
  final DateTime date;

  const HalaqaAttendanceDateParams({
    required this.halaqaId,
    required this.date,
  });

  @override
  List<Object?> get props => [halaqaId, date];
}

@lazySingleton
class GetHalaqaAttendanceForDateUseCase
    extends UseCase<List<AttendanceRecordEntity>, HalaqaAttendanceDateParams> {
  final TeacherRepository repository;

  GetHalaqaAttendanceForDateUseCase(this.repository);

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>> call(
    HalaqaAttendanceDateParams params,
  ) => repository.getHalaqaAttendanceForDate(
        halaqaId: params.halaqaId,
        date: params.date,
      );
}
