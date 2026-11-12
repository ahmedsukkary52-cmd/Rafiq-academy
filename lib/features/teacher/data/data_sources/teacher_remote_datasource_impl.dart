import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/absence_request_firestore_reads.dart';
import '../../../../shared/data/absence_request_model.dart';
import '../../../../shared/domain/absence_request.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/assignment_kind.dart';
import '../../../../shared/domain/assignment_policy.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/utils/firestore_in_query.dart';
import '../../../../shared/data/models/assignment_model.dart';
import '../../../../shared/data/models/halaqa_model.dart';
import '../../../../shared/data/models/recitation_record_model.dart';
import '../../../../shared/domain/recitation_record_entity.dart';
import '../../domain/services/halaqa_student_summary_projector.dart';
import '../models/attendance_record_model.dart';
import '../models/halaqa_student_summary_model.dart';

@LazySingleton(as: TeacherRemoteDatasource)
class TeacherRemoteDatasourceImpl implements TeacherRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const TeacherRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

  /// Cairo calendar day wire format expected by the session callables.
  static String _ymd(DateTime date) {
    final d = AttendancePolicy.dayStart(date);
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$m-$day';
  }

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

      // studentProfiles (not users) so D16 phone-bearing legacy users docs do
      // not break roster queries (WA-2). One get per student: the rules
      // authorize staff per student, which a list query cannot prove.
      final docs = (await _studentProfiles(studentIds))
          .where((doc) => doc.exists)
          .toList();

      final bases = docs
          .map(HalaqaStudentSummaryModel.fromStudentProfile)
          .toList();

      final now = DateTime.now();
      final from = now.subtract(
        const Duration(
          days: HalaqaStudentSummaryProjector.attendanceWindowDays,
        ),
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

      final attendanceSnap = parallel[0] as QuerySnapshot<Map<String, dynamic>>;
      final recitationSnap = parallel[1] as QuerySnapshot<Map<String, dynamic>>;
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
    for (final doc in await _studentProfiles(studentIds)) {
      if (!doc.exists) continue;
      final raw = doc.data()?['overallProgressPercent'];
      final value = raw is num ? raw.toDouble() : 0.0;
      out[doc.id] = value;
    }
    return out;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _studentProfiles(
    List<String> studentIds,
  ) {
    final profiles = firestore.collection(FirestoreCollections.studentProfiles);
    return Future.wait([
      for (final id in FirestoreInQuery.normalizeIds(studentIds))
        profiles.doc(id).get(),
    ]);
  }

  @override
  Future<void> recordAttendance(AttendanceRecordModel record) async {
    await saveDayAttendance([record]);
  }

  /// C6 / PH-02 — the recordSessionAttendance callable binds the day to a real
  /// `sessions/{id}`, validates roster + teacher + edit window, retires legacy
  /// duplicates and fans out absence cards to linked parents. The client
  /// sends intent only (halaqa, Cairo day, marks); no events are published
  /// from the device.
  @override
  Future<List<AcademyEvent>> saveDayAttendance(
    List<AttendanceRecordModel> records,
  ) async {
    try {
      if (records.isEmpty) return const [];

      final callable = functions.httpsCallable('recordSessionAttendance');
      await callable.call(<String, dynamic>{
        'halaqaId': records.first.halaqaId.trim(),
        'date': _ymd(records.first.date),
        'marks': [
          for (final record in records)
            {'studentId': record.studentId.trim(), 'status': record.wireStatus},
        ],
      });
      return const [];
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
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

  /// C6 + D7 / PH-02 — the upsertSessionEvaluation callable resolves the real
  /// session from the student's attendance and re-checks Present/Late in the
  /// same transaction. Legacy synthetic day ids are never sent as a session;
  /// duplicate retirement is decided server-side ([retireDocumentIds] is
  /// ignored).
  @override
  Future<void> upsertTeacherEvaluation({
    required RecitationRecordModel record,
    required List<String> retireDocumentIds,
  }) async {
    try {
      final grade = record.grade;
      final behaviorGrade = record.behaviorGrade;
      if (grade == null || behaviorGrade == null) {
        throw const ServerException('التقييم مطلوب');
      }
      final sessionId = record.sessionId?.trim() ?? '';
      final notes = record.notes?.trim() ?? '';

      final callable = functions.httpsCallable('upsertSessionEvaluation');
      await callable.call(<String, dynamic>{
        'halaqaId': record.halaqaId.trim(),
        'studentId': record.studentId.trim(),
        'type': record.type.name,
        'grade': grade.name,
        'behaviorGrade': behaviorGrade.name,
        'date': _ymd(record.date),
        if (sessionId.isNotEmpty &&
            !AttendancePolicy.isLegacySyntheticSessionId(sessionId))
          'sessionId': sessionId,
        if (notes.isNotEmpty) 'notes': notes,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
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
          AssignmentPolicy.kindField: AssignmentKind.wireLessonHomework,
          AssignmentPolicy.createdAtField: Timestamp.fromDate(DateTime.now()),
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
          .limit(AssignmentPolicy.latestScanLimit)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!AssignmentPolicy.isLessonHomeworkData(data)) continue;
        final raw = data[AssignmentPolicy.dueDateField];
        if (raw is Timestamp) return raw.toDate();
      }
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
      final items = await AbsenceRequestFirestoreReads.forHalaqaFrom(
        firestore: firestore,
        halaqaId: halaqaId,
        from: date,
        pendingOnly: true,
      );
      AbsenceRequestFirestoreReads.sortUpcoming(items);
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
          'reviewedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
