import 'package:equatable/equatable.dart';

enum AbsenceRequestStatus { pending, approved, rejected }

class AbsenceRequestEntity extends Equatable {
  final String id;
  final String studentId;
  final String requestedBy;
  final DateTime date;
  final String reason;
  final AbsenceRequestStatus status;
  final String? reviewedBy;

  const AbsenceRequestEntity({
    required this.id,
    required this.studentId,
    required this.requestedBy,
    required this.date,
    required this.reason,
    required this.status,
    this.reviewedBy,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    requestedBy,
    date,
    reason,
    status,
    reviewedBy,
  ];
}

enum PaymentStatus { paid, due, overdue }

class PaymentEntity extends Equatable {
  final String id;
  final String studentId;
  final String parentId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidAt;
  final PaymentStatus status;
  final String? method;

  const PaymentEntity({
    required this.id,
    required this.studentId,
    required this.parentId,
    required this.amount,
    required this.dueDate,
    this.paidAt,
    required this.status,
    this.method,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    parentId,
    amount,
    dueDate,
    paidAt,
    status,
    method,
  ];
}

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

  double get attendancePercent =>
      totalSessions == 0 ? 0 : (attendedSessions / totalSessions) * 100;

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
