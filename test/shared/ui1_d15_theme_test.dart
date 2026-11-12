import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/presentation/pages/settings_page.dart';
import 'package:rafiq_academy/shared/theme/app_preferences_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI-1 D15 dark theme not exposed', () {
    testWidgets('SettingsPage has no dark-mode toggle', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = await AppPreferencesController.load(prefs);

      await tester.pumpWidget(
        AppPreferencesScope(
          controller: controller,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );

      expect(find.text('الوضع الليلي'), findsNothing);
      expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
      // D15 is Arabic-only; the dead language row is removed (OA-27).
      expect(find.text('اللغة'), findsNothing);
      expect(find.text('حجم الخط'), findsOneWidget);
    });

    test('preferences always report light / not dark', () async {
      SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final controller = await AppPreferencesController.load(prefs);

      expect(controller.themeMode.value, ThemeMode.light);
      expect(controller.isDarkMode, isFalse);
      expect(prefs.containsKey('dark_mode_enabled'), isFalse);

      // ignore: deprecated_member_use_from_same_package
      await controller.setDarkMode(true);
      expect(controller.themeMode.value, ThemeMode.light);
      expect(controller.isDarkMode, isFalse);
    });
  });
}
