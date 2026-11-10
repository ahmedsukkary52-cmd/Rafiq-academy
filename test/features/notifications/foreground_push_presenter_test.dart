import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/notifications/data/services/firebase_notification_open_adapter.dart';
import 'package:rafiq_academy/features/notifications/data/services/foreground_push_presenter.dart';

class _FakeMessaging extends Fake implements FirebaseMessaging {
  RemoteMessage? initialMessage;
  bool initialThrows = false;
  final presentationCalls = <List<bool>>[];

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    if (initialThrows) throw StateError('no plugin');
    return initialMessage;
  }

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {
    presentationCalls.add([alert, badge, sound]);
  }
}

class _Shown {
  _Shown(this.id, this.title, this.body, this.payload);
  final int id;
  final String title;
  final String body;
  final String payload;
}

class _FakeDisplay implements LocalNotificationDisplay {
  void Function(String? payload)? onTap;
  bool initializeThrows = false;
  int channelsCreated = 0;
  String? launch;
  final shown = <_Shown>[];

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (initializeThrows) throw StateError('plugin missing');
    this.onTap = onTap;
  }

  @override
  Future<void> createChannel() async => channelsCreated++;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown.add(_Shown(id, title, body, payload));
  }

  @override
  Future<String?> launchPayload() async => launch;
}

RemoteMessage _push({
  String? type = 'evaluation',
  bool withNotification = true,
  String? collapseKey = 'notif-1',
}) => RemoteMessage(
  collapseKey: collapseKey,
  data: {if (type != null) 'type': type},
  notification: withNotification
      ? const RemoteNotification(title: 'تقييم جديد', body: 'تم تقييم ابنك')
      : null,
);

void main() {
  late _FakeMessaging messaging;
  late _FakeDisplay display;
  late StreamController<RemoteMessage> foreground;

  ForegroundPushPresenter presenter({required bool isAndroid}) =>
      ForegroundPushPresenter(
        messaging,
        display: display,
        foregroundMessages: foreground.stream,
        isAndroid: isAndroid,
      );

  setUp(() {
    messaging = _FakeMessaging();
    display = _FakeDisplay();
    foreground = StreamController<RemoteMessage>.broadcast();
  });

  tearDown(() => foreground.close());

  group('ForegroundPushPresenter on Android', () {
    test('creates the channel once and shows foreground pushes', () async {
      final p = presenter(isAndroid: true);
      await p.start();
      await p.start();
      expect(display.channelsCreated, 1);
      expect(messaging.presentationCalls, isEmpty);

      foreground.add(_push());
      await pumpEventQueue();

      expect(display.shown, hasLength(1));
      expect(display.shown.single.title, 'تقييم جديد');
      expect(display.shown.single.body, 'تم تقييم ابنك');
      expect(display.shown.single.payload, 'evaluation');
      await p.dispose();
    });

    test('ignores data-only pushes', () async {
      final p = presenter(isAndroid: true);
      await p.start();
      foreground.add(_push(withNotification: false));
      await pumpEventQueue();
      expect(display.shown, isEmpty);
      await p.dispose();
    });

    test('a repeated push reuses its notification id', () async {
      final p = presenter(isAndroid: true);
      await p.start();
      foreground
        ..add(_push())
        ..add(_push())
        ..add(_push(collapseKey: 'notif-2'));
      await pumpEventQueue();
      expect(display.shown[0].id, display.shown[1].id);
      expect(display.shown[2].id, isNot(display.shown[0].id));
      expect(display.shown.every((s) => s.id >= 0), isTrue);
      await p.dispose();
    });

    test('a broken plugin still listens instead of throwing', () async {
      display.initializeThrows = true;
      final p = presenter(isAndroid: true);
      await p.start();
      foreground.add(_push());
      await pumpEventQueue();
      expect(display.shown, hasLength(1));
      await p.dispose();
    });

    test('taps report the push type; blank payloads are dropped', () async {
      final p = presenter(isAndroid: true);
      await p.start();
      final taps = <String>[];
      final sub = p.tappedTypes().listen(taps.add);
      display.onTap!(' evaluation ');
      display.onTap!('');
      display.onTap!(null);
      await pumpEventQueue();
      expect(taps, ['evaluation']);
      await sub.cancel();
      await p.dispose();
    });

    test('launchType trims and drops blank payloads', () async {
      final p = presenter(isAndroid: true);
      expect(await p.launchType(), isNull);
      display.launch = '  ';
      expect(await p.launchType(), isNull);
      display.launch = ' assignment ';
      expect(await p.launchType(), 'assignment');
      await p.dispose();
    });
  });

  group('ForegroundPushPresenter on iOS', () {
    test('lets iOS present the push instead of showing a second one', () async {
      final p = presenter(isAndroid: false);
      await p.start();
      expect(messaging.presentationCalls, [
        [true, true, true],
      ]);
      expect(display.channelsCreated, 0);

      foreground.add(_push());
      await pumpEventQueue();
      expect(display.shown, isEmpty);
      await p.dispose();
    });
  });

  group('FirebaseNotificationOpenAdapter', () {
    late StreamController<RemoteMessage> opened;
    late ForegroundPushPresenter p;
    late FirebaseNotificationOpenAdapter adapter;

    setUp(() async {
      opened = StreamController<RemoteMessage>.broadcast();
      p = presenter(isAndroid: true);
      await p.start();
      adapter = FirebaseNotificationOpenAdapter(
        messaging: messaging,
        foreground: p,
        openedMessages: opened.stream,
      );
    });

    tearDown(() async {
      await opened.close();
      await p.dispose();
    });

    test('merges FCM opens and foreground notification taps', () async {
      final types = <String>[];
      final sub = adapter.openedTypes().listen(types.add);
      opened.add(_push(type: 'assignment'));
      display.onTap!('evaluation');
      await pumpEventQueue();
      expect(types, ['assignment', 'evaluation']);
      await sub.cancel();
    });

    test('initial open prefers the FCM launch message', () async {
      messaging.initialMessage = _push(type: 'assignment');
      display.launch = 'evaluation';
      expect(await adapter.initialOpenedType(), 'assignment');
    });

    test('initial open falls back to the local notification launch', () async {
      display.launch = 'evaluation';
      expect(await adapter.initialOpenedType(), 'evaluation');
      messaging.initialThrows = true;
      expect(await adapter.initialOpenedType(), 'evaluation');
    });

    test('no launch at all yields null', () async {
      expect(await adapter.initialOpenedType(), isNull);
    });
  });

  test('channel id matches the AndroidManifest default channel', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(
        r'default_notification_channel_id"\s+android:value="([^"]+)"',
      ).firstMatch(manifest)?.group(1),
      PushNotificationChannel.id,
    );
  });
}
