import '../../../auth/domain/services/sign_out_preparation.dart';
import 'fcm_token_registrar.dart';

/// Revokes this device's push token before Auth signs the user out.
///
/// The registrar is resolved on first use, so the eagerly built AuthBloc does
/// not touch FirebaseMessaging at startup.
class FcmSignOutPreparation implements SignOutPreparation {
  final FcmTokenRegistrar Function() _registrar;

  const FcmSignOutPreparation(this._registrar);

  @override
  Future<DeviceRevocation> beforeSignOut() =>
      _registrar().revokeBeforeSignOut();

  @override
  Future<void> signOutAborted(String uid) => _registrar().onSignedIn(uid);
}
