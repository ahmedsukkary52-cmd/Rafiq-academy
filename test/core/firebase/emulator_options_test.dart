import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/firebase/app_firebase.dart';
import 'package:rafiq_academy/core/firebase/app_flavor.dart';

void main() {
  group('emulator FirebaseOptions', () {
    test('API key passes the Android Firebase Installations format check', () {
      // Without this every callable fails on Android before any request
      // reaches the Functions emulator.
      expect(
        RegExp(r'^A[\w-]{38}$').hasMatch(firebaseEmulatorOptions.apiKey),
        isTrue,
      );
      expect(firebaseEmulatorOptions.appId, contains(':'));
    });

    test('stays a fake identity on the emulator-only project', () {
      expect(firebaseEmulatorOptions.projectId, 'demo-rafiq-rules');
      expect(firebaseEmulatorOptions.apiKey, contains('Fake'));
      final real = firebaseOptionsFor(AppFlavor.dev);
      expect(firebaseEmulatorOptions.apiKey, isNot(real.apiKey));
      expect(firebaseEmulatorOptions.projectId, isNot(real.projectId));
    });
  });

  group('emulator endpoints', () {
    test('use the phone loopback reached through adb reverse', () {
      expect(firebaseEmulatorHost, '127.0.0.1');
      expect(authEmulatorPort, 9099);
      expect(firestoreEmulatorPort, 8080);
      expect(functionsEmulatorPort, 5001);
      expect(storageEmulatorPort, 9199);
      expect(functionsRegion, 'europe-west1');
    });

    test('every service is wired without Android host rewriting', () {
      final source = File(
        'lib/core/firebase/app_firebase.dart',
      ).readAsStringSync();
      for (final call in [
        'useAuthEmulator(',
        'useFirestoreEmulator(',
        'useFunctionsEmulator(',
        'useStorageEmulator(',
      ]) {
        expect(source, contains(call), reason: call);
      }
      expect('automaticHostMapping: false'.allMatches(source).length, 4);
      expect(source, contains('if (!kDebugMode) {'));
      expect(
        source,
        contains(
          "'USE_FIREBASE_EMULATOR=true is only allowed in debug builds; '",
        ),
      );
    });

    test('debug builds allow cleartext only to the loopback emulators', () {
      final config = File(
        'android/app/src/debug/res/xml/debug_network_security_config.xml',
      ).readAsStringSync();
      final domains = RegExp(
        r'<domain[^>]*>([^<]+)</domain>',
      ).allMatches(config).map((m) => m.group(1)).toList();
      expect(domains, ['127.0.0.1']);
      expect(config, isNot(contains('<base-config')));
    });
  });
}
