import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../domain/entities/award_entities.dart';

class GrantedAwardModel extends GrantedAwardEntity {
  const GrantedAwardModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    super.studentImageUrl,
    required super.type,
    super.note,
    required super.grantedBy,
    required super.halaqaId,
    required super.grantedAt,
  });

  factory GrantedAwardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final noteRaw = data[AchievementsFirestoreContract.noteField] as String?;
    final titleRaw = data[AchievementsFirestoreContract.titleField] as String?;
    final note = (noteRaw != null && noteRaw.trim().isNotEmpty)
        ? noteRaw
        : (titleRaw != null && titleRaw.trim().isNotEmpty ? titleRaw : null);

    return GrantedAwardModel(
      id: doc.id,
      studentId: data[AchievementsFirestoreContract.studentIdField] ?? '',
      studentName: data[AchievementsFirestoreContract.studentNameField] ?? '',
      studentImageUrl:
          data[AchievementsFirestoreContract.studentImageUrlField] as String?,
      type: AwardTypeInfo.fromKey(
        data[AchievementsFirestoreContract.typeField] ?? '',
      ),
      note: note,
      grantedBy: AchievementsFirestoreContract.resolveActor(data),
      halaqaId: data[AchievementsFirestoreContract.halaqaIdField] ?? '',
      grantedAt: AchievementsFirestoreContract.resolveDate(data),
    );
  }

  Map<String, dynamic> toFirestore() =>
      AchievementsFirestoreContract.teacherGrantFields(
        studentId: studentId,
        studentName: studentName,
        studentImageUrl: studentImageUrl,
        type: type.firestoreKey,
        note: note,
        grantedBy: grantedBy,
        halaqaId: halaqaId,
      );
}
