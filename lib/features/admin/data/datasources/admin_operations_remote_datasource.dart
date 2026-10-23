import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/domain/payment_review_amounts.dart';
import '../../../parent/domain/parent_payment_proof.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/admin_operations_entities.dart';

abstract class AdminOperationsRemoteDatasource {
  Future<List<AdminDirectoryUser>> listUsersByRole(String role);

  Future<List<HalaqaEntity>> listHalaqat();

  Future<List<String>> getParentChildrenIds(String parentId);

  Future<ParentLinkResult> linkParentChild({
    required String parentId,
    required String studentId,
    required ParentLinkOperation operation,
  });

  Future<String> createHalaqa({
    required String name,
    required String teacherId,
    String? supervisorId,
    String? meetingLink,
    required List<HalaqaSlotInput> schedule,
    required String requestId,
  });

  Future<String> addHalaqaSlot({
    required String halaqaId,
    required HalaqaSlotInput slot,
  });

  /// `setHalaqaMeetingLink`: [meetingLink] to set, or [clear] to remove.
  Future<MeetingLinkChange> setHalaqaMeetingLink({
    required String halaqaId,
    String? meetingLink,
    bool clear = false,
  });

  Future<void> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  });

  Future<List<PaymentReviewItem>> listPendingPaymentProofs({
    required String reviewerUid,
    required bool isAdmin,
  });

  Future<PaymentReviewResult> reviewPaymentProof({
    required PaymentReviewCommand command,
    required String requestId,
  });
}

/// Pure mapping of a `payments/{id}` document to the review row.
PaymentReviewItem paymentReviewItemFromMap(
  String id,
  Map<String, dynamic> data,
) {
  DateTime? asDate(Object? raw) =>
      raw is Timestamp ? raw.toDate() : (raw is DateTime ? raw : null);
  String text(Object? raw) => raw is String ? raw.trim() : '';
  final path = text(data[ParentPaymentProofContract.proofStoragePathField]);
  final fileName = text(data[ParentPaymentProofContract.proofFileNameField]);
  final cycle = text(data[ParentPaymentProofContract.proofCycleIdField]);
  return PaymentReviewItem(
    paymentId: id,
    parentId: text(data['parentId']),
    studentId: text(data['studentId']),
    amount: (data['amount'] as num?)?.toDouble() ?? 0,
    currency: text(data['currency']),
    periodKey: text(data['periodKey']),
    dueDate: asDate(data['dueDate']),
    status: text(data['status']),
    reviewStatus: text(data[ParentPaymentProofContract.reviewStatusField]),
    proofStoragePath: path.isEmpty ? null : path,
    proofFileName: fileName.isEmpty ? null : fileName,
    proofSubmittedAt: asDate(
      data[ParentPaymentProofContract.proofSubmittedAtField],
    ),
    proofCycleId: ParentPaymentProofContract.isProofCycleId(cycle)
        ? cycle
        : null,
    amountPaidConfirmed:
        (data[ParentPaymentProofContract.amountPaidConfirmedField] as num?)
            ?.toDouble(),
  );
}
