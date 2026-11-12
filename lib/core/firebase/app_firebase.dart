import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'app_flavor.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` is REQUIRED for the local
/// flavors (dev, staging). Absent, false or malformed values are treated as
/// "not requested" and the app refuses to start (see [assertFirebaseRouting]).
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Must match the region the callables are deployed to (functions/src).
const String functionsRegion = 'europe-west1';

const String firebaseEmulatorProjectId = localEmulatorProjectId;

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

/// Local flavors ship without a native [DEFAULT] app (FirebaseInitProvider is
/// removed in android/app/src/{dev,staging}/AndroidManifest.xml), so the
/// emulator always gets its own named app. A Dart-side [DEFAULT] app with the
/// same fake options is still required: cloud_firestore resolves its platform
/// delegate through `Firebase.app()` even for `instanceFor(app: ...)`, and a
/// few call sites use the default instances directly.
const String _emulatorAppName = 'basma-emulator';

/// Throws unless [host] is the literal IPv4 loopback used for the emulators.
void assertLoopbackEmulatorHost(String host) {
  if (host != '127.0.0.1') {
    throw StateError('Firebase Emulator host must be 127.0.0.1, got "$host".');
  }
}

/// Throws unless [options] are exactly the fake local emulator options.
void assertEmulatorOptions(FirebaseOptions options) {
  if (options.projectId != firebaseEmulatorProjectId ||
      options.apiKey != firebaseEmulatorOptions.apiKey ||
      options.appId != firebaseEmulatorOptions.appId) {
    throw StateError(
      'Firebase app "$_emulatorAppName" was initialized with non-emulator '
      'options (project "${options.projectId}").',
    );
  }
}

FirebaseApp? _emulatorApp;

/// The emulator app; only valid after [initializeAppFirebase] completed.
FirebaseApp get firebaseEmulatorApp =>
    _emulatorApp ??
    (throw StateError(
      'Firebase emulator app requested before initializeAppFirebase() '
      'finished wiring the emulators.',
    ));

/// Initializes Firebase. Fail-closed: only a local flavor in a debug build
/// with USE_FIREBASE_EMULATOR=true gets past [assertFirebaseRouting]; every
/// service the app uses is routed to the Emulator Suite before this returns,
/// independent of whether the emulators are actually running.
Future<void> initializeAppFirebase() async {
  assertFirebaseRouting(
    flavor: currentAppFlavor(),
    emulatorRequested: useFirebaseEmulator,
    isDebugBuild: kDebugMode,
  );
  assertLoopbackEmulatorHost(firebaseEmulatorHost);

  final defaultApp = await Firebase.initializeApp(
    options: firebaseEmulatorOptions,
  );
  assertEmulatorOptions(defaultApp.options);
  await _useEmulators(defaultApp);

  final app = await Firebase.initializeApp(
    name: _emulatorAppName,
    options: firebaseEmulatorOptions,
  );
  assertEmulatorOptions(app.options);
  await _useEmulators(app);

  _emulatorApp = app;
}

/// Routes every service the app uses on [app] to the loopback emulators.
Future<void> _useEmulators(FirebaseApp app) async {
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
  FirebaseFunctions.instanceFor(
    app: app,
    region: functionsRegion,
  ).useFunctionsEmulator(
    firebaseEmulatorHost,
    functionsEmulatorPort,
    automaticHostMapping: false,
  );
  await FirebaseStorage.instanceFor(app: app).useStorageEmulator(
    firebaseEmulatorHost,
    storageEmulatorPort,
    automaticHostMapping: false,
  );
}
