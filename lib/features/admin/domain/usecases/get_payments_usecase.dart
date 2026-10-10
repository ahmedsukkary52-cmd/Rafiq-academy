import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/admin_payment_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetPaymentsUseCase extends UseCase<List<AdminPaymentEntity>, NoParams> {
  final AdminRepository repository;

  GetPaymentsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AdminPaymentEntity>>> call(NoParams params) =>
      repository.getPayments();
}
