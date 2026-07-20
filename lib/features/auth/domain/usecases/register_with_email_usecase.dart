import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

@injectable
class RegisterWithEmailUseCase implements UseCase<UserEntity, RegisterParams> {
  final AuthRepository repository;

  const RegisterWithEmailUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(RegisterParams params) async {
    return await repository.registerWithEmail(
      email: params.email,
      password: params.password,
      name: params.name,
      phone: params.phone,
      role: params.role,
    );
  }
}

class RegisterParams {
  final String email;
  final String password;
  final String name;
  final String phone;
  final String role;

  const RegisterParams({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.role,
  });
}
