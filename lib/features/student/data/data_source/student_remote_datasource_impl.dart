import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../../../shared/data/assignment_homework_fields_ensure.dart';
import '../../../../shared/domain/assignment_policy.dart';
import '../../../../shared/domain/merge_student_achievements.dart';
import '../../../../shared/data/models/achievement_model.dart';
import '../../../../shared/data/models/assignment_model.dart';
import '../../../../shared/data/models/halaqa_model.dart';
import '../../../../shared/data/models/recitation_record_model.dart';
import '../models/review_schedule_model.dart';
import '../models/student_profile_model.dart';

@LazySingleton(as: StudentRemoteDatasource)
class StudentRemoteDatasourceImpl implements StudentRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const StudentRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

  @override
  Future<StudentProfileModel> getStudentProfile(String uid) async {
    try {
      final results = await Future.wait([
        firestore.collection(FirestoreCollections.users).doc(uid).get(),
        firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(uid)
            .get(),
      ]);

      final userDoc = results[0];
      final profileDoc = results[1];

      if (!userDoc.exists || !profileDoc.exists) {
        throw const ServerException('لم يتم العثور على بيانات الطالب');
      }

      return StudentProfileModel.fromFirestore(
        userDoc: userDoc,
        profileDoc: profileDoc,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ReviewScheduleModel>> getMonthlyReviewSchedule({
    required String studentId,
    required DateTime month,
  }) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 1);

      final snapshot = await firestore
          .collection(FirestoreCollections.reviewSchedules)
          .where('studentId', isEqualTo: studentId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
          .orderBy('date')
          .get();

      return snapshot.docs.map(ReviewScheduleModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<RecitationRecordModel>> getRecitationRecords(
    String studentId,
  ) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.recitationRecords)
          .where('studentId', isEqualTo: studentId)
          .orderBy('date', descending: true)
          // Fetch extra so client-side pending filter still surfaces reviewed grades
          // when recent homework submits are waiting on the teacher.
          .limit(50)
          .get();

      return snapshot.docs
          .map(RecitationRecordModel.fromFirestore)
          // تقييمات المعلم فقط — استبعِد تسميعات الطالب المنتظرة للمراجعة
          .where((r) => !r.isPendingReview)
          .take(20)
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AchievementModel>> getAchievements(String studentId) async {
    try {
      final collection = firestore.collection(
        FirestoreCollections.achievements,
      );
      // Query separately so a missing index / secondary failure still returns
      // the primary studentId list instead of a generic red error.
      final byStudentId = <AchievementModel>[];
      final byRecipients = <AchievementModel>[];
      // Full merge for readers that need the complete set (badges stats,
      // supervisor reader). Paged UI uses [getAchievementsPage].
      try {
        final snap = await collection
            .where('studentId', isEqualTo: studentId)
            .get();
        for (final doc in snap.docs) {
          byStudentId.add(AchievementModel.fromFirestore(doc));
        }
      } catch (_) {
        // continue — try recipients query
      }
      try {
        final snap = await collection
            .where(
              AchievementsFirestoreContract.recipientStudentIdsField,
              arrayContains: studentId,
            )
            .get();
        for (final doc in snap.docs) {
          byRecipients.add(AchievementModel.fromFirestore(doc));
        }
      } catch (_) {
        // optional secondary path
      }
      if (byStudentId.isEmpty && byRecipients.isEmpty) {
        // Both failed or empty — probe once more; empty is OK, hard fail only
        // when the primary path throws and we have nothing.
        final snap = await collection
            .where('studentId', isEqualTo: studentId)
            .get();
        for (final doc in snap.docs) {
          byStudentId.add(AchievementModel.fromFirestore(doc));
        }
      }
      return mergeStudentAchievements(
        byStudentId,
        byRecipients,
      ).whereType<AchievementModel>().toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw const ServerException('تعذر تحميل الإنجازات. حاول مرة أخرى.');
    }
  }

  @override
  Future<
    ({
      List<AchievementModel> items,
      String? studentCursorId,
      String? recipientsCursorId,
      bool hasMoreStudent,
      bool hasMoreRecipients,
    })
  >
  getAchievementsPage({
    required String studentId,
    int limit = 20,
    String? afterStudentAchievementId,
    String? afterRecipientsAchievementId,
  }) async {
    try {
      final uid = studentId.trim();
      if (uid.isEmpty) {
        return (
          items: const <AchievementModel>[],
          studentCursorId: null,
          recipientsCursorId: null,
          hasMoreStudent: false,
          hasMoreRecipients: false,
        );
      }
      final pageSize = limit < 1 ? 20 : limit;
      final collection = firestore.collection(
        FirestoreCollections.achievements,
      );

      Future<QuerySnapshot<Map<String, dynamic>>> page({
        required Query<Map<String, dynamic>> base,
        required String? afterId,
      }) async {
        var q = base.orderBy('date', descending: true).limit(pageSize);
        final tip = afterId?.trim() ?? '';
        if (tip.isNotEmpty) {
          final cursor = await collection.doc(tip).get();
          if (cursor.exists) q = q.startAfterDocument(cursor);
        }
        return q.get();
      }

      final studentSnap = await page(
        base: collection.where('studentId', isEqualTo: uid),
        afterId: afterStudentAchievementId,
      );
      final recipientsSnap = await page(
        base: collection.where(
          AchievementsFirestoreContract.recipientStudentIdsField,
          arrayContains: uid,
        ),
        afterId: afterRecipientsAchievementId,
      );

      final byStudent = [
        for (final d in studentSnap.docs) AchievementModel.fromFirestore(d),
      ];
      final byRecipients = [
        for (final d in recipientsSnap.docs) AchievementModel.fromFirestore(d),
      ];
      final items = mergeStudentAchievements(
        byStudent,
        byRecipients,
      ).whereType<AchievementModel>().toList();

      return (
        items: items,
        studentCursorId: studentSnap.docs.isEmpty
            ? afterStudentAchievementId
            : studentSnap.docs.last.id,
        recipientsCursorId: recipientsSnap.docs.isEmpty
            ? afterRecipientsAchievementId
            : recipientsSnap.docs.last.id,
        hasMoreStudent: studentSnap.docs.length >= pageSize,
        hasMoreRecipients: recipientsSnap.docs.length >= pageSize,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'تعذر تحميل الإنجازات. حاول مرة أخرى.');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw const ServerException('تعذر تحميل الإنجازات. حاول مرة أخرى.');
    }
  }

  @override
  Future<AssignmentModel?> getLatestAssignment(String studentId) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.assignments)
          .where(AssignmentPolicy.studentIdField, isEqualTo: studentId)
          .orderBy(AssignmentPolicy.dueDateField, descending: true)
          .limit(AssignmentPolicy.latestScanLimit)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!AssignmentPolicy.isLessonHomeworkData(data)) continue;
        await AssignmentHomeworkFieldsEnsure.ensureOnDocument(doc);
        final refreshed = await doc.reference.get();
        return AssignmentModel.fromFirestore(refreshed);
      }
      return null;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<HalaqaModel> getStudentHalaqa(String halaqaId) async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();

      if (!doc.exists) {
        throw const ServerException('لم يتم العثور على بيانات الحلقة');
      }

      return HalaqaModel.fromFirestore(doc);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<AssignmentModel?> watchLatestAssignment(String studentId) {
    return firestore
        .collection(FirestoreCollections.assignments)
        .where(AssignmentPolicy.studentIdField, isEqualTo: studentId)
        .orderBy(AssignmentPolicy.dueDateField, descending: true)
        .limit(AssignmentPolicy.latestScanLimit)
        .snapshots()
        .asyncMap((snapshot) async {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (!AssignmentPolicy.isLessonHomeworkData(data)) continue;
            await AssignmentHomeworkFieldsEnsure.ensureOnDocument(doc);
            final refreshed = await doc.reference.get();
            return AssignmentModel.fromFirestore(refreshed);
          }
          return null;
        });
  }

  /// Economy (PH-02): the purchaseAvatar callable prices the avatar from the
  /// trusted catalog and debits atomically. Only [avatarId] is sent — the
  /// client-computed [unlockedAvatarIds] / [coins] are display-only.
  @override
  Future<void> updateAvatarSelection({
    required String studentId,
    required String avatarId,
    required List<String> unlockedAvatarIds,
    required int coins,
  }) async {
    try {
      final callable = functions.httpsCallable('purchaseAvatar');
      await callable.call(<String, dynamic>{'avatarId': avatarId.trim()});
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
