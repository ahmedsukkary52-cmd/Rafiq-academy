import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// أحجام الخط المتاحة في الإعدادات - قيمة textScaleFactor فعلية بتتطبق
/// على كل التطبيق عن طريق [MediaQuery] في [MyApp].
enum AppFontSize {
  small(0.9, 'صغير'),
  medium(1.0, 'متوسط'),
  large(1.15, 'كبير');

  final double scale;
  final String label;

  const AppFontSize(this.scale, this.label);

  static AppFontSize fromName(String? name) => AppFontSize.values.firstWhere(
    (e) => e.name == name,
    orElse: () => AppFontSize.medium,
  );
}

const String _darkModePrefKey = 'dark_mode_enabled';
const String _fontSizePrefKey = 'font_size';

/// Local preferences. D15: dark/light switching is OUT — [themeMode] is always
/// light and [setDarkMode] is a no-op that clears any legacy dark pref.
class AppPreferencesController {
  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeMode;
  final ValueNotifier<AppFontSize> fontSize;

  AppPreferencesController._(this._prefs, this.themeMode, this.fontSize);

  static Future<AppPreferencesController> load(SharedPreferences prefs) async {
    // D15 / UI-1: ignore legacy dark_mode_enabled; product is light-only.
    if (prefs.containsKey(_darkModePrefKey)) {
      await prefs.remove(_darkModePrefKey);
    }
    final fontSizeName = prefs.getString(_fontSizePrefKey);

    return AppPreferencesController._(
      prefs,
      ValueNotifier(ThemeMode.light),
      ValueNotifier(AppFontSize.fromName(fontSizeName)),
    );
  }

  /// Retained for binary compatibility; does not enable dark mode (D15).
  @Deprecated('D15: dark/light theme switching is out of scope for V1')
  Future<void> setDarkMode(bool enabled) async {
    themeMode.value = ThemeMode.light;
    await _prefs.remove(_darkModePrefKey);
  }

  Future<void> setFontSize(AppFontSize size) async {
    fontSize.value = size;
    await _prefs.setString(_fontSizePrefKey, size.name);
  }

  bool get isDarkMode => false;
}

/// يوفّر [AppPreferencesController] لأي صفحة تحت شجرة الـ widgets
/// (مثلاً صفحة الإعدادات) من غير الحاجة لـ DI منفصل - ده تفضيل محلي بحت.
class AppPreferencesScope extends InheritedWidget {
  final AppPreferencesController controller;

  const AppPreferencesScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static AppPreferencesController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppPreferencesScope>();
    assert(scope != null, 'AppPreferencesScope not found in context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(AppPreferencesScope oldWidget) =>
      oldWidget.controller != controller;
}
