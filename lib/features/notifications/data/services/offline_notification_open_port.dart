import '../../domain/services/notification_open_port.dart';

/// Emulator builds: FCM has no emulator and local flavors ship without a
/// native [DEFAULT] Firebase app, so push taps are explicitly unsupported.
/// Nothing is reported as opened; no FirebaseMessaging API is touched.
class OfflineNotificationOpenPort implements NotificationOpenPort {
  const OfflineNotificationOpenPort();

  @override
  Future<String?> initialOpenedType() async => null;

  @override
  Stream<String> openedTypes() => const Stream<String>.empty();
}
