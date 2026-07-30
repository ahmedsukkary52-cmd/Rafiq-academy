import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/achievements_firestore_contract.dart';
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
      type: _typeFromString(
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

  static AchievementType _typeFromString(String value) => switch (value) {
    'star' => AchievementType.star,
    'badge' => AchievementType.badge,
    'certificate' => AchievementType.certificate,
    _ => AchievementType.star,
  };

  static String _typeToString(AchievementType type) => switch (type) {
    AchievementType.star => 'star',
    AchievementType.badge => 'badge',
    AchievementType.certificate => 'certificate',
  };
}
