import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/halaqa_students_summary_entity.dart';

class HalaqaStudentSummaryModel extends HalaqaStudentSummaryEntity {
  const HalaqaStudentSummaryModel({
    required super.uid,
    required super.name,
    super.profileImageUrl,
    super.todayAttendance,
  });

  factory HalaqaStudentSummaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HalaqaStudentSummaryModel(
      uid: doc.id,
      name: data['name'] ?? '',
      profileImageUrl: data['profileImageUrl'] as String?,
    );
  }
}
