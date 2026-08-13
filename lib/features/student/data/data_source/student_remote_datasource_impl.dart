import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/assignment_homework_fields_ensure.dart';
import '../../../../shared/domain/assignment_policy.dart';
import '../models/achievement_model.dart';
import '../models/assignment_model.dart';
import '../models/halaqa_model.dart';
import '../models/recitation_record_model.dart';
import '../models/review_schedule_model.dart';
import '../models/student_profile_model.dart';

@LazySingleton(as: StudentRemoteDatasource)
class StudentRemoteDatasourceImpl implements StudentRemoteDatasource {
  final FirebaseFirestore firestore;

  const StudentRemoteDatasourceImpl({required this.firestore});

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
      // No orderBy('date'): teacher Awards docs use `grantedAt` instead of
      // `date` and would be excluded from an ordered query.
      final snapshot = await firestore
          .collection(FirestoreCollections.achievements)
          .where('studentId', isEqualTo: studentId)
          .get();

      final achievements =
          snapshot.docs.map(AchievementModel.fromFirestore).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      return achievements;
    } catch (e) {
      throw ServerException(e.toString());
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

  @override
  Future<void> updateAvatarSelection({
    required String studentId,
    required String avatarId,
    required List<String> unlockedAvatarIds,
    required int coins,
  }) async {
    try {
      await firestore
          .collection(FirestoreCollections.studentProfiles)
          .doc(studentId)
          .update({
            'avatarId': avatarId,
            'unlockedAvatarIds': unlockedAvatarIds,
            'coins': coins,
          });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
