import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/absence_request.dart';

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
      status: statusFromString(data['status'] ?? ''),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'halaqaId': halaqaId,
    'requestedBy': requestedBy,
    'date': Timestamp.fromDate(date),
    'reason': reason,
    'status': statusToString(status),
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
  };

  static AbsenceRequestStatus statusFromString(String v) => switch (v) {
    'approved' => AbsenceRequestStatus.approved,
    'rejected' => AbsenceRequestStatus.rejected,
    _ => AbsenceRequestStatus.pending,
  };

  static String statusToString(AbsenceRequestStatus s) => switch (s) {
    AbsenceRequestStatus.pending => 'pending',
    AbsenceRequestStatus.approved => 'approved',
    AbsenceRequestStatus.rejected => 'rejected',
  };
}
