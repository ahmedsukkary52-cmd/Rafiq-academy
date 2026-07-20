import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';

const _keyAppSounds = 'pref_app_sounds';
const _keyNotifications = 'pref_notifications';
const _keySessionReminders = 'pref_session_reminders';
const _keyScreenReader = 'pref_screen_reader';
const _keyLargeTouchTargets = 'pref_large_touch_targets';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SharedPreferences? _prefs;

  bool _appSounds = true;
  bool _notifications = true;
  bool _sessionReminders = true;
  bool _screenReader = false;
  bool _largeTouchTargets = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prefs = prefs;
      _appSounds = prefs.getBool(_keyAppSounds) ?? true;
      _notifications = prefs.getBool(_keyNotifications) ?? true;
      _sessionReminders = prefs.getBool(_keySessionReminders) ?? true;
      _screenReader = prefs.getBool(_keyScreenReader) ?? false;
      _largeTouchTargets = prefs.getBool(_keyLargeTouchTargets) ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appPreferences = AppPreferencesScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ الإعدادات')),
      body: _prefs == null
          ? const AppLoadingWidget()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingM),
              children: [
                const _SectionLabel('الصوت والإشعارات'),
                _ToggleTile(
                  icon: Icons.music_note_rounded,
                  iconBg: AppColors.primaryLight,
                  iconColor: AppColors.primary,
                  label: 'أصوات التطبيق',
                  value: _appSounds,
                  onChanged: (v) {
                    setState(() => _appSounds = v);
                    _prefs!.setBool(_keyAppSounds, v);
                  },
                ),
                _ToggleTile(
                  icon: Icons.notifications_rounded,
                  iconBg: AppColors.secondaryBg,
                  iconColor: AppColors.secondary,
                  label: 'الإشعارات',
                  value: _notifications,
                  onChanged: (v) {
                    setState(() => _notifications = v);
                    _prefs!.setBool(_keyNotifications, v);
                  },
                ),
                _ToggleTile(
                  icon: Icons.school_rounded,
                  iconBg: AppColors.primaryLight,
                  iconColor: AppColors.success,
                  label: 'تذكير الحصص',
                  value: _sessionReminders,
                  onChanged: (v) {
                    setState(() => _sessionReminders = v);
                    _prefs!.setBool(_keySessionReminders, v);
                  },
                ),

                const SizedBox(height: AppSizes.paddingM),
                const _SectionLabel('المظهر'),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: appPreferences.themeMode,
                  builder: (context, mode, _) {
                    return _ToggleTile(
                      icon: Icons.dark_mode_rounded,
                      iconBg: AppColors.dark,
                      iconColor: Colors.white,
                      iconOnDark: true,
                      label: 'الوضع الليلي',
                      value: mode == ThemeMode.dark,
                      onChanged: (v) => appPreferences.setDarkMode(v),
                    );
                  },
                ),
                _LinkTile(
                  icon: Icons.language_rounded,
                  iconBg: AppColors.primaryLight,
                  iconColor: AppColors.primary,
                  label: 'اللغة',
                  trailing: 'العربية',
                  onTap: () =>
                      AppSnackBar.showInfo(context, 'لغات إضافية قريباً'),
                ),
                ValueListenableBuilder<AppFontSize>(
                  valueListenable: appPreferences.fontSize,
                  builder: (context, size, _) {
                    return _LinkTile(
                      icon: Icons.text_fields_rounded,
                      iconBg: AppColors.secondaryBg,
                      iconColor: AppColors.secondary,
                      label: 'حجم الخط',
                      trailing: size.label,
                      onTap: () {
                        const values = AppFontSize.values;
                        final next = values[(size.index + 1) % values.length];
                        appPreferences.setFontSize(next);
                      },
                    );
                  },
                ),

                const SizedBox(height: AppSizes.paddingM),
                const _SectionLabel('إمكانية الوصول'),
                _ToggleTile(
                  icon: Icons.record_voice_over_rounded,
                  iconBg: AppColors.primaryLight,
                  iconColor: AppColors.primary,
                  label: 'القراءة الصوتية',
                  value: _screenReader,
                  onChanged: (v) {
                    setState(() => _screenReader = v);
                    _prefs!.setBool(_keyScreenReader, v);
                  },
                ),
                _ToggleTile(
                  icon: Icons.touch_app_rounded,
                  iconBg: AppColors.secondaryBg,
                  iconColor: AppColors.secondary,
                  label: 'مناطق لمس كبيرة',
                  value: _largeTouchTargets,
                  onChanged: (v) {
                    setState(() => _largeTouchTargets = v);
                    _prefs!.setBool(_keyLargeTouchTargets, v);
                  },
                ),

                const SizedBox(height: AppSizes.paddingM),
                const _SectionLabel('الحساب'),
                _LinkTile(
                  icon: Icons.lock_outline_rounded,
                  iconBg: AppColors.surfaceGrey,
                  iconColor: AppColors.textSecondary,
                  label: 'الخصوصية والأمان',
                  onTap: () => AppSnackBar.showInfo(context, 'قريباً'),
                ),
                _LinkTile(
                  icon: Icons.description_outlined,
                  iconBg: AppColors.surfaceGrey,
                  iconColor: AppColors.textSecondary,
                  label: 'الشروط والأحكام',
                  onTap: () => AppSnackBar.showInfo(context, 'قريباً'),
                ),
                _LinkTile(
                  icon: Icons.info_outline_rounded,
                  iconBg: AppColors.info.withOpacity(0.12),
                  iconColor: AppColors.info,
                  label: 'عن التطبيق',
                  trailing: 'v${AppConstantsVersion.version}',
                  onTap: () {},
                ),
              ],
            ),
    );
  }
}

/// نسخة التطبيق - مطابقة لـ pubspec.yaml
class AppConstantsVersion {
  static const String version = '1.0.0';
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingL,
        AppSizes.paddingM,
        AppSizes.paddingL,
        AppSizes.paddingS,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool iconOnDark;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.iconOnDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _RoundIcon(icon: icon, bg: iconBg, color: iconColor),
      title: Text(label, style: AppTextStyles.bodyLarge),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _RoundIcon(icon: icon, bg: iconBg, color: iconColor),
      title: Text(label, style: AppTextStyles.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[
            Text(trailing!, style: AppTextStyles.labelMedium),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;

  const _RoundIcon({required this.icon, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
