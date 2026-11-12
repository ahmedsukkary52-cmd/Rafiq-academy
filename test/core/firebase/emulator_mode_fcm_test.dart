// FCM stays dormant in Firebase Emulator mode: no token, no registration, no
// push listeners. The review build keeps the native FirebaseMessaging
// component (see android/app/src/dev-review/AndroidManifest.xml), so these
// Dart-side gates are what keep it unused.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/di/di_module.dart';
import 'package:rafiq_academy/core/firebase/app_firebase.dart';

class _Module extends DiModule {}

/// Text of the `{ ... }` block whose opening brace is at [open].
String _braceBlock(String src, int open) {
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(open, i + 1);
  }
  fail('unbalanced braces from offset $open');
}

void main() {
  String read(String p) => File(p).readAsStringSync();

  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => MapEntry(f.path.replaceAll('\\', '/'), f.readAsStringSync()))
      .toList();

  test('token and permission calls live only in the adapter and the '
      'registrar that drives it', () {
    const allowed = {
      'lib/features/notifications/data/services/firebase_messaging_adapter.dart',
      'lib/features/notifications/data/services/fcm_token_registrar.dart',
    };
    final callers = [
      for (final MapEntry(key: path, value: src) in libFiles)
        if (RegExp(
          r'\b(messaging|FirebaseMessaging\.instance)\s*\.\s*'
          r'(getToken|requestPermission|onTokenRefresh|deleteToken|'
          r'subscribeToTopic|setAutoInitEnabled)\b',
        ).hasMatch(src))
          path,
    ];
    expect(callers.toSet().difference(allowed), isEmpty);
  });

  test('FirebaseMessaging.instance is reached only through the DI getter', () {
    final users = [
      for (final MapEntry(key: path, value: src) in libFiles)
        if (src.contains('FirebaseMessaging.instance')) path,
    ];
    expect(users, ['lib/core/di/di_module.dart']);
    expect(
      RegExp(
        r'FirebaseMessaging get firebaseMessaging => useFirebaseEmulator\s*'
        r'\?\s*throw StateError\(',
      ).hasMatch(read('lib/core/di/di_module.dart')),
      isTrue,
    );
  });

  test('every FCM service is a lazy singleton (never built eagerly)', () {
    final config = read('lib/core/di/injection_container.config.dart');
    for (final type in [
      'FirebaseMessaging',
      'FcmMessagingPort',
      'ForegroundPushPresenter',
      'NotificationOpenPort',
      'FcmTokenRegistrar',
    ]) {
      expect(
        RegExp('gh\\.lazySingleton<_i\\d+\\.$type>').hasMatch(config),
        isTrue,
        reason: type,
      );
      expect(
        RegExp('gh\\.singleton(Async)?<_i\\d+\\.$type>').hasMatch(config),
        isFalse,
        reason: type,
      );
    }
  });

  test('main resolves FCM services only behind the emulator guard', () {
    final src = read('lib/main.dart');
    final guarded = <(int, int)>[];
    const guard = 'if (!useFirebaseEmulator) {';
    for (
      var at = src.indexOf(guard);
      at >= 0;
      at = src.indexOf(guard, at + 1)
    ) {
      final open = at + guard.length - 1;
      guarded.add((open, open + _braceBlock(src, open).length));
    }
    final fcm = RegExp(
      r'sl<(FcmTokenRegistrar|ForegroundPushPresenter|NotificationOpenPort|'
      r'FcmMessagingPort|FirebaseMessaging)>\(\)',
    );
    final matches = fcm.allMatches(src).toList();
    expect(matches, isNotEmpty);
    for (final m in matches) {
      final inGuard = guarded.any((r) => m.start > r.$1 && m.end < r.$2);
      final inTernary = RegExp(
        r'useFirebaseEmulator\s*\?\s*const OfflineNotificationOpenPort\(\)\s*:\s*$',
      ).hasMatch(src.substring(0, m.start));
      expect(inGuard || inTernary, isTrue, reason: m.group(0));
    }
    for (final other in libFiles.where((e) => e.key != 'lib/main.dart')) {
      expect(fcm.hasMatch(other.value), isFalse, reason: other.key);
    }
  });

  test(
    'emulator mode: DI refuses FirebaseMessaging before touching the plugin',
    () {
      expect(
        () => _Module().firebaseMessaging,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Emulator mode'),
          ),
        ),
      );
    },
    skip: useFirebaseEmulator
        ? false
        : 'runs with --dart-define=USE_FIREBASE_EMULATOR=true',
  );
}
