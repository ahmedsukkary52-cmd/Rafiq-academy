import '../models/user_model.dart';

/// D1: there is no account-creation method. Identities are provisioned by the
/// Admin `adminProvisionUser` callable only.
abstract class AuthRemoteDatasource {
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> logout();

  /// Waits for Firebase Auth to restore a persisted session, then loads the
  /// authorized academy profile. `null` when no session exists.
  Future<UserModel?> getCurrentUser();

  /// Firebase Auth session uid changes (`null` = signed out / revoked).
  Stream<String?> get sessionUidChanges;
}
