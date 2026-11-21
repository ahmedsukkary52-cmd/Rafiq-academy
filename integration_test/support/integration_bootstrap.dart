import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/firebase/app_firebase.dart';
import 'package:rafiq_academy/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:rafiq_academy/main.dart';
import 'package:rafiq_academy/shared/theme/app_preferences_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'emulator_health.dart';

/// Boots the real app against Firebase Emulators only.
///
/// Requires:
/// - `--flavor dev` (or `staging`) so the flavor is local
/// - `--dart-define=USE_FIREBASE_EMULATOR=true`
/// - Emulator Suite on loopback ports from [app_firebase.dart]
/// - Seeded demo accounts (`seed:emulator` or `seed-integration-fixture`)
///
/// Fail-closed: missing Emulator → [StateError] before any Firebase init.
Future<void> bootstrapIntegrationApp(WidgetTester tester) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  expect(
    useFirebaseEmulator,
    isTrue,
    reason:
        'integration_test must run with --dart-define=USE_FIREBASE_EMULATOR=true',
  );

  await EmulatorHealth().assertReady();
  await initializeAppFirebase();

  // Physical devices keep Auth persistence across reinstalls. Clear both
  // apps wired to Emulators so journeys start at LoginPage, not a home.
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instanceFor(app: firebaseEmulatorApp).signOut();

  await sl.reset();
  await initDependencies();

  SharedPreferences.setMockInitialValues({onboardingSeenPrefKey: true});
  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = ValueNotifier<bool>(true);
  final appPreferences = await AppPreferencesController.load(prefs);

  await tester.pumpWidget(
    MyApp(onboardingSeen: onboardingSeen, appPreferences: appPreferences),
  );
  // Bound settle: Duration arg is per-frame pump, not a wall timeout.
  // Unbounded settle hung the first physical run for ~10 minutes.
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
  await _waitForLoginForm(tester);
}

/// Waits until the login form keys are mounted (post version-gate + auth).
Future<void> _waitForLoginForm(WidgetTester tester) async {
  final loginField = find.byKey(const Key('login-identifier'));
  for (var i = 0; i < 40; i++) {
    if (loginField.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  final types = tester.allWidgets
      .map((w) => w.runtimeType.toString())
      .take(48)
      .join(', ');
  fail(
    'Login form not reached after Emulator bootstrap (widget sample: $types). '
    'Check adb reverse + Auth Emulator and that no persisted session remains.',
  );
}

/// Fills the login form and submits. Uses real Auth Emulator + Firestore profile.
Future<void> loginWithDemoAccount(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  expect(find.byKey(const Key('login-identifier')), findsOneWidget);
  await tester.enterText(find.byKey(const Key('login-identifier')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.pump();

  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 25),
  );
}
