import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/student/data/data_source/student_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
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
          .limit(20)
          .get();

      return snapshot.docs
          .map(RecitationRecordModel.fromFirestore)
          // تقييمات المعلم فقط — استبعِد تسميعات الطالب المنتظرة للمراجعة
          .where((r) => !r.isPendingReview)
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AchievementModel>> getAchievements(String studentId) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.achievements)
          .where('studentId', isEqualTo: studentId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map(AchievementModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AssignmentModel?> getLatestAssignment(String studentId) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.assignments)
          .where('studentId', isEqualTo: studentId)
          .orderBy('dueDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      await _ensureHomeworkFieldsOnAssignment(doc);
      final refreshed = await doc.reference.get();
      return AssignmentModel.fromFirestore(refreshed);
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
        .where('studentId', isEqualTo: studentId)
        .orderBy('dueDate', descending: true)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          await _ensureHomeworkFieldsOnAssignment(doc);
          final refreshed = await doc.reference.get();
          return AssignmentModel.fromFirestore(refreshed);
        });
  }

  /// يزرع حقول واجباتي على نفس مستند `assignments` لو ناقصة (مش collection منفصل).
  Future<void> _ensureHomeworkFieldsOnAssignment(DocumentSnapshot doc) async {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) return;
    final tasks = raw['tasks'];
    if (tasks is List && tasks.isNotEmpty) return;

    final seed = AssignmentModel.defaultHomeworkFields(
      newMemorizationRange: raw['newMemorizationRange'] as String? ?? '',
      reviewRange: raw['reviewRange'] as String? ?? '',
    );
    await doc.reference.set(seed, SetOptions(merge: true));
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
