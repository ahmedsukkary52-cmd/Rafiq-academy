import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// The Android channel every push is shown on.
///
/// [id] must match `default_notification_channel_id` in AndroidManifest.xml,
/// which FCM uses for pushes that arrive while the app is in the background.
abstract final class PushNotificationChannel {
  static const String id = 'basma_general';
  static const String name = 'إشعارات بصمة';
  static const String description = 'تنبيهات التقييمات والواجبات والرسائل';
}

/// Shows local notifications for pushes received in the foreground.
abstract class LocalNotificationDisplay {
  Future<void> initialize({required void Function(String? payload) onTap});

  Future<void> createChannel();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  /// Payload of the local notification that launched the app, if any.
  Future<String?> launchPayload();
}

class FlutterLocalNotificationDisplay implements LocalNotificationDisplay {
  FlutterLocalNotificationDisplay([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested by FcmTokenRegistrar at sign-in.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<void> createChannel() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            PushNotificationChannel.id,
            PushNotificationChannel.name,
            description: PushNotificationChannel.description,
            importance: Importance.high,
          ),
        );
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          PushNotificationChannel.id,
          PushNotificationChannel.name,
          channelDescription: PushNotificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}

/// Makes pushes visible while the app is open.
///
/// FCM shows notification pushes itself only in the background. In the
/// foreground, Android gets a local notification on [PushNotificationChannel]
/// and iOS is told to present the push itself. A tapped local notification
/// reports the push `type`, as FCM opens do.
@lazySingleton
class ForegroundPushPresenter {
  ForegroundPushPresenter(
    this.messaging, {
    @ignoreParam LocalNotificationDisplay? display,
    @ignoreParam Stream<RemoteMessage>? foregroundMessages,
    @ignoreParam bool? isAndroid,
  }) : display = display ?? FlutterLocalNotificationDisplay(),
       _foregroundMessages = foregroundMessages,
       _isAndroid =
           isAndroid ?? defaultTargetPlatform == TargetPlatform.android;

  final FirebaseMessaging messaging;
  final LocalNotificationDisplay display;
  final Stream<RemoteMessage>? _foregroundMessages;
  final bool _isAndroid;

  final _taps = StreamController<String>.broadcast();
  Future<void>? _started;
  StreamSubscription<RemoteMessage>? _messagesSub;

  /// Idempotent. Failures are swallowed: background pushes still work.
  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    try {
      await display.initialize(onTap: _onTap);
      if (_isAndroid) {
        await display.createChannel();
      } else {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {}
    _messagesSub = (_foregroundMessages ?? FirebaseMessaging.onMessage).listen(
      _onForegroundMessage,
    );
  }

  /// Push types of tapped foreground notifications.
  Stream<String> tappedTypes() => _taps.stream;

  /// Push type of the foreground notification that launched the app.
  Future<String?> launchType() async {
    try {
      final type = (await display.launchPayload())?.trim() ?? '';
      return type.isEmpty ? null : type;
    } catch (_) {
      return null;
    }
  }

  void _onTap(String? payload) {
    final type = payload?.trim() ?? '';
    if (type.isNotEmpty) _taps.add(type);
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (!_isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;
    final type = message.data['type'];
    unawaited(
      display
          .show(
            id: notificationIdFor(message),
            title: notification.title ?? '',
            body: notification.body ?? '',
            payload: type is String ? type.trim() : '',
          )
          .catchError((Object _) {}),
    );
  }

  /// The same push (by collapse key, else message id) replaces itself.
  @visibleForTesting
  static int notificationIdFor(RemoteMessage message) {
    final key = message.collapseKey ?? message.messageId;
    if (key == null || key.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    }
    return key.hashCode & 0x7fffffff;
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _messagesSub?.cancel();
    await _taps.close();
  }
}
