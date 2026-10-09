/// Firebase initialization for the seeders, keyed by an explicit
/// [SeedTarget]. Always called through `runGuardedSeed` (seed_target.dart).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'seed_target.dart';

/// Ports from `firebase.json` → `emulators`. The emulators listen on the IPv4
/// loopback only, so `localhost` (which may resolve to ::1 first) is avoided.
const _emulatorHost = '127.0.0.1';
const _authEmulatorPort = 9099;
const _firestoreEmulatorPort = 8080;

/// Emulator-only options. Fake API key and app ID: if the emulator hookup
/// ever failed, Auth would reject the key instead of reaching a real project
/// (Auth resolves the project from the API key, not from `projectId`).
const seedEmulatorFirebaseOptions = FirebaseOptions(
  apiKey: 'fake-emulator-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: seedEmulatorProjectId,
);

/// Options for [target]; only the emulator exists.
FirebaseOptions seedFirebaseOptions(SeedTarget target) {
  switch (target) {
    case SeedTarget.emulator:
      return seedEmulatorFirebaseOptions;
  }
}

/// Initializes Firebase for [config], connects the emulators when needed,
/// and re-checks the initialized project before returning.
Future<void> initializeSeedFirebase(SeedTargetConfig config) async {
  final options = seedFirebaseOptions(config.target);
  assertSeedProjectAllowed(options.projectId);
  if (options.projectId != config.projectId) {
    throw SeedTargetException(
      'Resolved options project "${options.projectId}" does not match '
      'target project "${config.projectId}".',
    );
  }

  final app = await Firebase.initializeApp(options: options);
  assertSeedProjectAllowed(app.options.projectId);

  if (app.options.apiKey != seedEmulatorFirebaseOptions.apiKey ||
      app.options.appId != seedEmulatorFirebaseOptions.appId) {
    throw const SeedTargetException(
      'Firebase was initialized with non-emulator options.',
    );
  }
  try {
    await FirebaseAuth.instance.useAuthEmulator(
      _emulatorHost,
      _authEmulatorPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      _emulatorHost,
      _firestoreEmulatorPort,
    );
  } catch (e) {
    throw SeedTargetException('Could not connect to the emulators: $e');
  }
}
