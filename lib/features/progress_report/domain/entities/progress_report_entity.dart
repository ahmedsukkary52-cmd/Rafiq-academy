import 'package:equatable/equatable.dart';

class ProgressReportEntity extends Equatable {
  /// دقة الحفظ — تُستبدل/تُزامَن مع overallProgressPercent من بروفايل الطالب
  final double memorizationAccuracyPercent;
  final int attendedSessions;
  final double monthlyAttendancePercent;
  final int attendanceDays;
  final int absenceDays;
  final List<double> weeklyVersesPerDay;
  final String teacherNotes;

  const ProgressReportEntity({
    required this.memorizationAccuracyPercent,
    required this.attendedSessions,
    required this.monthlyAttendancePercent,
    required this.attendanceDays,
    required this.absenceDays,
    required this.weeklyVersesPerDay,
    required this.teacherNotes,
  });

  ProgressReportEntity copyWith({double? memorizationAccuracyPercent}) {
    return ProgressReportEntity(
      memorizationAccuracyPercent:
          memorizationAccuracyPercent ?? this.memorizationAccuracyPercent,
      attendedSessions: attendedSessions,
      monthlyAttendancePercent: monthlyAttendancePercent,
      attendanceDays: attendanceDays,
      absenceDays: absenceDays,
      weeklyVersesPerDay: weeklyVersesPerDay,
      teacherNotes: teacherNotes,
    );
  }

  @override
  List<Object?> get props => [
    memorizationAccuracyPercent,
    attendedSessions,
    monthlyAttendancePercent,
    attendanceDays,
    absenceDays,
    weeklyVersesPerDay,
    teacherNotes,
  ];
}
