import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../parent/domain/entities/parent_entities.dart';
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
class ReviewPaymentProofUseCase extends UseCase<Unit, PaymentReviewParams> {
  final SupervisorRepository repository;

  ReviewPaymentProofUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(PaymentReviewParams params) {
    return repository.reviewPaymentProof(params);
  }
}
