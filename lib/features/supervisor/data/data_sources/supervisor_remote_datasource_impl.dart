import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/absence_request_firestore_reads.dart';
import '../../../../shared/data/absence_request_model.dart';
import '../../../../shared/data/payment_review_callable.dart';
import '../../../../shared/domain/payment_review_amounts.dart';
import '../../../../shared/utils/firestore_in_query.dart';
import '../../../awards/data/award_grant_errors.dart';
import '../../../awards/domain/award_submission_id.dart';
import '../../../../shared/data/models/payment_model.dart';
import '../../../../shared/data/models/halaqa_model.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/payment_review_params.dart';
import '../../domain/entities/supervisor_report_entity.dart';
import '../supervisor_payments_paging.dart';

@LazySingleton(as: SupervisorRemoteDatasource)
class SupervisorRemoteDatasourceImpl implements SupervisorRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const SupervisorRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

  @override
  Future<List<HalaqaModel>> getSupervisedHalaqat(String supervisorId) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.halaqat)
          .where('supervisorId', isEqualTo: supervisorId)
          .get();
      return snap.docs.map(HalaqaModel.fromFirestore).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> issueAchievement(AchievementIssueEntity data) async {
    if (!AwardSubmissionId.isValid(data.achievementId)) {
      throw const ServerException(kAwardGrantFailedMessage);
    }
    var requestSent = false;
    try {
      // The server writes the record; replaying the same id is a no-op.
      final callable = functions.httpsCallable('issueAchievement');
      requestSent = true;
      await callable.call(<String, dynamic>{
        'achievementId': data.achievementId,
        'studentId': data.studentId,
        'halaqaId': data.halaqaId,
        'type': data.type,
        'title': data.title,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(awardGrantErrorMessage(e.code, e.message));
    } catch (_) {
      throw ServerException(
        awardGrantUnexpectedErrorMessage(requestSent: requestSent),
      );
    }
  }

  @override
  // H6 / A-H16: write-only ops path — product UI removed; no in-app reader.
  Future<void> submitReport(SupervisorReportEntity report) async {
    try {
      await firestore.collection(FirestoreCollections.supervisorReports).add({
        'supervisorId': report.supervisorId,
        if (report.halaqaId != null) 'halaqaId': report.halaqaId,
        if (report.teacherId != null) 'teacherId': report.teacherId,
        'type': report.type,
        'content': report.content,
        'date': Timestamp.fromDate(report.date),
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }


  /// Academy Admission via the admitStudentToHalaqa callable: supervised-halaqa
  /// scope, student role, duplicate and max-2 cap are enforced transactionally.
  @override
  Future<void> admitStudentToHalaqa({
    required String supervisorId,
    required String halaqaId,
    required String studentId,
  }) {
    return _callAdmission(halaqaId: halaqaId, studentId: studentId);
  }

  @override
  Future<void> registerNewStudent({
    required String halaqaId,
    required String studentId,
  }) {
    return _callAdmission(halaqaId: halaqaId, studentId: studentId);
  }

  Future<void> _callAdmission({
    required String halaqaId,
    required String studentId,
  }) async {
    try {
      final callable = functions.httpsCallable('admitStudentToHalaqa');
      await callable.call(<String, dynamic>{
        'halaqaId': halaqaId.trim(),
        'studentId': studentId.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// adminTransferStudent requires the caller to supervise both halaqat.
  @override
  Future<void> transferStudentBetweenHalaqat({
    required String supervisorId,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  }) async {
    try {
      final callable = functions.httpsCallable('adminTransferStudent');
      await callable.call(<String, dynamic>{
        'studentId': studentId.trim(),
        'fromHalaqaId': sourceHalaqaId.trim(),
        'toHalaqaId': targetHalaqaId.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _studentProfileOrNull(
    String id,
  ) async {
    try {
      return await firestore
          .collection(FirestoreCollections.studentProfiles)
          .doc(id)
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> getUserDisplayNames(List<String> userIds) async {
    try {
      final unique = userIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (unique.isEmpty) return const {};

      final names = <String, String>{};
      for (final chunk in FirestoreInQuery.chunkIds(unique)) {
        // studentProfiles first, then users. teacherProfiles holds HR data
        // readable by Admin and the teacher only. Profiles are read one by
        // one: the rules authorize staff per student, and an id that is not
        // a student the caller serves falls through to users.
        final studentDocs = await Future.wait([
          for (final id in chunk) _studentProfileOrNull(id),
        ]);
        for (final doc in studentDocs) {
          final name = (doc?.data()?['name'] as String?)?.trim() ?? '';
          if (name.isNotEmpty) names[doc!.id] = name;
        }

        final missing = chunk.where((id) => !names.containsKey(id)).toList();
        if (missing.isEmpty) continue;

        final usersSnap = await firestore
            .collection(FirestoreCollections.users)
            .where(FieldPath.documentId, whereIn: missing)
            .get();
        for (final doc in usersSnap.docs) {
          final raw = doc.data()['name'];
          final name = raw is String ? raw.trim() : '';
          if (name.isNotEmpty) names[doc.id] = name;
        }
      }
      return names;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<AbsenceRequestModel>> getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  }) async {
    try {
      // Today and upcoming requests (read-only awareness; teacher decides).
      final pages = await Future.wait(
        halaqaIds.map(
          (rawId) => AbsenceRequestFirestoreReads.forHalaqaFrom(
            firestore: firestore,
            halaqaId: rawId,
            from: date,
          ),
        ),
      );
      final items = [for (final page in pages) ...page];
      AbsenceRequestFirestoreReads.sortUpcoming(items);
      return items;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<PaymentModel>> getPaymentsForStudents({
    required String supervisorId,
    required List<String> studentIds,
  }) async {
    try {
      final sid = supervisorId.trim();
      if (sid.isEmpty) {
        throw const ServerException('معرّف المشرف غير صالح');
      }

      // Scope from supervised halaqat — do not trust client studentIds alone.
      final supervised = await getSupervisedHalaqat(sid);
      final allowed = <String>{for (final h in supervised) ...h.studentIds};
      final requested = FirestoreInQuery.normalizeIds(studentIds).toSet();
      final ids = requested.isEmpty ? allowed : requested.intersection(allowed);
      if (ids.isEmpty) return const [];

      // Rules only allow reads by the supervisor of the student's primary
      // halaqa, so query per student (cannot use a single academy-wide query).
      // D2: page by document id (always present) — NOT by dueDate — so invoices
      // missing `dueDate` still appear, matching pre-D2 unordered `.get()`
      // completeness. Peak reads stay bounded; display sort is applied after.
      const pageSize = SupervisorPaymentsPaging.pageSize;
      const concurrency = SupervisorPaymentsPaging.concurrency;
      final idList = ids.toList();
      final byId = <String, PaymentModel>{};

      Future<void> fetchOne(String studentId) async {
        try {
          Query<Map<String, dynamic>> base = firestore
              .collection(FirestoreCollections.payments)
              .where('studentId', isEqualTo: studentId)
              .orderBy(FieldPath.documentId)
              .limit(pageSize);
          QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
          while (true) {
            final q = cursor == null ? base : base.startAfterDocument(cursor);
            final snap = await q.get();
            if (snap.docs.isEmpty) break;
            for (final doc in snap.docs) {
              byId[doc.id] = PaymentModel.fromFirestore(doc);
            }
            if (snap.docs.length < pageSize) break;
            cursor = snap.docs.last;
          }
        } on FirebaseException catch (e) {
          if (!SupervisorPaymentsPaging.swallowPermissionDenied(e.code)) {
            rethrow;
          }
        }
      }

      for (final chunk
          in SupervisorPaymentsPaging.concurrencyChunks(idList, concurrency: concurrency)) {
        await Future.wait(chunk.map(fetchOne));
      }

      final list = byId.values.toList()
        ..sort(SupervisorPaymentsPaging.compareDisplayOrder);
      return list;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// The reviewPaymentProof callable derives status, paidAt and the
  /// cumulative amounts and enforces supervised-halaqa scope server-side.
  @override
  Future<PaymentReviewResult> reviewPaymentProof(
    PaymentReviewParams params,
  ) async {
    if (params.paymentId.isEmpty) {
      throw const ServerException('بيانات المراجعة غير صالحة');
    }
    try {
      final callable = functions.httpsCallable('reviewPaymentProof');
      final response = await callable.call(
        reviewPaymentProofPayload(params.command, requestId: params.requestId),
      );
      return reviewPaymentProofResult(response.data, params.command);
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
