/// Whether this device's push delivery was stopped before sign-out.
enum DeviceRevocation {
  /// Nothing was registered for the session (e.g. emulator, no permission).
  notRegistered,

  /// A server confirmed it: the token write, or FCM deleting the token.
  confirmed,

  /// Not confirmed (offline, timeout, rejected): pushes may still arrive.
  unconfirmed,
}

/// Work that has to run while the user is still signed in: Rules only let a
/// user disable their own device token, so it cannot wait until after
/// sign-out.
abstract class SignOutPreparation {
  /// Completes within a bounded time whatever the network does; a failure is
  /// reported as [DeviceRevocation.unconfirmed], never as confirmed.
  Future<DeviceRevocation> beforeSignOut();

  /// Sign-out failed after [beforeSignOut]; the session for [uid] continues.
  Future<void> signOutAborted(String uid);
}

class NoSignOutPreparation implements SignOutPreparation {
  const NoSignOutPreparation();

  @override
  Future<DeviceRevocation> beforeSignOut() async =>
      DeviceRevocation.notRegistered;

  @override
  Future<void> signOutAborted(String uid) async {}
}
