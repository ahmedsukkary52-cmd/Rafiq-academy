import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/admin_repository.dart';

class ToggleAccountStatusUseCase extends UseCase<Unit, ToggleAccountParams> {
  final AdminRepository repository;

  ToggleAccountStatusUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ToggleAccountParams params) => repository
      .toggleAccountStatus(uid: params.uid, isActive: params.isActive);
}
