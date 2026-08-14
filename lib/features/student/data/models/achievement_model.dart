import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../../awards/domain/entities/award_entities.dart';
import '../../domain/entities/achievement_entity.dart';

class AchievementModel extends AchievementEntity {
  const AchievementModel({
    required super.id,
    required super.studentId,
    required super.type,
    required super.title,
    required super.issuedBy,
    required super.date,
  });

  factory AchievementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AchievementModel(
      id: doc.id,
      studentId: data[AchievementsFirestoreContract.studentIdField] ?? '',
      type: typeFromFirestoreKey(
        data[AchievementsFirestoreContract.typeField] ?? '',
      ),
      title: AchievementsFirestoreContract.resolveTitle(data),
      issuedBy: AchievementsFirestoreContract.resolveActor(data),
      date: AchievementsFirestoreContract.resolveDate(data),
    );
  }

  /// Legacy supervisor-shaped map (unused as a live writer after H7 dual-write).
  Map<String, dynamic> toFirestore() => {
    AchievementsFirestoreContract.studentIdField: studentId,
    AchievementsFirestoreContract.typeField: _typeToString(type),
    AchievementsFirestoreContract.titleField: title,
    AchievementsFirestoreContract.issuedByField: issuedBy,
    AchievementsFirestoreContract.dateField: Timestamp.fromDate(date),
  };

  static AchievementType typeFromFirestoreKey(String value) {
    for (final type in AwardType.values) {
      if (type.firestoreKey == value) {
        return switch (type) {
          AwardType.completionBadge => AchievementType.completionBadge,
          AwardType.performanceStars => AchievementType.performanceStars,
          AwardType.perfectAttendance => AchievementType.perfectAttendance,
          AwardType.studentOfWeek => AchievementType.studentOfWeek,
        };
      }
    }
    return switch (value) {
      'star' => AchievementType.star,
      'badge' => AchievementType.badge,
      'certificate' => AchievementType.certificate,
      _ => AchievementType.star,
    };
  }

  static String _typeToString(AchievementType type) {
    final award = type.awardType;
    if (award != null) return award.firestoreKey;
    return switch (type) {
      AchievementType.star => 'star',
      AchievementType.badge => 'badge',
      AchievementType.certificate => 'certificate',
      AchievementType.completionBadge => AwardType.completionBadge.firestoreKey,
      AchievementType.performanceStars =>
        AwardType.performanceStars.firestoreKey,
      AchievementType.perfectAttendance =>
        AwardType.perfectAttendance.firestoreKey,
      AchievementType.studentOfWeek => AwardType.studentOfWeek.firestoreKey,
    };
  }
}
