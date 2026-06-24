import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/student_profile_entity.dart';

class StudentProfileModel extends StudentProfileEntity {
  const StudentProfileModel({
    required super.uid,
    required super.name,
    super.profileImageUrl,
    super.halaqaId,
    super.halaqaName,
    required super.currentPlanName,
    required super.overallProgressPercent,
    super.totalVersesMemorized,
    super.completedJuz,
    super.points,
    super.streakDays,
    super.level,
    required super.totalStars,
    required super.badges,
  });

  factory StudentProfileModel.fromFirestore({
    required DocumentSnapshot userDoc,
    required DocumentSnapshot profileDoc,
    String halaqaName = '',
  }) {
    final user = userDoc.data() as Map<String, dynamic>;
    final profile = profileDoc.data() as Map<String, dynamic>;

    return StudentProfileModel(
      uid: userDoc.id,
      name: user['name'] ?? '',
      profileImageUrl: user['profileImageUrl'] as String?,
      halaqaId: profile['halaqaId'] as String?,
      halaqaName: halaqaName,
      currentPlanName: profile['currentPlanName'] ?? '',
      overallProgressPercent: (profile['overallProgressPercent'] ?? 0)
          .toDouble(),
      totalVersesMemorized: (profile['totalVersesMemorized'] ?? 0) as int,
      completedJuz: (profile['completedJuz'] ?? 0) as int,
      points: (profile['points'] ?? 0) as int,
      streakDays: (profile['streakDays'] ?? 0) as int,
      level: (profile['level'] ?? 1) as int,
      totalStars: (profile['totalStars'] ?? 0) as int,
      badges: List<String>.from(profile['badges'] ?? []),
    );
  }
}
