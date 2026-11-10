import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/domain/halaqa_students_summary_entity.dart';

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

  /// Roster identity from `studentProfiles` (WA-2 / D16 — avoid users.phone).
  factory HalaqaStudentSummaryModel.fromStudentProfile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return HalaqaStudentSummaryModel(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      profileImageUrl: data['profileImageUrl'] as String?,
      level: (data['level'] as num?)?.toInt() ?? 1,
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
