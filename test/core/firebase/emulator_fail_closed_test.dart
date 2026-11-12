// Basma Emulator isolation — fail-closed routing (2026-11-06).
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/firebase/app_firebase.dart';
import 'package:rafiq_academy/core/firebase/app_flavor.dart';
import 'package:rafiq_academy/features/notifications/data/services/offline_notification_open_port.dart';

void main() {
  group('assertFirebaseRouting matrix', () {
    for (final flavor in AppFlavor.values) {
      for (final emulator in [false, true]) {
        for (final debug in [false, true]) {
          final allowed = flavor != AppFlavor.prod && emulator && debug;
          test('${flavor.name} emulator=$emulator debug=$debug '
              '-> ${allowed ? 'allowed' : 'throws'}', () {
            void run() => assertFirebaseRouting(
              flavor: flavor,
              emulatorRequested: emulator,
              isDebugBuild: debug,
            );
            if (allowed) {
              expect(run, returnsNormally);
            } else {
              expect(run, throwsStateError);
            }
          });
        }
      }
    }
  });

  test('missing / false / malformed define resolves to not requested', () {
    // The test process gets no define, exactly like a build without one.
    expect(useFirebaseEmulator, isFalse);
    expect(
      () => assertFirebaseRouting(
        flavor: AppFlavor.dev,
        emulatorRequested: useFirebaseEmulator,
        isDebugBuild: true,
      ),
      throwsStateError,
    );
  });

  test('unknown flavor never reaches routing', () {
    expect(() => parseAppFlavor('qa'), throwsStateError);
    expect(() => parseAppFlavor(null), throwsStateError);
  });

  test(
    'initializeAppFirebase fails closed in this unflavored test process',
    () async {
      // No appFlavor and no define: must throw before any Firebase call.
      await expectLater(initializeAppFirebase(), throwsStateError);
      expect(() => firebaseEmulatorApp, throwsStateError);
    },
  );

  test('emulator endpoints are loopback-only with fixed ports', () {
    expect(firebaseEmulatorHost, '127.0.0.1');
    expect(() => assertLoopbackEmulatorHost('127.0.0.1'), returnsNormally);
    for (final bad in [
      '10.0.2.2',
      'localhost',
      '0.0.0.0',
      '192.168.1.5',
      'firestore.googleapis.com',
      '',
    ]) {
      expect(
        () => assertLoopbackEmulatorHost(bad),
        throwsStateError,
        reason: bad,
      );
    }
    expect(
      [
        authEmulatorPort,
        firestoreEmulatorPort,
        functionsEmulatorPort,
        storageEmulatorPort,
      ],
      [9099, 8080, 5001, 9199],
    );
    expect(functionsRegion, 'europe-west1');
  });

  test('emulator options are fake and rejected if mixed with real ones', () {
    expect(firebaseEmulatorOptions.projectId, 'demo-rafiq-rules');
    expect(firebaseEmulatorOptions.apiKey, 'fake-emulator-api-key');
    expect(
      () => assertEmulatorOptions(firebaseEmulatorOptions),
      returnsNormally,
    );
    const mixed = FirebaseOptions(
      apiKey: 'fake-emulator-api-key',
      appId: '1:000000000000:android:0000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'rafiq-academy',
    );
    expect(() => assertEmulatorOptions(mixed), throwsStateError);
  });

  test('offline notification port reports nothing and never fails', () async {
    const port = OfflineNotificationOpenPort();
    expect(await port.initialOpenedType(), isNull);
    expect(await port.openedTypes().toList(), isEmpty);
  });

  group('static wiring', () {
    String read(String p) => File(p).readAsStringSync();

    test('no lib file imports the real generated firebase_options.dart', () {
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) => RegExp(
              r'''^\s*(import|export)\s+['"][^'"]*firebase_options\.dart''',
              multiLine: true,
            ).hasMatch(f.readAsStringSync()),
          )
          .map((f) => f.path)
          .where(
            (p) =>
                !p.replaceAll('\\', '/').endsWith('lib/firebase_options.dart'),
          )
          .toList();
      expect(offenders, isEmpty);
    });

    test('app_firebase has no non-emulator initializeApp path', () {
      final src = read('lib/core/firebase/app_firebase.dart');
      final calls = RegExp(
        r'Firebase\.initializeApp\(([^)]*)\)',
      ).allMatches(src).map((m) => m.group(1)!).toList();
      expect(calls, hasLength(2));
      for (final args in calls) {
        expect(args, contains('options: firebaseEmulatorOptions'));
      }
      expect(calls.where((a) => a.contains('name:')).toList(), [
        contains('name: _emulatorAppName'),
      ]);
      expect(src, isNot(contains('DefaultFirebaseOptions')));
      expect(
        src.indexOf('assertFirebaseRouting('),
        lessThan(src.indexOf('Firebase.initializeApp(')),
      );
      expect(
        src.indexOf('assertLoopbackEmulatorHost(firebaseEmulatorHost)'),
        lessThan(src.indexOf('Firebase.initializeApp(')),
      );
    });

    test('[DEFAULT] app gets the fake options and the emulators before the '
        'named app is created', () {
      final src = read('lib/core/firebase/app_firebase.dart');
      final init = src.substring(
        src.indexOf('Future<void> initializeAppFirebase() async {'),
        src.indexOf('Future<void> _useEmulators('),
      );
      final ordered = [
        'final defaultApp = await Firebase.initializeApp(',
        'assertEmulatorOptions(defaultApp.options);',
        'await _useEmulators(defaultApp);',
        'final app = await Firebase.initializeApp(',
        'assertEmulatorOptions(app.options);',
        'await _useEmulators(app);',
        '_emulatorApp = app;',
      ];
      var at = -1;
      for (final step in ordered) {
        final next = init.indexOf(step);
        expect(next, greaterThan(at), reason: step);
        at = next;
      }
    });

    test('every service is routed to 127.0.0.1 without host mapping', () {
      final src = read('lib/core/firebase/app_firebase.dart');
      final wiring = src.substring(src.indexOf('Future<void> _useEmulators('));
      for (final call in [
        'useAuthEmulator(',
        'useFirestoreEmulator(',
        'useFunctionsEmulator(',
        'useStorageEmulator(',
      ]) {
        expect(call.allMatches(wiring).length, 1, reason: call);
      }
      expect('firebaseEmulatorHost,'.allMatches(wiring).length, 4);
      expect('automaticHostMapping: false'.allMatches(wiring).length, 4);
      expect(wiring, isNot(contains('automaticHostMapping: true')));
    });

    test('DI never touches FirebaseMessaging.instance in emulator mode', () {
      final src = read('lib/core/di/di_module.dart');
      expect(
        src,
        contains(
          'FirebaseMessaging get firebaseMessaging => useFirebaseEmulator',
        ),
      );
    });

    test('main uses the offline push port in emulator mode', () {
      final src = read('lib/main.dart');
      expect(src, contains('useFirebaseEmulator'));
      expect(src, contains('const OfflineNotificationOpenPort()'));
    });

    test('main wires FCM sign-out and the foreground presenter only behind '
        'the same non-emulator guard', () {
      final src = read('lib/main.dart');
      const guard = 'if (!useFirebaseEmulator) {';
      final mainStart = src.indexOf('Future<void> main() async {');
      expect(mainStart, isNonNegative);
      final guardStart = src.indexOf(guard, mainStart);
      expect(guardStart, isNonNegative);
      final block = _braceBlock(src, guardStart + guard.length - 1);

      const signOut = 'sl<AuthBloc>().attachSignOutPreparation(';
      const fcmPrep = 'FcmSignOutPreparation(() => sl<FcmTokenRegistrar>())';
      const presenter = 'await sl<ForegroundPushPresenter>().start();';
      for (final call in [signOut, fcmPrep, presenter]) {
        expect(block, contains(call), reason: call);
        expect(call.allMatches(src).length, 1, reason: call);
      }

      expect(
        RegExp(
          r'useFirebaseEmulator\s*\?\s*const OfflineNotificationOpenPort\(\)\s*'
          r':\s*sl<NotificationOpenPort>\(\)',
        ).hasMatch(src),
        isTrue,
      );
    });

    test('generated DI does not register sign-out preparation or a pending '
        'revocation store (wired from main instead)', () {
      final src = read('lib/core/di/injection_container.config.dart');
      expect(src, isNot(contains('SignOutPreparation')));
      expect(src, isNot(contains('FcmPendingRevocationStore')));
      expect(src, isNot(contains('signOutPreparation:')));
      expect(src, isNot(contains('pendingRevocations:')));
      expect(src, contains('ForegroundPushPresenter'));
      expect(
        read('lib/core/di/di_module.dart'),
        isNot(contains('SignOutPreparation')),
      );
    });
  });
}

/// Text of the `{ ... }` block whose opening brace is at [open].
String _braceBlock(String src, int open) {
  expect(src[open], '{');
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(open, i + 1);
  }
  fail('unbalanced braces from offset $open');
}
