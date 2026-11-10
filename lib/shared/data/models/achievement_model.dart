import 'package:cloud_firestore/cloud_firestore.dart';

import '../achievements_firestore_contract.dart';
import '../../../features/awards/domain/entities/award_entities.dart';
import '../../domain/achievement_entity.dart';

class AchievementModel extends AchievementEntity {
  const AchievementModel({
    required super.id,
    required super.studentId,
    required super.type,
    required super.title,
    super.description,
    super.imageUrl,
    required super.issuedBy,
    required super.date,
    super.recipientStudentIds,
  });

  factory AchievementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final recipients = AchievementsFirestoreContract.resolveRecipientStudentIds(
      data,
    );
    return AchievementModel(
      id: doc.id,
      studentId:
          data[AchievementsFirestoreContract.studentIdField] ??
          (recipients.isNotEmpty ? recipients.first : ''),
      type: typeFromFirestoreKey(
        data[AchievementsFirestoreContract.typeField] ?? '',
      ),
      title: AchievementsFirestoreContract.resolveTitle(data),
      description: AchievementsFirestoreContract.resolveDescription(data),
      imageUrl: data[AchievementsFirestoreContract.imageUrlField] as String?,
      issuedBy: AchievementsFirestoreContract.resolveActor(data),
      date: AchievementsFirestoreContract.resolveDate(data),
      recipientStudentIds: recipients,
    );
  }

  /// One entry of the `getParentAchievements` callable response (already
  /// projected server-side; `dateMillis` is epoch milliseconds).
  factory AchievementModel.fromParentCallable(Map<String, dynamic> data) {
    final millis = data['dateMillis'];
    final resolvable = <String, dynamic>{
      ...data,
      AchievementsFirestoreContract.dateField: millis is num
          ? DateTime.fromMillisecondsSinceEpoch(millis.toInt())
          : null,
    };
    final recipients = AchievementsFirestoreContract.resolveRecipientStudentIds(
      resolvable,
    );
    final studentId =
        (data[AchievementsFirestoreContract.studentIdField] as String?)
            ?.trim() ??
        '';
    final imageUrl =
        (data[AchievementsFirestoreContract.imageUrlField] as String?)?.trim();
    return AchievementModel(
      id: (data['id'] as String?)?.trim() ?? '',
      studentId: studentId.isNotEmpty
          ? studentId
          : (recipients.isNotEmpty ? recipients.first : ''),
      type: typeFromFirestoreKey(
        (data[AchievementsFirestoreContract.typeField] as String?) ?? '',
      ),
      title: AchievementsFirestoreContract.resolveTitle(resolvable),
      description: AchievementsFirestoreContract.resolveDescription(resolvable),
      imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      issuedBy: AchievementsFirestoreContract.resolveActor(resolvable),
      date: AchievementsFirestoreContract.resolveDate(resolvable),
      recipientStudentIds: recipients,
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
          AwardType.attendance => AchievementType.attendance,
          AwardType.completion => AchievementType.completion,
          AwardType.performance => AchievementType.performance,
          AwardType.achievement => AchievementType.achievement,
          AwardType.custom => AchievementType.custom,
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
      _ => type.awardType?.firestoreKey ?? 'star',
    };
  }
}
