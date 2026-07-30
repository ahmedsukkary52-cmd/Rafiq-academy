import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/parent_entities.dart';

export '../../../../shared/data/absence_request_model.dart';

class PaymentModel extends PaymentEntity {
  const PaymentModel({
    required super.id,
    required super.studentId,
    required super.parentId,
    required super.amount,
    required super.dueDate,
    super.paidAt,
    required super.status,
    super.method,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      parentId: data['parentId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paidAt: data['paidAt'] != null
          ? (data['paidAt'] as Timestamp).toDate()
          : null,
      status: _statusFromString(data['status'] ?? ''),
      method: data['method'] as String?,
    );
  }

  static PaymentStatus _statusFromString(String v) => switch (v) {
    'paid' => PaymentStatus.paid,
    'overdue' => PaymentStatus.overdue,
    _ => PaymentStatus.due,
  };
}

class WeeklyReportModel extends WeeklyReportEntity {
  const WeeklyReportModel({
    required super.studentId,
    required super.studentName,
    required super.weekStart,
    required super.totalVersesMemorized,
    required super.attendedSessions,
    required super.totalSessions,
    required super.teacherNotes,
  });

  factory WeeklyReportModel.fromMap({
    required String studentId,
    required String studentName,
    required DateTime weekStart,
    required Map<String, dynamic> data,
  }) {
    return WeeklyReportModel(
      studentId: studentId,
      studentName: studentName,
      weekStart: weekStart,
      totalVersesMemorized: (data['totalVersesMemorized'] ?? 0) as int,
      attendedSessions: (data['attendedSessions'] ?? 0) as int,
      totalSessions: (data['totalSessions'] ?? 0) as int,
      teacherNotes: data['teacherNotes'] ?? '',
    );
  }
}
