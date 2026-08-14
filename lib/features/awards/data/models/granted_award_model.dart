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
    super.title,
    super.description,
    super.imageUrl,
    super.imageStoragePath,
    super.localImagePath,
    required super.grantedBy,
    required super.halaqaId,
    super.halaqaName,
    super.halaqaIds,
    super.halaqaNames,
    required super.grantedAt,
    super.recipientStudentIds,
    super.recipientCount,
  });

  factory GrantedAwardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = AchievementsFirestoreContract.resolveTitle(data);
    final noteRaw = data[AchievementsFirestoreContract.noteField] as String?;
    final recipients =
        AchievementsFirestoreContract.resolveRecipientStudentIds(data);
    final studentId =
        (data[AchievementsFirestoreContract.studentIdField] as String?) ??
        (recipients.isNotEmpty ? recipients.first : '');

    return GrantedAwardModel(
      id: doc.id,
      studentId: studentId,
      studentName:
          data[AchievementsFirestoreContract.studentNameField] ?? '',
      studentImageUrl:
          data[AchievementsFirestoreContract.studentImageUrlField] as String?,
      type: AwardTypeInfo.fromKey(
        data[AchievementsFirestoreContract.typeField] ?? '',
      ),
      note: (noteRaw != null && noteRaw.trim().isNotEmpty) ? noteRaw : title,
      title: title,
      description: AchievementsFirestoreContract.resolveDescription(data),
      imageUrl: data[AchievementsFirestoreContract.imageUrlField] as String?,
      imageStoragePath:
          data[AchievementsFirestoreContract.imageStoragePathField] as String?,
      grantedBy: AchievementsFirestoreContract.resolveActor(data),
      halaqaId: data[AchievementsFirestoreContract.halaqaIdField] ?? '',
      halaqaName: data[AchievementsFirestoreContract.halaqaNameField] as String?,
      halaqaIds: AchievementsFirestoreContract.resolveHalaqaIds(data),
      halaqaNames: AchievementsFirestoreContract.resolveHalaqaNames(data),
      grantedAt: AchievementsFirestoreContract.resolveDate(data),
      recipientStudentIds: recipients,
      recipientCount: AchievementsFirestoreContract.resolveRecipientCount(data),
    );
  }

  Map<String, dynamic> toFirestore({
    String? imageUrl,
    String? imageStoragePath,
  }) => AchievementsFirestoreContract.teacherGrantFields(
    studentId: studentId,
    studentName: studentName,
    studentImageUrl: studentImageUrl,
    type: type.firestoreKey,
    title: displayTitle,
    note: displayTitle,
    description: description,
    grantedBy: grantedBy,
    halaqaId: halaqaId,
    halaqaName: halaqaName,
    halaqaIds: resolvedHalaqaIds,
    halaqaNames: resolvedHalaqaNames,
    recipientStudentIds: honoredStudentIds.toList(),
    recipientCount: recipientCount > 0
        ? recipientCount
        : honoredStudentIds.length,
    imageUrl: imageUrl ?? this.imageUrl,
    imageStoragePath: imageStoragePath ?? this.imageStoragePath,
  );

  factory GrantedAwardModel.fromEntity(GrantedAwardEntity award) {
    return GrantedAwardModel(
      id: award.id,
      studentId: award.studentId,
      studentName: award.studentName,
      studentImageUrl: award.studentImageUrl,
      type: award.type,
      note: award.note,
      title: award.title,
      description: award.description,
      imageUrl: award.imageUrl,
      imageStoragePath: award.imageStoragePath,
      localImagePath: award.localImagePath,
      grantedBy: award.grantedBy,
      halaqaId: award.halaqaId,
      halaqaName: award.halaqaName,
      halaqaIds: award.halaqaIds,
      halaqaNames: award.halaqaNames,
      grantedAt: award.grantedAt,
      recipientStudentIds: award.recipientStudentIds,
      recipientCount: award.recipientCount,
    );
  }
}
