import 'package:equatable/equatable.dart';

import '../repositories/teacher_repository.dart';

class HalaqaStudentSummaryEntity extends Equatable {
  final String uid;
  final String name;
  final String? profileImageUrl;
  final AttendanceStatus? todayAttendance;

  const HalaqaStudentSummaryEntity({
    required this.uid,
    required this.name,
    this.profileImageUrl,
    this.todayAttendance,
  });

  @override
  List<Object?> get props => [uid, name, profileImageUrl, todayAttendance];
}
