import 'package:equatable/equatable.dart';

import '../repositories/teacher_repository.dart';

class AttendanceRecordEntity extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String halaqaId;
  final DateTime date;
  final AttendanceStatus status;
  final String recordedBy;

  const AttendanceRecordEntity({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.halaqaId,
    required this.date,
    required this.status,
    required this.recordedBy,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    studentName,
    halaqaId,
    date,
    status,
    recordedBy,
  ];
}
