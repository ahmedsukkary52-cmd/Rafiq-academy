import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'app_flavor.dart';

/// `flutter run --dart-define=USE_FIREBASE_EMULATOR=true` routes the app to
/// the local Emulator Suite. Debug builds only; absent or false uses the
/// build flavor's project (see app_flavor.dart).
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Must match the region the callables are deployed to (functions/src).
const String functionsRegion = 'europe-west1';

const String firebaseEmulatorProjectId = 'demo-rafiq-rules';

/// A physical phone reaches the PC's emulators through
/// `adb reverse tcp:<port> tcp:<port>`, so the phone's own loopback is used.
const String firebaseEmulatorHost = '127.0.0.1';
const int authEmulatorPort = 9099;
const int firestoreEmulatorPort = 8080;
const int functionsEmulatorPort = 5001;
const int storageEmulatorPort = 9199;

/// Fake API key and app ID: if emulator routing were ever skipped, requests
/// would be rejected instead of reaching a real project.
const FirebaseOptions firebaseEmulatorOptions = FirebaseOptions(
  apiKey: 'fake-emulator-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: firebaseEmulatorProjectId,
  storageBucket: '$firebaseEmulatorProjectId.appspot.com',
);

/// The google-services Gradle plugin creates the native [DEFAULT] app from
/// google-services.json before Dart runs, and firebase_core refuses to
/// re-initialize [DEFAULT] with a different API key, so the emulator gets its
/// own named app.
const String _emulatorAppName = 'rafiq-emulator';

FirebaseApp? _emulatorApp;

/// The emulator app; only valid after [initializeAppFirebase] completed in
/// emulator mode.
FirebaseApp get firebaseEmulatorApp =>
    _emulatorApp ??
    (throw StateError(
      'Firebase emulator app requested before initializeAppFirebase() '
      'finished wiring the emulators.',
    ));

/// Initializes Firebase. In emulator mode every service the app uses is
/// routed to the Emulator Suite before this returns, so call it before
/// `initDependencies()`.
Future<void> initializeAppFirebase() async {
  if (!useFirebaseEmulator) {
    await Firebase.initializeApp(
      options: firebaseOptionsFor(currentAppFlavor()),
    );
    return;
  }

  if (!kDebugMode) {
    throw StateError(
      'USE_FIREBASE_EMULATOR=true is only allowed in debug builds; '
      'refusing to start instead of falling back to production.',
    );
  }

  final app = await Firebase.initializeApp(
    name: _emulatorAppName,
    options: firebaseEmulatorOptions,
  );
  if (app.options.projectId != firebaseEmulatorProjectId ||
      app.options.apiKey != firebaseEmulatorOptions.apiKey ||
      app.options.appId != firebaseEmulatorOptions.appId) {
    throw StateError(
      'Firebase app "$_emulatorAppName" was initialized with non-emulator '
      'options (project "${app.options.projectId}").',
    );
  }

  // automaticHostMapping would rewrite 127.0.0.1 to 10.0.2.2 on Android,
  // which only exists inside the Android emulator.
  await FirebaseAuth.instanceFor(app: app).useAuthEmulator(
    firebaseEmulatorHost,
    authEmulatorPort,
    automaticHostMapping: false,
  );
  FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(
    firebaseEmulatorHost,
    firestoreEmulatorPort,
    automaticHostMapping: false,
  );
  FirebaseFunctions.instanceFor(app: app, region: functionsRegion)
      .useFunctionsEmulator(
    firebaseEmulatorHost,
    functionsEmulatorPort,
    automaticHostMapping: false,
  );
  await FirebaseStorage.instanceFor(app: app).useStorageEmulator(
    firebaseEmulatorHost,
    storageEmulatorPort,
    automaticHostMapping: false,
  );

  _emulatorApp = app;
}
