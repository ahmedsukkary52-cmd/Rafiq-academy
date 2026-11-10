import 'package:equatable/equatable.dart';

import '../../../../shared/utils/attendance_policy.dart';

// AbsenceRequest* (H4 / A-H6) and Payment* types live in shared.
export '../../../../shared/domain/absence_request.dart';
export '../../../../shared/domain/payment_entity.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WeeklyReportEntity - التقرير الأسبوعي لولي الأمر
// ══════════════════════════════════════════════════════════════════════════════

class WeeklyReportEntity extends Equatable {
  final String studentId;
  final String studentName;
  final DateTime weekStart;
  final int totalVersesMemorized;
  final int attendedSessions;
  final int totalSessions;
  final String teacherNotes;

  const WeeklyReportEntity({
    required this.studentId,
    required this.studentName,
    required this.weekStart,
    required this.totalVersesMemorized,
    required this.attendedSessions,
    required this.totalSessions,
    required this.teacherNotes,
  });

  double get attendancePercent => AttendancePolicy.attendancePercent(
    attended: attendedSessions,
    total: totalSessions,
  );

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    weekStart,
    totalVersesMemorized,
    attendedSessions,
    totalSessions,
    teacherNotes,
  ];
}
