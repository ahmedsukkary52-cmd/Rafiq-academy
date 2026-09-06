import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/data/absence_request_firestore_reads.dart';
import '../../../../shared/data/absence_request_model.dart';
import '../../../../shared/data/academy_admission_firestore.dart';
import '../../../../shared/data/achievements_firestore_contract.dart';
import '../../../../shared/utils/firestore_in_query.dart';
import '../../../parent/data/models/parent_model.dart';
import '../../../parent/domain/parent_payment_proof.dart';
import '../../../student/data/models/halaqa_model.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../../domain/entities/payment_review_params.dart';
import '../../domain/entities/supervisor_report_entity.dart';

@LazySingleton(as: SupervisorRemoteDatasource)
class SupervisorRemoteDatasourceImpl implements SupervisorRemoteDatasource {
  final FirebaseFirestore firestore;

  const SupervisorRemoteDatasourceImpl({required this.firestore});

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
    try {
      await firestore
          .collection(FirestoreCollections.achievements)
          .add(
            AchievementsFirestoreContract.supervisorIssueFields(
              studentId: data.studentId,
              type: data.type,
              title: data.title,
              issuedBy: data.issuedBy,
              halaqaId: data.halaqaId,
            ),
          );
    } catch (e) {
      throw ServerException(e.toString());
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

  @override
  Future<void> admitStudentToHalaqa({
    required String supervisorId,
    required String halaqaId,
    required String studentId,
  }) async {
    try {
      await _assertSupervisedHalaqa(
        supervisorId: supervisorId,
        halaqaId: halaqaId,
      );
      await AcademyAdmissionFirestore.establishMembership(
        firestore: firestore,
        studentId: studentId,
        halaqaId: halaqaId,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  @override
  Future<void> registerNewStudent({
    required String halaqaId,
    required String studentId,
  }) async {
    try {
      await AcademyAdmissionFirestore.establishMembership(
        firestore: firestore,
        studentId: studentId,
        halaqaId: halaqaId,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> transferStudentBetweenHalaqat({
    required String supervisorId,
    required String studentId,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  }) async {
    try {
      await _assertSupervisedHalaqa(
        supervisorId: supervisorId,
        halaqaId: sourceHalaqaId,
      );
      await _assertSupervisedHalaqa(
        supervisorId: supervisorId,
        halaqaId: targetHalaqaId,
      );
      await AcademyAdmissionFirestore.transferMembership(
        firestore: firestore,
        studentId: studentId,
        sourceHalaqaId: sourceHalaqaId,
        targetHalaqaId: targetHalaqaId,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> _assertSupervisedHalaqa({
    required String supervisorId,
    required String halaqaId,
  }) async {
    final sid = supervisorId.trim();
    final hid = halaqaId.trim();
    if (sid.isEmpty || hid.isEmpty) {
      throw const ServerException('معرّف المشرف أو الحلقة غير صالح');
    }
    final snap = await firestore
        .collection(FirestoreCollections.halaqat)
        .doc(hid)
        .get();
    if (!snap.exists) {
      throw const ServerException('الحلقة غير موجودة');
    }
    final owner = (snap.data()?['supervisorId'] as String?)?.trim() ?? '';
    if (owner != sid) {
      throw const ServerException('الحلقة ليست ضمن نطاق إشرافك');
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
        final snap = await firestore
            .collection(FirestoreCollections.users)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
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
      final items = <AbsenceRequestModel>[];
      for (final rawId in halaqaIds) {
        items.addAll(
          await AbsenceRequestFirestoreReads.forHalaqaOnDate(
            firestore: firestore,
            halaqaId: rawId,
            date: date,
            pendingOnly: false,
          ),
        );
      }
      AbsenceRequestFirestoreReads.sortSupervisorDay(items);
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
      final ids =
          (requested.isEmpty ? allowed : requested.intersection(allowed))
              .toList();
      if (ids.isEmpty) return const [];

      final byId = <String, PaymentModel>{};
      for (final chunk in FirestoreInQuery.chunkIds(ids)) {
        final snap = await firestore
            .collection(FirestoreCollections.payments)
            .where('studentId', whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          byId[doc.id] = PaymentModel.fromFirestore(doc);
        }
      }

      final list = byId.values.toList()
        ..sort((a, b) {
          final aPending = a.hasProofAwaitingReview ? 0 : 1;
          final bPending = b.hasProofAwaitingReview ? 0 : 1;
          if (aPending != bPending) return aPending.compareTo(bPending);
          return b.dueDate.compareTo(a.dueDate);
        });
      return list;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> reviewPaymentProof(PaymentReviewParams params) async {
    try {
      final sid = params.supervisorId.trim();
      final payId = params.paymentId.trim();
      if (sid.isEmpty || payId.isEmpty) {
        throw const ServerException('بيانات المراجعة غير صالحة');
      }

      final paymentRef = firestore
          .collection(FirestoreCollections.payments)
          .doc(payId);
      final snap = await paymentRef.get();
      if (!snap.exists) {
        throw const ServerException('الدفعة غير موجودة');
      }
      final data = snap.data() ?? const <String, dynamic>{};
      final studentId = (data['studentId'] as String?)?.trim() ?? '';
      if (studentId.isEmpty) {
        throw const ServerException('الدفعة غير مرتبطة بطالب');
      }

      await _assertStudentInSupervisedHalaqa(
        supervisorId: sid,
        studentId: studentId,
      );

      final proofPath =
          (data[ParentPaymentProofContract.proofStoragePathField] as String?)
              ?.trim() ??
          '';
      if (proofPath.isEmpty && data['proofSubmittedAt'] == null) {
        throw const ServerException('لا يوجد إثبات دفع للمراجعة');
      }

      final decisionStatus = switch (params.decision) {
        PaymentReviewDecision.approved => ParentPaymentProofContract.approved,
        PaymentReviewDecision.rejected => ParentPaymentProofContract.rejected,
        PaymentReviewDecision.partial => ParentPaymentProofContract.partial,
      };

      final notes = params.notes?.trim();
      final update = <String, dynamic>{
        ParentPaymentProofContract.reviewStatusField: decisionStatus,
        ParentPaymentProofContract.reviewedByField: sid,
        ParentPaymentProofContract.reviewedAtField:
            FieldValue.serverTimestamp(),
        if (notes != null && notes.isNotEmpty)
          ParentPaymentProofContract.reviewNotesField: notes,
        if (params.amountPaidConfirmed != null)
          ParentPaymentProofContract.amountPaidConfirmedField:
              params.amountPaidConfirmed,
        if (params.remainingAmount != null)
          ParentPaymentProofContract.remainingAmountField:
              params.remainingAmount,
      };

      if (params.decision == PaymentReviewDecision.approved) {
        update['status'] = 'paid';
        update['paidAt'] = FieldValue.serverTimestamp();
        update[ParentPaymentProofContract.remainingAmountField] = 0;
        if (params.amountPaidConfirmed == null) {
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          update[ParentPaymentProofContract.amountPaidConfirmedField] = amount;
        }
      }

      await paymentRef.update(update);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> _assertStudentInSupervisedHalaqa({
    required String supervisorId,
    required String studentId,
  }) async {
    final halaqat = await getSupervisedHalaqat(supervisorId);
    final allowed = halaqat.any((h) => h.studentIds.contains(studentId));
    if (!allowed) {
      throw const ServerException('الطالب ليس ضمن حلقاتك');
    }
  }
}
