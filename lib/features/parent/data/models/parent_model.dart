import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_payment_proof.dart';

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
    super.proofStoragePath,
    super.proofDownloadUrl,
    super.proofSubmittedAt,
    super.proofSubmittedBy,
    super.proofFileName,
    super.reviewStatus,
    super.reviewedBy,
    super.reviewedAt,
    super.reviewNotes,
    super.amountPaidConfirmed,
    super.remainingAmount,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final submitted = data[ParentPaymentProofContract.proofSubmittedAtField];
    final reviewed = data[ParentPaymentProofContract.reviewedAtField];
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
      proofStoragePath:
          data[ParentPaymentProofContract.proofStoragePathField] as String?,
      proofDownloadUrl:
          data[ParentPaymentProofContract.proofDownloadUrlField] as String?,
      proofSubmittedAt: submitted is Timestamp ? submitted.toDate() : null,
      proofSubmittedBy:
          data[ParentPaymentProofContract.proofSubmittedByField] as String?,
      proofFileName:
          data[ParentPaymentProofContract.proofFileNameField] as String?,
      reviewStatus:
          data[ParentPaymentProofContract.reviewStatusField] as String?,
      reviewedBy: data[ParentPaymentProofContract.reviewedByField] as String?,
      reviewedAt: reviewed is Timestamp ? reviewed.toDate() : null,
      reviewNotes: data[ParentPaymentProofContract.reviewNotesField] as String?,
      amountPaidConfirmed:
          (data[ParentPaymentProofContract.amountPaidConfirmedField] as num?)
              ?.toDouble(),
      remainingAmount:
          (data[ParentPaymentProofContract.remainingAmountField] as num?)
              ?.toDouble(),
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
