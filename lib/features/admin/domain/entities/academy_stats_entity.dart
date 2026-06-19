import 'package:equatable/equatable.dart';

class AcademyStatsEntity extends Equatable {
  final int totalStudents;
  final int totalTeachers;
  final int totalHalaqat;
  final double overallAttendancePercent;
  final int totalVersesMemorizedThisMonth;

  const AcademyStatsEntity({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalHalaqat,
    required this.overallAttendancePercent,
    required this.totalVersesMemorizedThisMonth,
  });

  @override
  List<Object?> get props => [
    totalStudents,
    totalTeachers,
    totalHalaqat,
    overallAttendancePercent,
    totalVersesMemorizedThisMonth,
  ];
}
