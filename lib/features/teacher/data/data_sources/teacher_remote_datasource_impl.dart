import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/utils/attendance_absence_transitions.dart';
import '../../../../shared/utils/attendance_policy.dart';
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
    await saveDayAttendance([record]);
  }

  @override
  Future<List<AcademyEvent>> saveDayAttendance(
    List<AttendanceRecordModel> records,
  ) async {
    try {
      if (records.isEmpty) return const [];

      final halaqaId = records.first.halaqaId;
      final dayStart = AttendancePolicy.dayStart(records.first.date);
      final dayEnd = AttendancePolicy.dayEndExclusive(records.first.date);

      final existingSnap = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('halaqaId', isEqualTo: halaqaId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      // Raw pre-save statuses; AttendanceRecordModel is deliberately not used
      // here because it maps unknown → absent.
      final previousStatuses =
          AttendanceAbsenceTransitions.previousStatusByStudent(
            existingSnap.docs.map((doc) {
              final data = doc.data();
              return AttendanceMarkRef(
                id: doc.id,
                halaqaId: (data['halaqaId'] as String?) ?? halaqaId,
                studentId: (data['studentId'] as String?) ?? '',
                date: dayStart,
                status: data['status'] as String?,
              );
            }),
          );

      // Firestore batch max is 500 ops; keep day save atomic (no split commits).
      final estimatedOps = records.length + existingSnap.docs.length;
      if (estimatedOps > 500) {
        throw const ServerException(
          'عدد سجلات الحضور كبير جداً للحفظ دفعة واحدة. قلّل حجم الحلقة أو أعد المحاولة لاحقاً.',
        );
      }

      final batch = firestore.batch();
      final savedStudentIds = <String>{};

      for (final record in records) {
        final normalizedDay = AttendancePolicy.dayStart(record.date);
        final docId = AttendancePolicy.documentId(
          halaqaId: record.halaqaId,
          studentId: record.studentId,
          date: normalizedDay,
        );
        final normalized = AttendanceRecordModel(
          id: docId,
          studentId: record.studentId,
          studentName: record.studentName,
          halaqaId: record.halaqaId,
          date: normalizedDay,
          status: record.status,
          recordedBy: record.recordedBy,
        );
        final ref = firestore
            .collection(FirestoreCollections.attendanceRecords)
            .doc(docId);
        batch.set(ref, normalized.toFirestore(), SetOptions(merge: true));
        savedStudentIds.add(record.studentId);
      }

      // Remove legacy auto-id duplicates for the same students/day.
      for (final doc in existingSnap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String? ?? '';
        if (!savedStudentIds.contains(studentId)) continue;
        final expectedId = AttendancePolicy.documentId(
          halaqaId: halaqaId,
          studentId: studentId,
          date: dayStart,
        );
        if (doc.id != expectedId) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

      // Derived only from a committed save: no events for failed writes.
      return AttendanceAbsenceTransitions.project(
        previousStatusByStudentId: previousStatuses,
        currentMarks: records.map(
          (record) => AttendanceMarkInput(
            studentId: record.studentId,
            studentName: record.studentName,
            halaqaId: record.halaqaId,
            date: record.date,
            status: record.wireStatus,
          ),
        ),
      );
    } on ServerException {
      rethrow;
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
      final dayStart = AttendancePolicy.dayStart(date);
      final dayEnd = AttendancePolicy.dayEndExclusive(date);

      final snapshot = await firestore
          .collection(FirestoreCollections.attendanceRecords)
          .where('halaqaId', isEqualTo: halaqaId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      // One record per student — prefer deterministic doc id when duplicates exist.
      final byStudent = <String, AttendanceRecordModel>{};
      for (final doc in snapshot.docs) {
        final model = AttendanceRecordModel.fromFirestore(doc);
        final preferredId = AttendancePolicy.documentId(
          halaqaId: halaqaId,
          studentId: model.studentId,
          date: dayStart,
        );
        final existing = byStudent[model.studentId];
        if (existing == null || model.id == preferredId) {
          byStudent[model.studentId] = model;
        }
      }
      return byStudent.values.toList();
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
  Future<List<AcademyEvent>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) async {
    try {
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

      // One assignment write per student (notifications are not written here).
      if (studentIds.length > 500) {
        throw const ServerException(
          'عدد طلاب الحلقة كبير جداً لإرسال التكليف دفعة واحدة.',
        );
      }

      final batch = firestore.batch();
      final events = <AcademyEvent>[];

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

        events.add(
          HomeworkAssigned(
            assignmentId: ref.id,
            studentId: studentId,
            halaqaId: halaqaId,
            assignedBy: teacherId,
            dueDate: dueDate,
            newMemorizationRange: newMemorizationRange,
            reviewRange: reviewRange,
          ),
        );
      }

      await batch.commit();
      return events;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<DateTime?> getLatestAssignmentDueDate(String halaqaId) async {
    try {
      // Same ordering as W1 student "current homework" (latest dueDate),
      // scoped to the halaqa so the teacher agenda reuses D7, not a second rule.
      final snapshot = await firestore
          .collection(FirestoreCollections.assignments)
          .where('halaqaId', isEqualTo: halaqaId)
          .orderBy('dueDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final raw = snapshot.docs.first.data()['dueDate'];
      if (raw is Timestamp) return raw.toDate();
      return null;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
