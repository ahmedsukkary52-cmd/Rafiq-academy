import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    required ValueNotifier<bool> seen,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        supportedLocales: AppLocaleConfig.supportedLocales,
        localizationsDelegates: AppLocaleConfig.localizationsDelegates,
        theme: AppTheme.theme,
        home: OnboardingPage(onboardingSeen: seen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows first slide and advances with التالي', (tester) async {
    final seen = ValueNotifier(false);
    addTearDown(seen.dispose);

    await pumpOnboarding(tester, seen: seen);

    expect(find.textContaining('أكاديمية بصمة'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(seen.value, isFalse);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsOneWidget);
    expect(find.textContaining('التقدم والجوائز'), findsOneWidget);
    expect(seen.value, isFalse);
  });

  testWidgets('تخطى marks onboarding seen in prefs and notifier', (
    tester,
  ) async {
    final seen = ValueNotifier(false);
    addTearDown(seen.dispose);

    await pumpOnboarding(tester, seen: seen);
    await tester.tap(find.text('تخطى'));
    await tester.pumpAndSettle();

    expect(seen.value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingSeenPrefKey), isTrue);
  });

  testWidgets('last-slide تسجيل الدخول finishes onboarding', (tester) async {
    final seen = ValueNotifier(false);
    addTearDown(seen.dispose);

    await pumpOnboarding(tester, seen: seen);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(seen.value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingSeenPrefKey), isTrue);
  });
}
