import 'package:flutter/material.dart';

import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_button.dart';

/// Student settings — only preferences that actually affect the app.
/// D15: dark/light theme switching is OUT — no theme toggle here (UI-1).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appPreferences = AppPreferencesScope.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          centerTitle: true,
          leading: const AppBackButton(),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _SectionLabel('المظهر'),
            _SettingsGroup(
              children: [
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
              ],
            ),
            const SizedBox(height: 20),
            const _SectionLabel('عن التطبيق'),
            _SettingsGroup(
              children: const [
                _LinkTile(
                  icon: Icons.info_outline_rounded,
                  iconBg: AppColors.surfaceGrey,
                  iconColor: AppColors.textSecondary,
                  label: 'الإصدار',
                  trailing: 'v${AppConstantsVersion.version}',
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(children: children),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: _RoundIcon(icon: icon, bg: iconBg, color: iconColor),
      title: Text(
        label,
        textAlign: TextAlign.right,
        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: trailing == null
          ? const Icon(Icons.chevron_left_rounded, color: AppColors.textHint)
          : Text(
              trailing!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
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
