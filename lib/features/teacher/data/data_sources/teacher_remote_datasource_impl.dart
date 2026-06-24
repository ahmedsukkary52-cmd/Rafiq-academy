import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../student/data/models/halaqa_model.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../models/attendance_record_model.dart';
import '../models/halaqa_student_summary_model.dart';

@LazySingleton(as: TeacherRemoteDatasource)
class TeacherRemoteDatasourceImpl implements TeacherRemoteDatasource {
  final FirebaseFirestore firestore;

  const TeacherRemoteDatasourceImpl({required this.firestore});

  @override
  Future<List<HalaqaModel>> getTeacherHalaqat(String teacherId) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.halaqat)
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: 'active')
          .get();
      return snapshot.docs.map(HalaqaModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<HalaqaStudentSummaryModel>> getHalaqaStudents(
    String halaqaId,
  ) async {
    try {
      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();

      if (!halaqaDoc.exists) throw const ServerException('الحلقة غير موجودة');

      final data = halaqaDoc.data() as Map<String, dynamic>;
      final studentIds = List<String>.from(data['studentIds'] ?? []);

      if (studentIds.isEmpty) return [];

      final usersSnap = await firestore
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: studentIds)
          .get();

      return usersSnap.docs
          .map(HalaqaStudentSummaryModel.fromFirestore)
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> recordAttendance(AttendanceRecordModel record) async {
    try {
      await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .add(record.toFirestore());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> addRecitationRecord(RecitationRecordModel record) async {
    try {
      await firestore
          .collection(FirestoreCollections.recitationRecords)
          .add(record.toFirestore());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) async {
    try {
      // نجيب طلاب الحلقة ونبعت تكليف لكل واحد
      final halaqaDoc = await firestore
          .collection(FirestoreCollections.halaqat)
          .doc(halaqaId)
          .get();

      final data = halaqaDoc.data() as Map<String, dynamic>;
      final studentIds = List<String>.from(data['studentIds'] ?? []);

      final batch = firestore.batch();
      for (final studentId in studentIds) {
        final ref = firestore
            .collection(FirestoreCollections.assignments)
            .doc();
        batch.set(ref, {
          'studentId': studentId,
          'halaqaId': halaqaId,
          'assignedBy': teacherId,
          'newMemorizationRange': newMemorizationRange,
          'reviewRange': reviewRange,
          'dueDate': Timestamp.fromDate(dueDate),
        });
      }
      await batch.commit();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
