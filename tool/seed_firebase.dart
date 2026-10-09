/// Firebase initialization for the seeders, keyed by an explicit
/// [SeedTarget]. Always called through `runGuardedSeed` (seed_target.dart).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rafiq_academy/firebase_options.dart';

import 'seed_target.dart';

/// Ports from `firebase.json` → `emulators`.
const _emulatorHost = 'localhost';
const _authEmulatorPort = 9099;
const _firestoreEmulatorPort = 8080;

/// Options for [target]. The Android app registration is used on desktop
/// because no desktop Firebase app is registered.
FirebaseOptions seedFirebaseOptions(SeedTarget target) {
  const dev = DefaultFirebaseOptions.android;
  switch (target) {
    case SeedTarget.emulator:
      // demo- project: the emulators never reach a real project.
      return FirebaseOptions(
        apiKey: dev.apiKey,
        appId: dev.appId,
        messagingSenderId: dev.messagingSenderId,
        projectId: seedEmulatorProjectId,
      );
    case SeedTarget.dev:
      if (dev.projectId != seedDevProjectId) {
        throw SeedTargetException(
          'lib/firebase_options.dart points to "${dev.projectId}", '
          'expected dev project "$seedDevProjectId".',
        );
      }
      return dev;
    case SeedTarget.staging:
      throw const SeedTargetException(
        'Staging FirebaseOptions are not configured yet '
        '($seedStagingProjectId). Seeding staging is unavailable until the '
        'staging Firebase app is registered and its options are added.',
      );
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

  if (config.isEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(
      _emulatorHost,
      _authEmulatorPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      _emulatorHost,
      _firestoreEmulatorPort,
    );
  }
}
