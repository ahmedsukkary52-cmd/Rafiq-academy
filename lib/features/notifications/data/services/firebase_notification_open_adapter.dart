import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';

import '../../domain/services/notification_open_port.dart';

@LazySingleton(as: NotificationOpenPort)
class FirebaseNotificationOpenAdapter implements NotificationOpenPort {
  final FirebaseMessaging messaging;

  const FirebaseNotificationOpenAdapter({required this.messaging});

  static String _typeOf(RemoteMessage message) {
    final raw = message.data['type'];
    return raw is String ? raw.trim() : '';
  }

  @override
  Future<String?> initialOpenedType() async {
    try {
      final message = await messaging.getInitialMessage();
      return message == null ? null : _typeOf(message);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> openedTypes() =>
      FirebaseMessaging.onMessageOpenedApp.map(_typeOf);
}
