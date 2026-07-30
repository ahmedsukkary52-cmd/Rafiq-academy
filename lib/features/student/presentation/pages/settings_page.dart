import 'package:flutter/material.dart';

import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';

/// Student settings — only preferences that actually affect the app.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appPreferences = AppPreferencesScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingM),
        children: [
          const _SectionLabel('المظهر'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appPreferences.themeMode,
            builder: (context, mode, _) {
              return _ToggleTile(
                icon: Icons.dark_mode_rounded,
                iconBg: AppColors.dark,
                iconColor: Colors.white,
                label: 'الوضع الليلي',
                value: mode == ThemeMode.dark,
                onChanged: (v) => appPreferences.setDarkMode(v),
              );
            },
          ),
          const _LinkTile(
            icon: Icons.language_rounded,
            iconBg: AppColors.primaryLight,
            iconColor: AppColors.primary,
            label: 'اللغة',
            trailing: 'العربية',
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
          const _SectionLabel('قريباً'),
          const _ComingSoonTile(
            icon: Icons.notifications_rounded,
            iconBg: AppColors.secondaryBg,
            iconColor: AppColors.secondary,
            label: 'تفضيلات الإشعارات',
          ),
          const _ComingSoonTile(
            icon: Icons.lock_outline_rounded,
            iconBg: AppColors.surfaceGrey,
            iconColor: AppColors.textSecondary,
            label: 'الخصوصية والأمان',
          ),
          const _ComingSoonTile(
            icon: Icons.description_outlined,
            iconBg: AppColors.surfaceGrey,
            iconColor: AppColors.textSecondary,
            label: 'الشروط والأحكام',
          ),

          const SizedBox(height: AppSizes.paddingM),
          const _SectionLabel('عن التطبيق'),
          const _LinkTile(
            icon: Icons.info_outline_rounded,
            iconBg: AppColors.surfaceGrey,
            iconColor: AppColors.textSecondary,
            label: 'الإصدار',
            trailing: 'v${AppConstantsVersion.version}',
          ),
        ],
      ),
    );
  }
}

/// App version — keep in sync with pubspec.yaml
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
  final VoidCallback? onTap;

  const _LinkTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _RoundIcon(icon: icon, bg: iconBg, color: iconColor),
      title: Text(label, style: AppTextStyles.bodyLarge),
      trailing: trailing == null
          ? null
          : Text(trailing!, style: AppTextStyles.labelMedium),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;

  const _ComingSoonTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _RoundIcon(icon: icon, bg: iconBg, color: iconColor),
      title: Text(label, style: AppTextStyles.bodyLarge),
      trailing: Text(
        'Coming Soon',
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textHint),
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
