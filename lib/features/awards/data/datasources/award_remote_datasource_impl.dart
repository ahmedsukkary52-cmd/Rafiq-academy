import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../domain/entities/award_entities.dart';
import '../award_image_storage_path.dart';
import '../models/granted_award_model.dart';
import 'award_remote_datasource.dart';

@LazySingleton(as: AwardsRemoteDatasource)
class AwardsRemoteDatasourceImpl implements AwardsRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  const AwardsRemoteDatasourceImpl({
    required this.firestore,
    required this.storage,
  });

  CollectionReference get _awardsRef =>
      firestore.collection(FirestoreCollections.achievements);

  static const _profileOpsPerBatch = 400;

  @override
  Future<AwardsStatsEntity> getAwardsStats(String halaqaId) async {
    try {
      final grants = await _grantsForHalaqa(halaqaId);
      return computeAwardsStats(grants);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<GrantedAwardModel>> getGrantedAwards(String halaqaId) async {
    try {
      return await _grantsForHalaqa(halaqaId, limit: 50);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<GrantedAwardModel>> _grantsForHalaqa(
    String halaqaId, {
    int? limit,
  }) async {
    final byIdSnap = await _awardsRef
        .where(AchievementsFirestoreContract.halaqaIdField, isEqualTo: halaqaId)
        .get();
    final byIdsSnap = await _awardsRef
        .where(
          AchievementsFirestoreContract.halaqaIdsField,
          arrayContains: halaqaId,
        )
        .get();
    final byId = byIdSnap.docs.map(GrantedAwardModel.fromFirestore);
    final byIds = byIdsSnap.docs.map(GrantedAwardModel.fromFirestore);
    return mergeHalaqaScopedAwards(
      byHalaqaIdField: byId,
      byHalaqaIdsField: byIds,
      idOf: (grant) => grant.id,
      grantedAtOf: (grant) => grant.grantedAt,
      limit: limit,
    );
  }

  @override
  Future<void> grantAward(GrantedAwardModel award) async {
    try {
      final recipientIds = award.honoredStudentIds.toList();
      if (recipientIds.isEmpty) {
        throw const ServerException('يجب اختيار طالب واحد على الأقل');
      }

      var imageUrl = award.imageUrl;
      var imageStoragePath = award.imageStoragePath;
      final localPath = award.localImagePath?.trim();
      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        final ext = localPath.split('.').last;
        imageStoragePath = awardImageStoragePath(
          teacherId: award.grantedBy,
          extension: ext,
        );
        final ref = storage.ref(imageStoragePath);
        await ref.putFile(file);
        imageUrl = await ref.getDownloadURL();
      }

      final payload = award.toFirestore(
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
      );
      final awardRef = _awardsRef.doc();

      var remaining = [...recipientIds];
      var wroteAward = false;
      while (!wroteAward || remaining.isNotEmpty) {
        final batch = firestore.batch();
        if (!wroteAward) {
          batch.set(awardRef, payload);
          wroteAward = true;
        }
        final chunk = remaining.take(_profileOpsPerBatch).toList();
        remaining = remaining.skip(_profileOpsPerBatch).toList();
        for (final studentId in chunk) {
          final profileRef = firestore
              .collection(FirestoreCollections.studentProfiles)
              .doc(studentId);
          batch.update(profileRef, {
            'points': FieldValue.increment(10),
            'totalStars': FieldValue.increment(1),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
