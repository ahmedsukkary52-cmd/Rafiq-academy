import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class ProvisionUserUseCase extends UseCase<String, ProvisionUserParams> {
  final AdminRepository repository;

  ProvisionUserUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(ProvisionUserParams params) =>
      repository.provisionUser(
        email: params.email,
        password: params.password,
        name: params.name,
        role: params.role,
        isActive: params.isActive,
      );
}
