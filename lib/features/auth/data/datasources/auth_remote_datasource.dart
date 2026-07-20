import '../models/user_model.dart';

abstract class AuthRemoteDatasource {
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  });

  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  });

  Future<void> logout();

  Future<UserModel?> getCurrentUser();

  Stream<UserModel?> get authStateChanges;
}