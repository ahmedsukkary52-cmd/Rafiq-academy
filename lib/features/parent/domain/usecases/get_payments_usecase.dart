import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/parent_entities.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class GetPaymentsUseCase extends UseCase<List<PaymentEntity>, ParentIdParams> {
  final ParentRepository repository;

  GetPaymentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<PaymentEntity>>> call(ParentIdParams params) =>
      repository.getPayments(params.parentId);

  /// Cursor page used by Parent subscriptions (D2 deferred pagination).
  Future<Either<Failure, ParentPaymentsPage>> page(
    ParentPaymentsPageParams params,
  ) =>
      repository.getPaymentsPage(
        parentId: params.parentId,
        limit: params.limit,
        afterPaymentId: params.afterPaymentId,
      );
}
