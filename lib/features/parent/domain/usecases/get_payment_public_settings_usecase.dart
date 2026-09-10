import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class GetPaymentPublicSettingsUseCase
    extends UseCase<PaymentPublicSettingsEntity, NoParams> {
  final ParentRepository repository;

  GetPaymentPublicSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, PaymentPublicSettingsEntity>> call(NoParams params) =>
      repository.getPaymentPublicSettings();
}
