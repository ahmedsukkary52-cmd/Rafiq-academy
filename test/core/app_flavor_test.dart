import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/firebase/app_flavor.dart';

FirebaseOptions _options(String projectId) => FirebaseOptions(
  apiKey: 'key',
  appId: '1:1:android:1',
  messagingSenderId: '1',
  projectId: projectId,
);

void main() {
  group('parseAppFlavor', () {
    test('accepts dev, staging, prod and emulator', () {
      expect(parseAppFlavor('dev'), AppFlavor.dev);
      expect(parseAppFlavor('staging'), AppFlavor.staging);
      expect(parseAppFlavor('prod'), AppFlavor.prod);
      expect(parseAppFlavor('emulator'), AppFlavor.emulator);
      expect(() => parseAppFlavor('Emulator'), throwsStateError);
    });

    test('refuses to guess a missing or unknown flavor', () {
      expect(() => parseAppFlavor(null), throwsStateError);
      expect(() => parseAppFlavor(''), throwsStateError);
      expect(() => parseAppFlavor('stage'), throwsStateError);
      expect(() => parseAppFlavor('Staging'), throwsStateError);
      expect(() => parseAppFlavor('Dev'), throwsStateError);
    });
  });

  group('firebaseOptionsFor', () {
    test('dev returns the rafiq-academy options', () {
      final options = firebaseOptionsFor(
        AppFlavor.dev,
        devOptions: () => _options(devFirebaseProjectId),
      );
      expect(options.projectId, 'rafiq-academy');
    });

    test('dev refuses options for any other project', () {
      expect(
        () => firebaseOptionsFor(
          AppFlavor.dev,
          devOptions: () => _options('rafiq-academy-prod'),
        ),
        throwsStateError,
      );
    });

    test('staging refuses to start until its project is configured', () {
      expect(stagingFirebaseProjectId, 'rafiq-academy-staging');
      expect(
        () => firebaseOptionsFor(
          AppFlavor.staging,
          devOptions: () => _options(devFirebaseProjectId),
        ),
        throwsStateError,
      );
    });

    test('prod refuses to start until its project is configured', () {
      expect(
        () => firebaseOptionsFor(
          AppFlavor.prod,
          devOptions: () => _options(devFirebaseProjectId),
        ),
        throwsStateError,
      );
    });

    test('emulator never falls back to a real project', () {
      expect(
        () => firebaseOptionsFor(
          AppFlavor.emulator,
          devOptions: () => _options(devFirebaseProjectId),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('USE_FIREBASE_EMULATOR=true'),
          ),
        ),
      );
    });

    test('the generated options still target rafiq-academy', () {
      expect(firebaseOptionsFor(AppFlavor.dev).projectId, devFirebaseProjectId);
    });
  });
}
