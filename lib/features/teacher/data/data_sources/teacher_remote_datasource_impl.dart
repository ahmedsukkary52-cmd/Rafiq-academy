import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../student/data/models/assignment_model.dart';
import '../../../student/data/models/halaqa_model.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
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
      final dayStart = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));
      final normalized = AttendanceRecordModel(
        id: record.id,
        studentId: record.studentId,
        studentName: record.studentName,
        halaqaId: record.halaqaId,
        date: dayStart,
        status: record.status,
        recordedBy: record.recordedBy,
      );

      final existing = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('halaqaId', isEqualTo: record.halaqaId)
          .where('studentId', isEqualTo: record.studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThan: Timestamp.fromDate(dayEnd))
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update(normalized.toFirestore());
      } else {
        await firestore
            .collection(FirestoreCollections.attendanceRecords)
            .add(normalized.toFirestore());
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final snapshot = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('halaqaId', isEqualTo: halaqaId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      return snapshot.docs.map(AttendanceRecordModel.fromFirestore).toList();
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
  Future<void> updateRecitationReview({
    required String recordId,
    required RecitationGrade grade,
    required RecitationGrade behaviorGrade,
    String? notes,
  }) async {
    try {
      final ref = firestore
          .collection(FirestoreCollections.recitationRecords)
          .doc(recordId);

      await firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) {
          throw const ServerException('سجل التسميع غير موجود');
        }
        final data = snap.data()!;
        final status = data['reviewStatus'] as String? ?? 'reviewed';
        if (status != 'pending') {
          throw const ServerException('تم تقييم هذا التسميع مسبقاً');
        }

        final trimmed = notes?.trim();
        txn.update(ref, {
          'reviewStatus': 'reviewed',
          'grade': grade.label,
          'behaviorGrade': behaviorGrade.label,
          'notes': (trimmed != null && trimmed.isNotEmpty)
              ? trimmed
              : FieldValue.delete(),
        });

        final studentId = data['studentId'] as String? ?? '';
        if (studentId.isNotEmpty) {
          final notifRef = firestore
              .collection(FirestoreCollections.notifications)
              .doc();
          txn.set(notifRef, {
            'audience': studentId,
            'title': 'تم تقييم تسميعك',
            'body': 'راجع صفحة التقييمات لمعرفة الدرجة والملاحظات',
            'type': NotificationTypes.assignment,
            'readBy': <String>[],
            'hasAudioAlert': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<RecitationRecordModel>> getHalaqaRecitationRecords(
    String halaqaId,
  ) async {
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.recitationRecords)
          .where('halaqaId', isEqualTo: halaqaId)
          .get();

      final records = snapshot.docs
          .map(RecitationRecordModel.fromFirestore)
          .toList();
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
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

      if (!halaqaDoc.exists) {
        throw const ServerException('الحلقة غير موجودة');
      }

      final data = halaqaDoc.data() as Map<String, dynamic>;
      final studentIds = List<String>.from(data['studentIds'] ?? []);
      if (studentIds.isEmpty) {
        throw const ServerException(
          'لا يوجد طلاب في هذه الحلقة لإرسال التكليف',
        );
      }

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
          // نفس مستند التكليف يحمل حقول واجباتي (Single Source of Truth)
          ...AssignmentModel.defaultHomeworkFields(
            newMemorizationRange: newMemorizationRange,
            reviewRange: reviewRange,
          ),
        });

        final notifRef = firestore
            .collection(FirestoreCollections.notifications)
            .doc();
        final rangeHint = newMemorizationRange.trim().isNotEmpty
            ? newMemorizationRange.trim()
            : reviewRange.trim();
        batch.set(notifRef, {
          'audience': studentId,
          'title': 'تكليف جديد',
          'body': rangeHint.isEmpty
              ? 'لديك تكليف جديد — افتح واجباتي'
              : 'تكليف جديد: $rangeHint — افتح واجباتي',
          'type': NotificationTypes.assignment,
          'readBy': <String>[],
          'hasAudioAlert': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
