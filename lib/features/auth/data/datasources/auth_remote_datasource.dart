import '../models/user_model.dart';

abstract class AuthRemoteDatasource {
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<UserModel?> getCurrentUser();

  Stream<UserModel?> get authStateChanges;
}