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
}
