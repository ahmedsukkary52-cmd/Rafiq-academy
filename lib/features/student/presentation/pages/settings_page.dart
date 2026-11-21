import 'package:flutter/material.dart';

import '../../../../core/constants/academy_branding.dart';
import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_button.dart';

/// Student settings — compact hero + gradient preference cards (no hairline rows).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appPreferences = AppPreferencesScope.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  18,
                ),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const AppBackButton(
                          color: Colors.white,
                          circular: true,
                        ),
                        Expanded(
                          child: Text(
                            'الإعدادات',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'خط أوضح · تجربة أنسب لك',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SoftSliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'المظهر',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<AppFontSize>(
                    valueListenable: appPreferences.fontSize,
                    builder: (context, size, _) {
                      return _GradientSettingCard(
                        icon: Icons.text_fields_rounded,
                        title: 'حجم الخط',
                        subtitle: 'اضغط للتبديل بين الأحجام',
                        trailing: size.label,
                        onTap: () {
                          const values = AppFontSize.values;
                          final next = values[(size.index + 1) % values.length];
                          appPreferences.setFontSize(next);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'عن التطبيق',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _GradientSettingCard(
                    icon: Icons.info_outline_rounded,
                    title: 'الإصدار',
                    subtitle: AcademyBranding.displayName,
                    trailing: 'v${AppConstantsVersion.version}',
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoftSliverPadding extends StatelessWidget {
  final EdgeInsets padding;
  final Widget sliver;

  const SoftSliverPadding({
    super.key,
    required this.padding,
    required this.sliver,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(padding: padding, sliver: sliver);
  }
}

class AppConstantsVersion {
  static const String version = '1.0.0';
}

class _GradientSettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  const _GradientSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.primaryLight.withValues(alpha: 0.55),
                AppColors.surface,
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trailing!,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
