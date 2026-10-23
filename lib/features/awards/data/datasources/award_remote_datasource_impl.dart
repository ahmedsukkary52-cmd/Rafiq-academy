import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../../../shared/domain/upload_file_policy.dart';
import '../../domain/award_submission_id.dart';
import '../../domain/entities/award_entities.dart';
import '../award_grant_errors.dart';
import '../award_image_storage_path.dart';
import '../models/granted_award_model.dart';
import 'award_remote_datasource.dart';

@LazySingleton(as: AwardsRemoteDatasource)
class AwardsRemoteDatasourceImpl implements AwardsRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseFunctions functions;

  const AwardsRemoteDatasourceImpl({
    required this.firestore,
    required this.storage,
    required this.functions,
  });

  CollectionReference get _awardsRef =>
      firestore.collection(FirestoreCollections.achievements);

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
    var requestSent = false;
    try {
      final recipientIds = award.honoredStudentIds.toList();
      if (recipientIds.isEmpty) {
        throw const ServerException('يجب اختيار طالب واحد على الأقل');
      }
      if (!AwardSubmissionId.isValid(award.id)) {
        throw const ServerException(kAwardGrantFailedMessage);
      }

      var imageUrl = award.imageUrl;
      var imageStoragePath = award.imageStoragePath;
      final localPath = award.localImagePath?.trim();
      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        final check = await UploadFilePolicy.checkFile(
          file,
          formats: awardImageFormats,
        );
        final format = check.format;
        if (format == null) {
          throw ServerException(check.error ?? 'صيغة الصورة غير مدعومة');
        }
        imageStoragePath = awardImageStoragePath(
          teacherId: award.grantedBy,
          extension: format.extension,
        );
        final ref = storage.ref(imageStoragePath);
        await ref.putFile(
          file,
          SettableMetadata(contentType: format.contentType),
        );
        imageUrl = await ref.getDownloadURL();
      }

      // The server writes the award and credits stars atomically; the
      // caller's per-submission id makes a replayed call a no-op.
      final callable = functions.httpsCallable('grantAward');
      requestSent = true;
      await callable.call(<String, dynamic>{
        'awardId': award.id,
        'type': award.type.firestoreKey,
        'title': award.displayTitle,
        'description': award.description?.trim() ?? '',
        'studentName': award.studentName,
        'studentImageUrl': award.studentImageUrl ?? '',
        'halaqaId': award.halaqaId,
        'halaqaIds': award.resolvedHalaqaIds,
        'recipientStudentIds': recipientIds,
        'imageUrl': imageUrl ?? '',
        'imageStoragePath': imageStoragePath ?? '',
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(awardGrantErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        awardGrantUnexpectedErrorMessage(requestSent: requestSent),
      );
    }
  }
}
