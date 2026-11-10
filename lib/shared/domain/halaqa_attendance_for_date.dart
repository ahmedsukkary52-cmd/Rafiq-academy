import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:equatable/equatable.dart';

import '../../core/error/failure.dart';
import '../../core/usecases/usecases.dart';
import 'attendance_record_entity.dart';
import 'load_halaqa_day_readiness.dart';

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

/// One Halaqa-day attendance read, used by the teacher and supervisor
/// attendance screens.
@lazySingleton
class GetHalaqaAttendanceForDateUseCase
    extends UseCase<List<AttendanceRecordEntity>, HalaqaAttendanceDateParams> {
  final HalaqaDayFactsReader repository;

  GetHalaqaAttendanceForDateUseCase(this.repository);

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>> call(
    HalaqaAttendanceDateParams params,
  ) => repository.getHalaqaAttendanceForDate(
    halaqaId: params.halaqaId,
    date: params.date,
  );
}
