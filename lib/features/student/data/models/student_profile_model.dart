import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/student_profile_entity.dart';

class StudentProfileModel extends StudentProfileEntity {
  const StudentProfileModel({
    required super.uid,
    required super.name,
    super.profileImageUrl,
    super.halaqaId,
    required super.currentPlanName,
    required super.overallProgressPercent,
    required super.totalStars,
    required super.badges,
  });

  factory StudentProfileModel.fromFirestore({
    required DocumentSnapshot userDoc,
    required DocumentSnapshot profileDoc,
  }) {
    final user = userDoc.data() as Map<String, dynamic>;
    final profile = profileDoc.data() as Map<String, dynamic>;

    return StudentProfileModel(
      uid: userDoc.id,
      name: user['name'] ?? '',
      profileImageUrl: user['profileImageUrl'] as String?,
      halaqaId: profile['halaqaId'] as String?,
      currentPlanName: profile['currentPlanName'] ?? '',
      overallProgressPercent: (profile['overallProgressPercent'] ?? 0)
          .toDouble(),
      totalStars: (profile['totalStars'] ?? 0) as int,
      badges: List<String>.from(profile['badges'] ?? []),
    );
  }
}
