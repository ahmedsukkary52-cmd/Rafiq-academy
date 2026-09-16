/// C11 / WA-13 — frozen FCM device-token contract.
///
/// `firestore.rules` is authoritative; these helpers exist so Dart never
/// invents an alternate path shape, field name, or platform value.
///
/// Tokens live at `fcmTokens/{uid}/devices/{deviceId}` and are readable and
/// writable by their owner only. Server-owned fields ([serverOwnedFields]) are
/// written by trusted Cloud Functions through the Admin SDK.
class FcmTokenContract {
  const FcmTokenContract._();

  static const String collection = 'fcmTokens';
  static const String devicesSubcollection = 'devices';

  static const String tokenField = 'token';
  static const String platformField = 'platform';
  static const String createdAtField = 'createdAt';
  static const String updatedAtField = 'updatedAt';
  static const String disabledField = 'disabled';

  static const String platformAndroid = 'android';
  static const String platformIos = 'ios';
  static const String platformWeb = 'web';

  static const List<String> supportedPlatforms = [
    platformAndroid,
    platformIos,
    platformWeb,
  ];

  /// Fields the client may write — Rules enforce exactly this set.
  static const List<String> clientWritableFields = [
    tokenField,
    platformField,
    createdAtField,
    updatedAtField,
    disabledField,
  ];

  /// Written by trusted Cloud Functions only; client writes are denied.
  static const List<String> serverOwnedFields = [
    'disabledReason',
    'disabledAt',
    'lastSendAt',
    'lastErrorCode',
  ];

  static const int maxTokenLength = 4096;
  static const int maxDeviceIdLength = 128;

  /// `fcmTokens/{uid}/devices/{deviceId}`
  static String devicePath({required String uid, required String deviceId}) {
    final u = uid.trim();
    final d = deviceId.trim();
    if (u.isEmpty || d.isEmpty) {
      throw ArgumentError('fcm device path segments must be non-empty');
    }
    if (!isValidDeviceId(d)) {
      throw ArgumentError('invalid fcm deviceId: $d');
    }
    return '$collection/$u/$devicesSubcollection/$d';
  }

  static bool isSupportedPlatform(String platform) =>
      supportedPlatforms.contains(platform);

  static bool isUsableToken(String token) {
    final t = token.trim();
    return t.isNotEmpty && t.length <= maxTokenLength;
  }

  /// A stable per-install id: opaque, path-safe, never regenerated per launch.
  static bool isValidDeviceId(String deviceId) {
    final d = deviceId.trim();
    if (d.isEmpty || d.length > maxDeviceIdLength) return false;
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(d);
  }

  /// Platform key from host facts — keeps the adapter free of branching.
  static String platformKey({
    required bool isWeb,
    required String operatingSystem,
  }) {
    if (isWeb) return platformWeb;
    return operatingSystem.trim().toLowerCase() == 'ios'
        ? platformIos
        : platformAndroid;
  }
}
