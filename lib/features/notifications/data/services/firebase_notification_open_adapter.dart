import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';

import '../../domain/services/notification_open_port.dart';
import 'foreground_push_presenter.dart';

@LazySingleton(as: NotificationOpenPort)
class FirebaseNotificationOpenAdapter implements NotificationOpenPort {
  final FirebaseMessaging messaging;
  final ForegroundPushPresenter foreground;
  final Stream<RemoteMessage>? _openedMessages;

  FirebaseNotificationOpenAdapter({
    required this.messaging,
    required this.foreground,
    @ignoreParam Stream<RemoteMessage>? openedMessages,
  }) : _openedMessages = openedMessages;

  static String _typeOf(RemoteMessage message) {
    final raw = message.data['type'];
    return raw is String ? raw.trim() : '';
  }

  @override
  Future<String?> initialOpenedType() async {
    try {
      final message = await messaging.getInitialMessage();
      if (message != null) return _typeOf(message);
    } catch (_) {}
    return foreground.launchType();
  }

  @override
  Stream<String> openedTypes() {
    final subs = <StreamSubscription<String>>[];
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        final pushOpens =
            (_openedMessages ?? FirebaseMessaging.onMessageOpenedApp).map(
              _typeOf,
            );
        for (final source in [pushOpens, foreground.tappedTypes()]) {
          subs.add(source.listen(controller.add, onError: controller.addError));
        }
      },
      onCancel: () => Future.wait(subs.map((s) => s.cancel())),
    );
    return controller.stream;
  }
}
