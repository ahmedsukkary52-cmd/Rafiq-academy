import 'package:flutter/services.dart' show appFlavor;

/// Build flavor, from `flutter run/build --flavor <name>` (pubspec
/// `default-flavor` supplies `dev` when none is given).
///
/// Flavor != Firebase project. `dev` and `staging` are LOCAL flavors that may
/// only talk to the Firebase Emulator Suite. `prod` has no Firebase project
/// configured yet (the production decision is pending), so it refuses to
/// start. No flavor can reach a real Firebase project from this file:
/// `lib/firebase_options.dart` is intentionally not imported here.
enum AppFlavor { dev, staging, prod }

/// The only Firebase project ID a local flavor may use. `demo-` IDs are
/// treated by the Emulator Suite as offline demo projects (no real project).
const String localEmulatorProjectId = 'demo-rafiq-rules';

/// The running build's flavor. Throws for a missing or unknown flavor rather
/// than guessing, so a build can never silently use the wrong project.
AppFlavor currentAppFlavor() => parseAppFlavor(appFlavor);

AppFlavor parseAppFlavor(String? raw) => switch (raw) {
  'dev' => AppFlavor.dev,
  'staging' => AppFlavor.staging,
  'prod' => AppFlavor.prod,
  _ => throw StateError(
    'Unknown app flavor "${raw ?? ''}"; build with --flavor dev, '
    '--flavor staging or --flavor prod.',
  ),
};

/// True for flavors that must run against the local Emulator Suite only.
bool isLocalFlavor(AppFlavor flavor) => flavor != AppFlavor.prod;

/// Fail-closed routing gate, run before any Firebase call.
///
/// Returns normally only for a local flavor, in a debug build, with
/// `USE_FIREBASE_EMULATOR=true`. Every other combination throws, so there is
/// no path that falls back to a real Firebase project.
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
