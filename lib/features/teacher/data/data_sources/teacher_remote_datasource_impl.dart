import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/absence_request_firestore_reads.dart';
import '../../../../shared/data/absence_request_model.dart';
import '../../../../shared/domain/absence_request.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/assignment_policy.dart';
import '../../../../shared/utils/attendance_absence_transitions.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/utils/firestore_in_query.dart';
import '../../../student/data/models/assignment_model.dart';
import '../../../student/data/models/halaqa_model.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../domain/services/halaqa_student_summary_projector.dart';
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

      // Firestore whereIn max 30 — chunk so large rosters do not hard-fail (H5).
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final chunk in FirestoreInQuery.chunkIds(studentIds)) {
        final usersSnap = await firestore
            .collection(FirestoreCollections.users)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        docs.addAll(usersSnap.docs);
      }

      final bases =
          docs.map(HalaqaStudentSummaryModel.fromFirestore).toList();

      final now = DateTime.now();
      final from = now.subtract(
        const Duration(days: HalaqaStudentSummaryProjector.attendanceWindowDays),
      );

      final parallel = await Future.wait([
        firestore
            .collection(FirestoreCollections.attendanceRecords)
            .where('halaqaId', isEqualTo: halaqaId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .get(),
        firestore
            .collection(FirestoreCollections.recitationRecords)
            .where('halaqaId', isEqualTo: halaqaId)
            .get(),
        _loadProgressByStudentId(studentIds),
      ]);

      final attendanceSnap =
          parallel[0] as QuerySnapshot<Map<String, dynamic>>;
      final recitationSnap =
          parallel[1] as QuerySnapshot<Map<String, dynamic>>;
      final progressById = parallel[2] as Map<String, double>;

      final marks = attendanceSnap.docs.map((doc) {
        final d = doc.data();
        final rawDate = d['date'];
        final date = rawDate is Timestamp ? rawDate.toDate() : now;
        return AttendanceMarkRef(
          id: doc.id,
          halaqaId: halaqaId,
          studentId: (d['studentId'] as String?) ?? '',
          date: date,
          status: d['status'] as String?,
          sessionId: d['sessionId'] as String?,
        );
      });

      final recitations = recitationSnap.docs
          .map(RecitationRecordModel.fromFirestore)
          .toList();

      return bases
          .map(
            (base) => HalaqaStudentSummaryModel.fromEntity(
              HalaqaStudentSummaryProjector.enrich(
                base: base,
                attendanceMarks: marks,
                recitations: recitations,
                now: now,
                overallProgressPercent: progressById[base.uid],
              ),
            ),
          )
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<Map<String, double>> _loadProgressByStudentId(
    List<String> studentIds,
  ) async {
    final out = <String, double>{};
    for (final chunk in FirestoreInQuery.chunkIds(studentIds)) {
      final snap = await firestore
          .collection(FirestoreCollections.studentProfiles)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final raw = doc.data()['overallProgressPercent'];
        final value = raw is num ? raw.toDouble() : 0.0;
        out[doc.id] = value;
      }
    }
    return out;
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
                sessionId: data['sessionId'] as String?,
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
      final preferredIds = <String>{};

      for (final record in records) {
        final normalizedDay = AttendancePolicy.dayStart(record.date);
        final sessionId = record.sessionId.trim();
        if (sessionId.isEmpty) {
          throw const ServerException(
            'sessionId مطلوب لكل سجل حضور جديد',
          );
        }
        final docId = AttendancePolicy.documentId(
          sessionId: sessionId,
          studentId: record.studentId,
        );
        final normalized = AttendanceRecordModel(
          id: docId,
          studentId: record.studentId,
          studentName: record.studentName,
          halaqaId: record.halaqaId,
          date: normalizedDay,
          status: record.status,
          recordedBy: record.recordedBy,
          sessionId: sessionId,
        );
        final ref = firestore
            .collection(FirestoreCollections.attendanceRecords)
            .doc(docId);
        batch.set(ref, normalized.toFirestore(), SetOptions(merge: true));
        savedStudentIds.add(record.studentId);
        preferredIds.add(docId);
      }

      // Remove legacy / colliding docs for the same students/session.
      for (final doc in existingSnap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String? ?? '';
        if (!savedStudentIds.contains(studentId)) continue;
        if (preferredIds.contains(doc.id)) continue;
        batch.delete(doc.reference);
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
            sessionId: record.sessionId,
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

      // One record per student — prefer session-scoped deterministic id.
      final byStudent = <String, AttendanceRecordModel>{};
      for (final doc in snapshot.docs) {
        final model = AttendanceRecordModel.fromFirestore(doc);
        final preferredId = AttendancePolicy.preferredDocumentId(
          halaqaId: halaqaId,
          studentId: model.studentId,
          date: dayStart,
          sessionId: model.sessionId,
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
  Future<void> upsertTeacherEvaluation({
    required RecitationRecordModel record,
    required List<String> retireDocumentIds,
  }) async {
    try {
      final id = record.id.trim();
      if (id.isEmpty) {
        throw const ServerException('معرّف التقييم مطلوب');
      }

      final batch = firestore.batch();
      final col = firestore.collection(FirestoreCollections.recitationRecords);
      batch.set(col.doc(id), record.toFirestore(), SetOptions(merge: true));

      for (final raw in retireDocumentIds) {
        final retireId = raw.trim();
        if (retireId.isEmpty || retireId == id) continue;
        batch.delete(col.doc(retireId));
      }

      await batch.commit();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AcademyEvent>> updateRecitationReview({
    required String recordId,
    required RecitationGrade grade,
    required RecitationGrade behaviorGrade,
    String? notes,
  }) async {
    try {
      final ref = firestore
          .collection(FirestoreCollections.recitationRecords)
          .doc(recordId);

      late final HomeworkReviewed event;

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
        if (studentId.trim().isEmpty) {
          throw const ServerException('سجل التسميع بدون طالب');
        }

        final rawDate = data['date'];
        final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();

        event = HomeworkReviewed(
          recitationRecordId: recordId,
          studentId: studentId,
          halaqaId: (data['halaqaId'] as String?) ?? '',
          date: date,
          grade: grade.label,
          behaviorGrade: behaviorGrade.label,
          versesRange: (data['versesRange'] as String?) ?? '',
        );
      });

      return [event];
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
      // Same [AssignmentPolicy] as W1 student "current homework" (latest dueDate),
      // scoped to the halaqa so the teacher agenda reuses D7, not a second rule.
      final snapshot = await firestore
          .collection(FirestoreCollections.assignments)
          .where(AssignmentPolicy.halaqaIdField, isEqualTo: halaqaId)
          .orderBy(AssignmentPolicy.dueDateField, descending: true)
          .limit(AssignmentPolicy.latestLimit)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final raw = snapshot.docs.first.data()[AssignmentPolicy.dueDateField];
      if (raw is Timestamp) return raw.toDate();
      return null;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AbsenceRequestModel>> getPendingAbsenceRequests({
    required String halaqaId,
    required DateTime date,
  }) async {
    try {
      final items = await AbsenceRequestFirestoreReads.forHalaqaOnDate(
        firestore: firestore,
        halaqaId: halaqaId,
        date: date,
        pendingOnly: true,
      );
      AbsenceRequestFirestoreReads.sortTeacherPending(items);
      return items;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> reviewAbsenceRequest({
    required String requestId,
    required String expectedHalaqaId,
    required String teacherId,
    required AbsenceRequestStatus decision,
  }) async {
    try {
      if (decision == AbsenceRequestStatus.pending) {
        throw const ServerException('قرار المراجعة غير صالح');
      }

      final ref = firestore
          .collection(FirestoreCollections.absenceRequests)
          .doc(requestId.trim());

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw const ServerException('طلب الاستئذان غير موجود');
        }
        final data = snap.data() ?? const <String, dynamic>{};
        final halaqaId = (data['halaqaId'] as String?)?.trim() ?? '';
        if (halaqaId != expectedHalaqaId.trim()) {
          throw const ServerException('طلب الاستئذان لا يخص هذه الحلقة');
        }
        final status = (data['status'] as String?)?.trim() ?? '';
        if (status != 'pending') {
          throw const ServerException('تم اتخاذ قرار لهذا الطلب مسبقاً');
        }

        // Status classification only — never writes attendanceRecords (Rule 1).
        tx.update(ref, {
          'status': decision == AbsenceRequestStatus.approved
              ? 'approved'
              : 'rejected',
          'reviewedBy': teacherId.trim(),
        });
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
