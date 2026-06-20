import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/recitation_record_entity.dart';

class RecitationRecordModel extends RecitationRecordEntity {
  const RecitationRecordModel({
    required super.id,
    required super.studentId,
    required super.teacherId,
    required super.halaqaId,
    required super.date,
    required super.type,
    required super.versesRange,
    required super.grade,
    super.notes,
  });

  factory RecitationRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecitationRecordModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      halaqaId: data['halaqaId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      type: data['type'] == 'memorization'
          ? RecitationType.memorization
          : RecitationType.review,
      versesRange: data['versesRange'] ?? '',
      grade: _gradeFromString(data['grade'] ?? ''),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'teacherId': teacherId,
    'halaqaId': halaqaId,
    'date': Timestamp.fromDate(date),
    'type': type == RecitationType.memorization ? 'memorization' : 'review',
    'versesRange': versesRange,
    'grade': grade.label,
    if (notes != null) 'notes': notes,
  };

  static RecitationGrade _gradeFromString(String value) => switch (value) {
    'ممتاز' => RecitationGrade.excellent,
    'جيد جداً' => RecitationGrade.veryGood,
    'جيد' => RecitationGrade.good,
    'يحتاج إعادة' => RecitationGrade.needsRetry,
    _ => RecitationGrade.good,
  };
}
