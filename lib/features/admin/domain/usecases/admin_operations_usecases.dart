import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../entities/admin_operations_entities.dart';
import '../repositories/admin_operations_repository.dart';

@lazySingleton
class ListUsersByRoleUseCase extends UseCase<List<AdminDirectoryUser>, String> {
  final AdminOperationsRepository repository;
  ListUsersByRoleUseCase(this.repository);

  @override
  Future<Either<Failure, List<AdminDirectoryUser>>> call(String role) =>
      repository.listUsersByRole(role);
}

@lazySingleton
class ListAdminHalaqatUseCase extends UseCase<List<HalaqaEntity>, NoParams> {
  final AdminOperationsRepository repository;
  ListAdminHalaqatUseCase(this.repository);

  @override
  Future<Either<Failure, List<HalaqaEntity>>> call(NoParams params) =>
      repository.listHalaqat();
}

@lazySingleton
class GetParentChildrenUseCase extends UseCase<List<String>, String> {
  final AdminOperationsRepository repository;
  GetParentChildrenUseCase(this.repository);

  @override
  Future<Either<Failure, List<String>>> call(String parentId) =>
      repository.getParentChildrenIds(parentId);
}

class LinkParentChildParams extends Equatable {
  final String parentId;
  final String studentId;
  final ParentLinkOperation operation;

  const LinkParentChildParams({
    required this.parentId,
    required this.studentId,
    this.operation = ParentLinkOperation.link,
  });

  @override
  List<Object?> get props => [parentId, studentId, operation];
}

@lazySingleton
class LinkParentChildUseCase
    extends UseCase<ParentLinkResult, LinkParentChildParams> {
  final AdminOperationsRepository repository;
  LinkParentChildUseCase(this.repository);

  @override
  Future<Either<Failure, ParentLinkResult>> call(LinkParentChildParams params) {
    if (params.parentId.trim().isEmpty || params.studentId.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('اختر ولي الأمر والطالب')),
      );
    }
    return repository.linkParentChild(
      parentId: params.parentId.trim(),
      studentId: params.studentId.trim(),
      operation: params.operation,
    );
  }
}

class CreateHalaqaParams extends Equatable {
  final String name;
  final String teacherId;
  final String? supervisorId;
  final String? meetingLink;
  final List<HalaqaSlotInput> schedule;

  /// Client-generated idempotency key (doc id) so a retried submit never
  /// creates a second Halaqa.
  final String requestId;

  const CreateHalaqaParams({
    required this.name,
    required this.teacherId,
    required this.schedule,
    required this.requestId,
    this.supervisorId,
    this.meetingLink,
  });

  @override
  List<Object?> get props => [
    name,
    teacherId,
    supervisorId,
    meetingLink,
    schedule,
    requestId,
  ];
}

@lazySingleton
class CreateHalaqaUseCase extends UseCase<String, CreateHalaqaParams> {
  final AdminOperationsRepository repository;
  CreateHalaqaUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(CreateHalaqaParams params) {
    if (params.name.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('أدخل اسم الحلقة')));
    }
    if (params.teacherId.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('اختر معلم الحلقة')));
    }
    // D8: a Halaqa is created with at least one weekly slot.
    if (params.schedule.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('أضف موعداً أسبوعياً واحداً على الأقل')),
      );
    }
    for (final slot in params.schedule) {
      final error = validateSlotInput(slot);
      if (error != null) return Future.value(Left(ValidationFailure(error)));
    }
    return repository.createHalaqa(
      name: params.name.trim(),
      teacherId: params.teacherId.trim(),
      supervisorId: params.supervisorId?.trim(),
      meetingLink: params.meetingLink?.trim(),
      schedule: params.schedule,
      requestId: params.requestId,
    );
  }
}

class AddHalaqaSlotParams extends Equatable {
  final String halaqaId;
  final HalaqaSlotInput slot;

  const AddHalaqaSlotParams({required this.halaqaId, required this.slot});

  @override
  List<Object?> get props => [halaqaId, slot];
}

@lazySingleton
class AddHalaqaSlotUseCase extends UseCase<String, AddHalaqaSlotParams> {
  final AdminOperationsRepository repository;
  AddHalaqaSlotUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(AddHalaqaSlotParams params) {
    final error = validateSlotInput(params.slot);
    if (error != null) return Future.value(Left(ValidationFailure(error)));
    return repository.addHalaqaSlot(
      halaqaId: params.halaqaId,
      slot: params.slot,
    );
  }
}

class TransferStudentParams extends Equatable {
  final String studentId;
  final String fromHalaqaId;
  final String toHalaqaId;

  const TransferStudentParams({
    required this.studentId,
    required this.fromHalaqaId,
    required this.toHalaqaId,
  });

  @override
  List<Object?> get props => [studentId, fromHalaqaId, toHalaqaId];
}

@lazySingleton
class TransferStudentUseCase extends UseCase<Unit, TransferStudentParams> {
  final AdminOperationsRepository repository;
  TransferStudentUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(TransferStudentParams params) {
    if (params.fromHalaqaId == params.toHalaqaId) {
      return Future.value(
        const Left(ValidationFailure('الحلقة المصدر والهدف يجب أن تختلفا')),
      );
    }
    return repository.transferStudent(
      studentId: params.studentId,
      fromHalaqaId: params.fromHalaqaId,
      toHalaqaId: params.toHalaqaId,
    );
  }
}

class PendingPaymentProofsParams extends Equatable {
  final String reviewerUid;
  final bool isAdmin;

  const PendingPaymentProofsParams({
    required this.reviewerUid,
    required this.isAdmin,
  });

  @override
  List<Object?> get props => [reviewerUid, isAdmin];
}

@lazySingleton
class ListPendingPaymentProofsUseCase
    extends UseCase<List<PaymentReviewItem>, PendingPaymentProofsParams> {
  final AdminOperationsRepository repository;
  ListPendingPaymentProofsUseCase(this.repository);

  @override
  Future<Either<Failure, List<PaymentReviewItem>>> call(
    PendingPaymentProofsParams params,
  ) => repository.listPendingPaymentProofs(
    reviewerUid: params.reviewerUid,
    isAdmin: params.isAdmin,
  );
}

class ReviewPaymentProofParams extends Equatable {
  final String paymentId;
  final PaymentReviewDecision decision;
  final double invoiceAmount;
  final String? notes;
  final double? amountPaidConfirmed;

  const ReviewPaymentProofParams({
    required this.paymentId,
    required this.decision,
    required this.invoiceAmount,
    this.notes,
    this.amountPaidConfirmed,
  });

  @override
  List<Object?> get props => [
    paymentId,
    decision,
    invoiceAmount,
    notes,
    amountPaidConfirmed,
  ];
}

@lazySingleton
class ReviewPaymentProofUseCase
    extends UseCase<Unit, ReviewPaymentProofParams> {
  final AdminOperationsRepository repository;
  ReviewPaymentProofUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ReviewPaymentProofParams params) {
    if (params.decision == PaymentReviewDecision.partial) {
      final error = validatePartialAmount(
        invoiceAmount: params.invoiceAmount,
        confirmed: params.amountPaidConfirmed,
      );
      if (error != null) return Future.value(Left(ValidationFailure(error)));
    }
    return repository.reviewPaymentProof(
      paymentId: params.paymentId,
      decision: params.decision,
      notes: params.notes,
      amountPaidConfirmed: params.decision == PaymentReviewDecision.partial
          ? params.amountPaidConfirmed
          : null,
    );
  }
}
