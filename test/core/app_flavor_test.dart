import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
    test('accepts dev, staging and prod', () {
      expect(parseAppFlavor('dev'), AppFlavor.dev);
      expect(parseAppFlavor('staging'), AppFlavor.staging);
      expect(parseAppFlavor('prod'), AppFlavor.prod);
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

    test('staging and prod never fall back to the generated dev options', () {
      var devOptionsRequested = false;
      FirebaseOptions devOptions() {
        devOptionsRequested = true;
        return _options(devFirebaseProjectId);
      }

      for (final flavor in [AppFlavor.staging, AppFlavor.prod]) {
        expect(() => firebaseOptionsFor(flavor), throwsStateError);
        expect(
          () => firebaseOptionsFor(flavor, devOptions: devOptions),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('not configured yet'),
            ),
          ),
          reason: flavor.name,
        );
      }
      expect(devOptionsRequested, isFalse);
    });

    test('the generated options still target rafiq-academy', () {
      expect(firebaseOptionsFor(AppFlavor.dev).projectId, devFirebaseProjectId);
    });

    test('the generated iOS options target rafiq-academy', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final options = firebaseOptionsFor(AppFlavor.dev);
      expect(options.projectId, devFirebaseProjectId);
      expect(options.iosBundleId, 'com.example.rafiqAcademy');
    });
  });
}
