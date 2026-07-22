import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  });

  Future<Either<Failure, Unit>> logout();

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  Stream<UserEntity?> get authStateChanges;
}
