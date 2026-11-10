import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../../firebase_options.dart';

/// Build flavor, from `flutter run/build --flavor <name>` (pubspec
/// `default-flavor` supplies `dev` when none is given). `emulator` is an
/// Android debug build for phone testing against the local Emulator Suite.
enum AppFlavor { dev, staging, prod, emulator }

/// Firebase project the dev flavor talks to (seed and test data only).
const String devFirebaseProjectId = 'rafiq-academy';

/// Firebase project the staging flavor will talk to once it is configured.
const String stagingFirebaseProjectId = 'rafiq-academy-staging';

/// The running build's flavor. Throws for a missing or unknown flavor rather
/// than guessing, so a build can never silently use the wrong project.
AppFlavor currentAppFlavor() => parseAppFlavor(appFlavor);

AppFlavor parseAppFlavor(String? raw) => switch (raw) {
  'dev' => AppFlavor.dev,
  'staging' => AppFlavor.staging,
  'prod' => AppFlavor.prod,
  'emulator' => AppFlavor.emulator,
  _ => throw StateError(
    'Unknown app flavor "${raw ?? ''}"; build with --flavor dev, '
    '--flavor staging, --flavor prod or --flavor emulator.',
  ),
};

/// Firebase options for [flavor] on the current platform.
///
/// The staging and production projects are not configured yet, so those
/// flavors refuse to start instead of falling back to the development project.
/// The emulator flavor has no real project at all: without
/// `USE_FIREBASE_EMULATOR=true` it refuses to start.
FirebaseOptions firebaseOptionsFor(
  AppFlavor flavor, {
  FirebaseOptions Function()? devOptions,
}) => switch (flavor) {
  AppFlavor.dev => _requireDevProject(
    (devOptions ?? () => DefaultFirebaseOptions.currentPlatform)(),
  ),
  AppFlavor.staging => throw _notConfigured(
    'staging ($stagingFirebaseProjectId)',
  ),
  AppFlavor.prod => throw _notConfigured('production'),
  AppFlavor.emulator => throw StateError(
    'The emulator flavor only runs against the Firebase Emulator Suite; '
    'build it with --dart-define=USE_FIREBASE_EMULATOR=true.',
  ),
};

FirebaseOptions _requireDevProject(FirebaseOptions options) {
  if (options.projectId != devFirebaseProjectId) {
    throw StateError(
      'Dev flavor must use $devFirebaseProjectId, got "${options.projectId}".',
    );
  }
  return options;
}

StateError _notConfigured(String project) => StateError(
  'The $project Firebase project is not configured yet; '
  'build with --flavor dev.',
);
