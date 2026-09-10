import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/payment_access_entity.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class GetPaymentAccessUseCase
    extends UseCase<PaymentAccessEntity?, ParentIdParams> {
  final ParentRepository repository;

  GetPaymentAccessUseCase(this.repository);

  @override
  Future<Either<Failure, PaymentAccessEntity?>> call(ParentIdParams params) =>
      repository.getPaymentAccess(params.parentId);
}
