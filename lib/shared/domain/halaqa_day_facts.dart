import '../../features/student/domain/entities/recitation_record_entity.dart';
import '../../features/teacher/domain/entities/attendance_record_entity.dart';
import 'halaqa_day_readiness.dart';

/// One I/O pass of W1/W2 facts used by readiness **and** Home activity projection.
///
/// Keeps Teacher Home from re-querying attendance/recitations for the same
/// halaqa/day that agenda already loaded.
class HalaqaDayFacts {
  final HalaqaDayReadiness readiness;
  final List<AttendanceRecordEntity> attendance;
  final List<RecitationRecordEntity> recitations;

  const HalaqaDayFacts({
    required this.readiness,
    required this.attendance,
    required this.recitations,
  });
}
