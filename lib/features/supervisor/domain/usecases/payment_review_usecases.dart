import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/payment_review_amounts.dart';
import '../../../../shared/domain/payment_entity.dart';
import '../entities/payment_review_params.dart';
import '../repositories/parent_repository.dart';

class SupervisedPaymentsParams extends Equatable {
  final String supervisorId;
  final List<String> studentIds;

  const SupervisedPaymentsParams({
    required this.supervisorId,
    required this.studentIds,
  });

  @override
  List<Object?> get props => [supervisorId, studentIds];
}

@lazySingleton
class GetSupervisedPaymentsUseCase
    extends UseCase<List<PaymentEntity>, SupervisedPaymentsParams> {
  final SupervisorRepository repository;

  GetSupervisedPaymentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<PaymentEntity>>> call(
    SupervisedPaymentsParams params,
  ) {
    return repository.getPaymentsForStudents(
      supervisorId: params.supervisorId,
      studentIds: params.studentIds,
    );
  }
}

@lazySingleton
class ReviewPaymentProofUseCase
    extends UseCase<PaymentReviewResult, PaymentReviewParams> {
  final SupervisorRepository repository;

  ReviewPaymentProofUseCase(this.repository);

  @override
  Future<Either<Failure, PaymentReviewResult>> call(
    PaymentReviewParams params,
  ) {
    final error = !kPaymentReviewRequestIdPattern.hasMatch(params.requestId)
        ? 'بيانات المراجعة غير صالحة'
        : validatePaymentReviewCommand(params.command, params.snapshot);
    if (error != null) return Future.value(Left(ValidationFailure(error)));
    return repository.reviewPaymentProof(params);
  }
}
