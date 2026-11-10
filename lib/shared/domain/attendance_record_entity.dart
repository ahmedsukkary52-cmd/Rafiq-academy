import 'package:equatable/equatable.dart';

enum AttendanceStatus { present, absent, late, excused }

class AttendanceRecordEntity extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String halaqaId;
  final DateTime date;
  final AttendanceStatus status;
  final String recordedBy;

  /// Operational session id (`{halaqaId}_yyyyMMdd`) — required on every write.
  final String sessionId;

  const AttendanceRecordEntity({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.halaqaId,
    required this.date,
    required this.status,
    required this.recordedBy,
    required this.sessionId,
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
    sessionId,
  ];
}
