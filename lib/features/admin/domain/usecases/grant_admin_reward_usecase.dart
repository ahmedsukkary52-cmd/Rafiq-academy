import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../admin_grant_reward_params.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GrantAdminRewardUseCase extends UseCase<Unit, AdminGrantRewardParams> {
  final AdminRepository repository;

  GrantAdminRewardUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AdminGrantRewardParams params) =>
      repository.grantReward(params);
}
