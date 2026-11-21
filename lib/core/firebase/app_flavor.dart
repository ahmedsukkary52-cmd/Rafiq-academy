import 'package:flutter/services.dart' show appFlavor;

/// Build flavor, from `flutter run/build --flavor <name>` (pubspec
/// `default-flavor` supplies `dev` when none is given).
///
/// Flavor != Firebase project. `dev` and `staging` are LOCAL flavors that may
/// only talk to the Firebase Emulator Suite. `trial` connects to the real
/// `rafiq-academy` project (no emulator). `prod` has no Firebase project
/// configured yet (the production decision is pending), so it refuses to
/// start.
enum AppFlavor { dev, staging, trial, prod }

/// The only Firebase project ID a local flavor may use. `demo-` IDs are
/// treated by the Emulator Suite as offline demo projects (no real project).
const String localEmulatorProjectId = 'demo-rafiq-rules';

/// Real Firebase project for the academy trial APK (`trial` flavor).
const String trialFirebaseProjectId = 'rafiq-academy';

/// The running build's flavor. Throws for a missing or unknown flavor rather
/// than guessing, so a build can never silently use the wrong project.
AppFlavor currentAppFlavor() => parseAppFlavor(appFlavor);

AppFlavor parseAppFlavor(String? raw) => switch (raw) {
  'dev' => AppFlavor.dev,
  'staging' => AppFlavor.staging,
  'trial' => AppFlavor.trial,
  'prod' => AppFlavor.prod,
  _ => throw StateError(
    'Unknown app flavor "${raw ?? ''}"; build with --flavor dev, '
    '--flavor staging, --flavor trial or --flavor prod.',
  ),
};

/// True for flavors that must run against the local Emulator Suite only.
bool isLocalFlavor(AppFlavor flavor) =>
    flavor == AppFlavor.dev || flavor == AppFlavor.staging;

/// Fail-closed routing gate, run before any Firebase call.
///
/// Local flavors: only pass in a debug build with `USE_FIREBASE_EMULATOR=true`.
/// Trial: only pass when the emulator is not requested (debug or release).
/// Prod: always refuses until production Firebase is configured.
void assertFirebaseRouting({
  required AppFlavor flavor,
  required bool emulatorRequested,
  required bool isDebugBuild,
}) {
  if (flavor == AppFlavor.prod) {
    if (emulatorRequested) {
      throw StateError(
        'The prod flavor must never be routed to the Firebase Emulator.',
      );
    }
    throw StateError(
      'The production Firebase project is not configured yet; '
      'local review builds use --flavor dev|staging with '
      '--dart-define=USE_FIREBASE_EMULATOR=true.',
    );
  }
  if (flavor == AppFlavor.trial) {
    if (emulatorRequested) {
      throw StateError(
        'The trial flavor must not use the Firebase Emulator; build without '
        '--dart-define=USE_FIREBASE_EMULATOR=true.',
      );
    }
    return;
  }
  if (!emulatorRequested) {
    throw StateError(
      'Local flavor "${flavor.name}" is Emulator-only: build with '
      '--dart-define=USE_FIREBASE_EMULATOR=true. Refusing to start instead '
      'of contacting any real Firebase project.',
    );
  }
  if (!isDebugBuild) {
    throw StateError(
      'Local flavor "${flavor.name}" is debug-only; refusing to start a '
      'non-debug Emulator build.',
    );
  }
}