import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../entities/admin_operations_entities.dart';

/// P0-01 … P0-04 operational contracts. Every mutation is an existing
/// authoritative callable; reads are rules-scoped Firestore queries.
/// Provisioning, admission and access reinstatement stay on [AdminRepository].
abstract class AdminOperationsRepository {
  Future<Either<Failure, List<AdminDirectoryUser>>> listUsersByRole(
    String role,
  );

  Future<Either<Failure, List<HalaqaEntity>>> listHalaqat();

  /// Children currently linked to [parentId] (parentProfiles.childrenIds).
  Future<Either<Failure, List<String>>> getParentChildrenIds(String parentId);

  Future<Either<Failure, ParentLinkResult>> linkParentChild({
    required String parentId,
    required String studentId,
    required ParentLinkOperation operation,
  });

  Future<Either<Failure, String>> createHalaqa({
    required String name,
    required String teacherId,
    String? supervisorId,
    String? meetingLink,
    required List<HalaqaSlotInput> schedule,
    required String requestId,
  });

  Future<Either<Failure, String>> addHalaqaSlot({
    required String halaqaId,
    required HalaqaSlotInput slot,
  });

  Future<Either<Failure, Unit>> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  });

  /// Admin: every pending proof. Supervisor: proofs of supervised students.
  Future<Either<Failure, List<PaymentReviewItem>>> listPendingPaymentProofs({
    required String reviewerUid,
    required bool isAdmin,
  });

  Future<Either<Failure, Unit>> reviewPaymentProof({
    required String paymentId,
    required PaymentReviewDecision decision,
    String? notes,
    double? amountPaidConfirmed,
  });
}
