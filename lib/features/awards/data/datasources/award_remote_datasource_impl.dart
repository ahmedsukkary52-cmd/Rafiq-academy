import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/award_entities.dart';
import '../models/granted_award_model.dart';
import 'award_remote_datasource.dart';

@LazySingleton(as: AwardsRemoteDatasource)
class AwardsRemoteDatasourceImpl implements AwardsRemoteDatasource {
  final FirebaseFirestore firestore;

  const AwardsRemoteDatasourceImpl({required this.firestore});

  CollectionReference get _awardsRef =>
      firestore.collection(FirestoreCollections.achievements);

  @override
  Future<AwardsStatsEntity> getAwardsStats(String halaqaId) async {
    try {
      final startOfMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );

      final results = await Future.wait([
        _awardsRef.where('halaqaId', isEqualTo: halaqaId).get(),
        _awardsRef
            .where('halaqaId', isEqualTo: halaqaId)
            .where(
              'grantedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .get(),
      ]);

      final allDocs = results[0].docs;
      final thisMonthDocs = results[1].docs;

      // إجمالي الطلاب المستفيدين (بدون تكرار)
      final uniqueStudents = allDocs
          .map((d) => (d.data() as Map<String, dynamic>)['studentId'] as String)
          .toSet();

      return AwardsStatsEntity(
        totalRecipients: uniqueStudents.length,
        thisMonthCount: thisMonthDocs.length,
        totalAwardsCount: allDocs.length,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<GrantedAwardModel>> getGrantedAwards(String halaqaId) async {
    try {
      final snap = await _awardsRef
          .where('halaqaId', isEqualTo: halaqaId)
          .orderBy('grantedAt', descending: true)
          .limit(50)
          .get();

      return snap.docs.map(GrantedAwardModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> grantAward(GrantedAwardModel award) async {
    try {
      final batch = firestore.batch();

      // إضافة الجائزة في achievements collection
      final awardRef = _awardsRef.doc();
      batch.set(awardRef, award.toFirestore());

      // تحديث نقاط الطالب في studentProfiles (+10 نقطة لكل جائزة)
      final profileRef = firestore
          .collection(FirestoreCollections.studentProfiles)
          .doc(award.studentId);
      batch.update(profileRef, {
        'points': FieldValue.increment(10),
        'totalStars': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
