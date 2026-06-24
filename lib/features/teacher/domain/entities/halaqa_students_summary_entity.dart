import 'package:equatable/equatable.dart';

import '../repositories/teacher_repository.dart';

class HalaqaStudentSummaryEntity extends Equatable {
  final String uid;
  final String name;
  final String? profileImageUrl;
  final AttendanceStatus? todayAttendance;

  /// المستوى داخل الحلقة - ظهر في التصميم "المستوى ٣"
  final int level;

  /// نسبة الحضور الكلية - ظهرت في التصميم "٩٢% حضور"
  final double attendancePercent;

  /// آخر تقييم حفظ - ظهر في التصميم "آخر تقييم: ممتاز"
  final String? lastGradeLabel;

  /// طالب في خطر (غيابات متكررة أو أداء ضعيف) - ظهر في التصميم ببادج "في خطر"
  final bool isAtRisk;

  const HalaqaStudentSummaryEntity({
    required this.uid,
    required this.name,
    this.profileImageUrl,
    this.todayAttendance,
    this.level = 1,
    this.attendancePercent = 0,
    this.lastGradeLabel,
    this.isAtRisk = false,
  });

  @override
  List<Object?> get props => [
    uid,
    name,
    profileImageUrl,
    todayAttendance,
    level,
    attendancePercent,
    lastGradeLabel,
    isAtRisk,
  ];
}
