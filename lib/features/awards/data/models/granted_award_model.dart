import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/award_entities.dart';

class GrantedAwardModel extends GrantedAwardEntity {
  const GrantedAwardModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    super.studentImageUrl,
    required super.type,
    super.note,
    required super.grantedBy,
    required super.halaqaId,
    required super.grantedAt,
  });

  factory GrantedAwardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GrantedAwardModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentImageUrl: data['studentImageUrl'] as String?,
      type: AwardTypeInfo.fromKey(data['type'] ?? ''),
      note: data['note'] as String?,
      grantedBy: data['grantedBy'] ?? '',
      halaqaId: data['halaqaId'] ?? '',
      grantedAt: (data['grantedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'studentName': studentName,
    if (studentImageUrl != null) 'studentImageUrl': studentImageUrl,
    'type': type.firestoreKey,
    if (note != null) 'note': note,
    'grantedBy': grantedBy,
    'halaqaId': halaqaId,
    'grantedAt': FieldValue.serverTimestamp(),
  };
}
