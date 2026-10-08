import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/auth_repository.dart';

/// Firebase email-link reset: the user sets the new password through the
/// Firebase action page, then signs in again.
@lazySingleton
class SendPasswordResetUseCase extends UseCase<Unit, String> {
  final AuthRepository repository;

  SendPasswordResetUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String email) {
    return repository.sendPasswordResetEmail(email: email.trim());
  }
}
