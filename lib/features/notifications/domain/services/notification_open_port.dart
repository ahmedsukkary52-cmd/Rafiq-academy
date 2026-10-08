/// Push notifications the user tapped (§15). Only the notification `type`
/// crosses this boundary — payloads carry no content.
abstract class NotificationOpenPort {
  /// Type of the push that launched the app from a terminated state, if any.
  Future<String?> initialOpenedType();

  /// Types of pushes tapped while the app is in the background.
  Stream<String> openedTypes();
}
