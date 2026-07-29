import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/parent_entities.dart';

class AbsenceRequestModel extends AbsenceRequestEntity {
  const AbsenceRequestModel({
    required super.id,
    required super.studentId,
    required super.halaqaId,
    required super.requestedBy,
    required super.date,
    required super.reason,
    required super.status,
    super.reviewedBy,
  });

  factory AbsenceRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AbsenceRequestModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      halaqaId: data['halaqaId'] ?? '',
      requestedBy: data['requestedBy'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      reason: data['reason'] ?? '',
      status: _statusFromString(data['status'] ?? ''),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'halaqaId': halaqaId,
    'requestedBy': requestedBy,
    'date': Timestamp.fromDate(date),
    'reason': reason,
    'status': _statusToString(status),
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
  };

  static AbsenceRequestStatus _statusFromString(String v) => switch (v) {
    'approved' => AbsenceRequestStatus.approved,
    'rejected' => AbsenceRequestStatus.rejected,
    _ => AbsenceRequestStatus.pending,
  };

  static String _statusToString(AbsenceRequestStatus s) => switch (s) {
    AbsenceRequestStatus.pending => 'pending',
    AbsenceRequestStatus.approved => 'approved',
    AbsenceRequestStatus.rejected => 'rejected',
  };
}

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
