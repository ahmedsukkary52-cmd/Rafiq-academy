import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/parent_entities.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class InitiatePaymentUseCase
    extends UseCase<PaymentInitiationEntity, PaymentIdParams> {
  final ParentRepository repository;

  InitiatePaymentUseCase(this.repository);

  @override
  Future<Either<Failure, PaymentInitiationEntity>> call(
    PaymentIdParams params,
  ) => repository.initiatePayment(params.paymentId);
}
