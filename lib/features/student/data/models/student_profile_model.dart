import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/student_profile_entity.dart';

class StudentProfileModel extends StudentProfileEntity {
  const StudentProfileModel({
    required super.uid,
    required super.name,
    super.profileImageUrl,
    super.phone,
    super.halaqaId,
    super.halaqaName,
    required super.currentPlanName,
    required super.overallProgressPercent,
    super.totalVersesMemorized,
    super.completedJuz,
    super.completedSurahs,
    super.points,
    super.streakDays,
    super.level,
    required super.totalStars,
    required super.badges,
    super.coins,
    super.avatarId,
    super.unlockedAvatarIds,
    super.createdAt,
  });

  factory StudentProfileModel.fromFirestore({
    required DocumentSnapshot userDoc,
    required DocumentSnapshot profileDoc,
    String halaqaName = '',
  }) {
    return StudentProfileModel.fromMaps(
      uid: userDoc.id,
      user: userDoc.data() as Map<String, dynamic>,
      profile: profileDoc.data() as Map<String, dynamic>,
      halaqaName: halaqaName,
    );
  }

  factory StudentProfileModel.fromMaps({
    required String uid,
    required Map<String, dynamic> user,
    required Map<String, dynamic> profile,
    String halaqaName = '',
  }) {
    return StudentProfileModel(
      uid: uid,
      name: user['name'] ?? '',
      profileImageUrl: user['profileImageUrl'] as String?,
      phone: _readNonEmptyString(user['phone']),
      halaqaId: profile['halaqaId'] as String?,
      halaqaName: _readNonEmptyString(profile['halaqaName']) ?? halaqaName,
      currentPlanName: profile['currentPlanName'] ?? '',
      overallProgressPercent: (profile['overallProgressPercent'] ?? 0)
          .toDouble(),
      totalVersesMemorized: (profile['totalVersesMemorized'] ?? 0) as int,
      completedJuz: (profile['completedJuz'] ?? 0) as int,
      completedSurahs: (profile['completedSurahs'] ?? 0) as int,
      points: (profile['points'] ?? 0) as int,
      streakDays: (profile['streakDays'] ?? 0) as int,
      level: (profile['level'] ?? 1) as int,
      totalStars: (profile['totalStars'] ?? 0) as int,
      badges: List<String>.from(profile['badges'] ?? []),
      coins: (profile['coins'] ?? 0) as int,
      avatarId: (profile['avatarId'] as String?) ?? 'fox',
      unlockedAvatarIds: profile['unlockedAvatarIds'] != null
          ? List<String>.from(profile['unlockedAvatarIds'])
          : const ['fox', 'panda', 'lion', 'rabbit', 'owl'],
      createdAt:
          _readDate(profile['createdAt']) ?? _readDate(user['createdAt']),
    );
  }

  static String? _readNonEmptyString(dynamic raw) {
    final value = (raw as String?)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
