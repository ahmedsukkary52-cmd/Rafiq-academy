import '../../domain/entities/progress_report_entity.dart';
import '../models/progress_report_source_model.dart';

/// Aggregates raw attendance/recitation docs into [ProgressReportEntity].
/// Memorization accuracy stays 0 here — Bloc overlays profile percent.
class ProgressReportMapper {
  const ProgressReportMapper();

  ProgressReportEntity map(ProgressReportSourceModel source, {DateTime? now}) {
    final clock = now ?? DateTime.now();

    final attended = source.attendance.where((a) => a.isPresentLike).length;
    final absences = source.attendance.where((a) => a.isAbsent).length;
    final total = source.attendance.length;
    final attendancePercent = total == 0 ? 0.0 : (attended / total) * 100.0;

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
