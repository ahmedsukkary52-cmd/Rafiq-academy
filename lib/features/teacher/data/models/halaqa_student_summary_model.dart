import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/halaqa_students_summary_entity.dart';

class HalaqaStudentSummaryModel extends HalaqaStudentSummaryEntity {
  const HalaqaStudentSummaryModel({
    required super.uid,
    required super.name,
    super.profileImageUrl,
    super.todayAttendance,
    super.level,
    super.attendancePercent,
    super.lastGradeLabel,
    super.isAtRisk,
    super.overallProgressPercent,
  });

  factory HalaqaStudentSummaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HalaqaStudentSummaryModel(
      uid: doc.id,
      name: data['name'] ?? '',
      profileImageUrl: data['profileImageUrl'] as String?,
      level: (data['level'] ?? 1) as int,
    );
  }

  factory HalaqaStudentSummaryModel.fromEntity(
    HalaqaStudentSummaryEntity entity,
  ) {
    return HalaqaStudentSummaryModel(
      uid: entity.uid,
      name: entity.name,
      profileImageUrl: entity.profileImageUrl,
      todayAttendance: entity.todayAttendance,
      level: entity.level,
      attendancePercent: entity.attendancePercent,
      lastGradeLabel: entity.lastGradeLabel,
      isAtRisk: entity.isAtRisk,
      overallProgressPercent: entity.overallProgressPercent,
    );
  }
}
