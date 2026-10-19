import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../../firebase_options.dart';

/// Build flavor, from `flutter run/build --flavor <name>` (pubspec
/// `default-flavor` supplies `dev` when none is given).
enum AppFlavor { dev, prod }

/// Firebase project the dev flavor talks to (seed and test data only).
const String devFirebaseProjectId = 'rafiq-academy';

/// The running build's flavor. Throws for a missing or unknown flavor rather
/// than guessing, so a build can never silently use the wrong project.
AppFlavor currentAppFlavor() => parseAppFlavor(appFlavor);

AppFlavor parseAppFlavor(String? raw) => switch (raw) {
  'dev' => AppFlavor.dev,
  'prod' => AppFlavor.prod,
  _ => throw StateError(
    'Unknown app flavor "${raw ?? ''}"; build with --flavor dev or '
    '--flavor prod.',
  ),
};

/// Firebase options for [flavor] on the current platform.
///
/// The production project does not exist yet, so `prod` refuses to start
/// instead of falling back to the development project.
FirebaseOptions firebaseOptionsFor(
  AppFlavor flavor, {
  FirebaseOptions Function()? devOptions,
}) {
  switch (flavor) {
    case AppFlavor.dev:
      final options =
          (devOptions ?? () => DefaultFirebaseOptions.currentPlatform)();
      if (options.projectId != devFirebaseProjectId) {
        throw StateError(
          'Dev flavor must use $devFirebaseProjectId, '
          'got "${options.projectId}".',
        );
      }
      return options;
    case AppFlavor.prod:
      throw StateError(
        'The production Firebase project is not configured yet; '
        'build with --flavor dev.',
      );
  }
}
