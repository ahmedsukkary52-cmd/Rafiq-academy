/// Platform push facts needed by WA-13 token lifecycle.
///
/// Keeps `firebase_messaging` out of the application layer so the registrar is
/// testable without a Firebase host.
abstract class FcmMessagingPort {
  /// Whether the user authorized notifications on this device.
  Future<bool> requestPermission();

  /// Current device token, or null when unavailable / not permitted.
  Future<String?> currentToken();

  /// Emits the new token whenever FCM rotates it.
  Stream<String> tokenRefreshes();

  /// One of [FcmTokenContract.supportedPlatforms].
  String platformKey();
}
