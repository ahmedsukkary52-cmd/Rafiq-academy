import '../../../../shared/domain/student_at_risk_policy.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../entities/halaqa_students_summary_entity.dart';

/// Pure enrichment for teacher class-detail roster cards.
///
/// At-risk is delegated entirely to [StudentAtRiskPolicy] (same SSOT as
/// analytics). Progress / level come from existing profile & user fields.
class HalaqaStudentSummaryProjector {
  const HalaqaStudentSummaryProjector._();

  static const int attendanceWindowDays = 30;

  static HalaqaStudentSummaryEntity enrich({
    required HalaqaStudentSummaryEntity base,
    required Iterable<AttendanceMarkRef> attendanceMarks,
    required Iterable<RecitationRecordEntity> recitations,
    required DateTime now,
    double? overallProgressPercent,
  }) {
    final riskStart =
        now.subtract(const Duration(days: StudentAtRiskPolicy.windowDays));
    final attendanceStart =
        now.subtract(const Duration(days: attendanceWindowDays));

    final studentMarks = attendanceMarks
        .where((m) => m.studentId.trim() == base.uid)
        .where((m) => !m.date.isBefore(attendanceStart))
        .toList();
    final unique = AttendancePolicy.uniqueDayStatuses(studentMarks);
    final attendancePercent =
        AttendancePolicy.attendancePercentFromStatuses(unique);

    final studentRecitations = recitations
        .where((r) => r.studentId.trim() == base.uid)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    String? lastGradeLabel;
    for (final record in studentRecitations) {
      if (record.isPendingReview) continue;
      final grade = record.grade;
      if (grade == null) continue;
      lastGradeLabel = grade.label;
      break;
    }

    final marksInRiskWindow =
        studentMarks.where((m) => !m.date.isBefore(riskStart));
    final hasRecentEvaluation = studentRecitations.any(
      (r) => !r.date.isBefore(riskStart),
    );

    return base.copyWith(
      attendancePercent: attendancePercent,
      lastGradeLabel: lastGradeLabel,
      isAtRisk: StudentAtRiskPolicy.isAtRisk(
        marksInWindow: marksInRiskWindow,
        hasEvaluationInWindow: hasRecentEvaluation,
      ),
      overallProgressPercent:
          overallProgressPercent ?? base.overallProgressPercent,
    );
  }
}
