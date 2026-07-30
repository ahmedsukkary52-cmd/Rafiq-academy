import '../../../../shared/utils/attendance_policy.dart';
import '../../domain/entities/progress_report_entity.dart';
import '../models/progress_report_source_model.dart';

/// Aggregates raw attendance/recitation docs into [ProgressReportEntity].
/// Memorization accuracy stays 0 here — Bloc overlays profile percent.
class ProgressReportMapper {
  const ProgressReportMapper();

  ProgressReportEntity map(ProgressReportSourceModel source, {DateTime? now}) {
    final clock = now ?? DateTime.now();

    final statuses = AttendancePolicy.uniqueDayStatuses(
      source.attendance.map(
        (a) => AttendanceMarkRef(
          id: a.id,
          halaqaId: a.halaqaId,
          studentId: source.studentId,
          date: a.date,
          status: a.status,
        ),
      ),
    );
    final attended = AttendancePolicy.countAttended(statuses);
    final absences = AttendancePolicy.countAbsent(statuses);
    final attendancePercent = AttendancePolicy.attendancePercent(
      attended: attended,
      total: statuses.length,
    );

    return ProgressReportEntity(
      memorizationAccuracyPercent: 0,
      attendedSessions: attended,
      monthlyAttendancePercent: attendancePercent,
      attendanceDays: attended,
      absenceDays: absences,
      weeklyVersesPerDay: _weeklyRecitationCounts(source.recitations, clock),
      teacherNotes: _latestReviewedNotes(source.recitations),
    );
  }

  /// Chart indices match UI labels أح…سب (Sun=0 … Sat=6).
  List<double> _weeklyRecitationCounts(
    List<ProgressRecitationDocModel> recitations,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    // Week starting Sunday containing [today].
    final sundayOffset = today.weekday % 7; // Sun=0
    final weekStart = today.subtract(Duration(days: sundayOffset));
    final counts = List<double>.filled(7, 0);

    for (final rec in recitations) {
      final day = DateTime(rec.date.year, rec.date.month, rec.date.day);
      final diff = day.difference(weekStart).inDays;
      if (diff < 0 || diff > 6) continue;
      counts[diff] += 1;
    }
    return counts;
  }

  String _latestReviewedNotes(List<ProgressRecitationDocModel> recitations) {
    final withNotes =
        recitations
            .where((r) => r.isReviewed && (r.notes?.trim().isNotEmpty ?? false))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (withNotes.isEmpty) return '';
    return withNotes.first.notes!.trim();
  }
}
