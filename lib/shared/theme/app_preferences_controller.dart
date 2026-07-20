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

/// يدير تفضيلات المظهر (الوضع الليلي وحجم الخط) اللي بتتخزن محليًا
/// وتتطبق فورًا على كل الشجرة عن طريق [ValueNotifier]s.
class AppPreferencesController {
  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeMode;
  final ValueNotifier<AppFontSize> fontSize;

  AppPreferencesController._(this._prefs, this.themeMode, this.fontSize);

  static Future<AppPreferencesController> load(SharedPreferences prefs) async {
    final isDark = prefs.getBool(_darkModePrefKey) ?? false;
    final fontSizeName = prefs.getString(_fontSizePrefKey);

    return AppPreferencesController._(
      prefs,
      ValueNotifier(isDark ? ThemeMode.dark : ThemeMode.light),
      ValueNotifier(AppFontSize.fromName(fontSizeName)),
    );
  }

  Future<void> setDarkMode(bool enabled) async {
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool(_darkModePrefKey, enabled);
  }

  Future<void> setFontSize(AppFontSize size) async {
    fontSize.value = size;
    await _prefs.setString(_fontSizePrefKey, size.name);
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
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
