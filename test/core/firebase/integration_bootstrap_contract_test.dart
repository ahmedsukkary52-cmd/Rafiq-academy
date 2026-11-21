import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/firebase/app_firebase.dart';
import 'package:rafiq_academy/core/firebase/app_flavor.dart';

import '../../../integration_test/support/emulator_health.dart';
import '../../../integration_test/support/demo_accounts.dart';

void main() {
  group('Flutter ↔ Emulator integration bootstrap contracts', () {
    test('demo accounts stay on emulator-only domains', () {
      for (final a in [
        DemoAccounts.admin,
        DemoAccounts.parent,
        DemoAccounts.student,
        DemoAccounts.teacher,
      ]) {
        expect(a.email, contains('@rafiq.demo'));
        expect(a.password.length, greaterThanOrEqualTo(8));
        expect(a.uid, startsWith('demo-'));
      }
    });

    test('emulator health refuses non-loopback hosts', () {
      expect(
        () => EmulatorHealth(host: '10.0.2.2').assertReady(),
        throwsStateError,
      );
      expect(
        () => EmulatorHealth(host: 'firestore.googleapis.com').assertReady(),
        throwsStateError,
      );
    });

    test(
      'assertReady fails closed when Emulator Suite is down (no Production)',
      () async {
        // Ports are currently expected down in a cold workspace; if someone
        // left serve running this still validates the throw path by probing
        // an unused high port.
        final health = EmulatorHealth(
          authPort: 59999,
          firestorePort: 59998,
          functionsPort: 59997,
          storagePort: 59996,
          timeout: const Duration(milliseconds: 200),
        );
        await expectLater(health.assertReady(), throwsStateError);
      },
    );

    test('local flavor still requires USE_FIREBASE_EMULATOR', () {
      // This test process has no dart-define — mirrors a misconfigured
      // integration run that forgot the define.
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

    test('integration_test package and entry points exist', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('integration_test:'));
      expect(Directory('integration_test').existsSync(), isTrue);
      expect(
        File('integration_test/auth_role_routing_test.dart').existsSync(),
        isTrue,
      );
      expect(
        File('integration_test/student_data_load_test.dart').existsSync(),
        isTrue,
      );
      expect(
        File('integration_test/parent_payments_load_test.dart').existsSync(),
        isTrue,
      );
      expect(
        File('functions/scripts/seed-integration-fixture.mjs').existsSync(),
        isTrue,
      );
    });
  });
}
