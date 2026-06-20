import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/assignment_entity.dart';

class AssignmentModel extends AssignmentEntity {
  const AssignmentModel({
    required super.id,
    required super.studentId,
    required super.assignedBy,
    required super.newMemorizationRange,
    required super.reviewRange,
    required super.dueDate,
  });

  factory AssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssignmentModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      newMemorizationRange: data['newMemorizationRange'] ?? '',
      reviewRange: data['reviewRange'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'assignedBy': assignedBy,
    'newMemorizationRange': newMemorizationRange,
    'reviewRange': reviewRange,
    'dueDate': Timestamp.fromDate(dueDate),
  };
}
