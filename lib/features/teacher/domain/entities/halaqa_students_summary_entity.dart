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
  /// Derived at read time — never a stored Firestore field.
  final bool isAtRisk;

  /// تقدم الحفظ من `studentProfiles.overallProgressPercent` (0–100).
  final double overallProgressPercent;

  const HalaqaStudentSummaryEntity({
    required this.uid,
    required this.name,
    this.profileImageUrl,
    this.todayAttendance,
    this.level = 1,
    this.attendancePercent = 0,
    this.lastGradeLabel,
    this.isAtRisk = false,
    this.overallProgressPercent = 0,
  });

  HalaqaStudentSummaryEntity copyWith({
    String? uid,
    String? name,
    String? profileImageUrl,
    AttendanceStatus? todayAttendance,
    int? level,
    double? attendancePercent,
    String? lastGradeLabel,
    bool? isAtRisk,
    double? overallProgressPercent,
  }) {
    return HalaqaStudentSummaryEntity(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      level: level ?? this.level,
      attendancePercent: attendancePercent ?? this.attendancePercent,
      lastGradeLabel: lastGradeLabel ?? this.lastGradeLabel,
      isAtRisk: isAtRisk ?? this.isAtRisk,
      overallProgressPercent:
          overallProgressPercent ?? this.overallProgressPercent,
    );
  }

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
    overallProgressPercent,
  ];
}
