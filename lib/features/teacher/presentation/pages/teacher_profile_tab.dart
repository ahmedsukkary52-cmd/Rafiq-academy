import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class TeacherProfileTab extends StatelessWidget {
  const TeacherProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header التيل ────────────────────────────────────
            Container(
              color: AppColors.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: AppSizes.paddingXL,
              ),
              child: Column(
                children: [
                  // Avatar مع أيقونة التعديل
                  Stack(
                    children: [
                      UserAvatar(
                        name: user?.name ?? 'م',
                        size: AppSizes.avatarXL,
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // الاسم والوصف
                  Text(
                    'أ. ${user?.name ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'معلم تحفيظ',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Team Academy · خبرة ٨ سنوات',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            // ── إحصائيات ────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.all(AppSizes.paddingM),
              child: Row(
                children: [
                  _StatCard(value: '%٩١', label: 'رضا الأهالي'),
                  SizedBox(width: 12),
                  _StatCard(value: '٤٢', label: 'طالب'),
                  SizedBox(width: 12),
                  _StatCard(value: '٣', label: 'حلقات'),
                ],
              ),
            ),

            // ── المساعد الذكي ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                ),
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'توصيات هذا الأسبوع',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppColors.primary,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'مساعد ذكي',
                                style: TextStyle(
                                  fontFamily: 'NotoNaskhArabic',
                                  fontSize: 11,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'بناءً على بيانات حلقاتك',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        _DarkChip(label: 'متابعة ٢ طلاب في خطر'),
                        _DarkChip(label: 'رفع ٥ تقييمات معلقة'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── الإعدادات ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
              ),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingToggle(
                      icon: Icons.dark_mode_outlined,
                      label: 'الوضع الليلي',
                      color: const Color(0xFF5C6BC0),
                      value: false,
                      onChanged: (_) {},
                    ),
                    const Divider(height: 1),
                    _SettingToggle(
                      icon: Icons.notifications_outlined,
                      label: 'الإشعارات',
                      color: AppColors.primary,
                      value: true,
                      onChanged: (_) {},
                    ),
                    const Divider(height: 1),
                    const _SettingArrow(
                      icon: Icons.language_outlined,
                      label: 'اللغة',
                      subtitle: 'العربية',
                      color: AppColors.secondary,
                    ),
                    const Divider(height: 1),
                    const _SettingArrow(
                      icon: Icons.security_outlined,
                      label: 'الخصوصية',
                      color: AppColors.success,
                    ),
                    const Divider(height: 1),
                    const _SettingArrow(
                      icon: Icons.help_outline_rounded,
                      label: 'المساعدة والدعم',
                      color: Color(0xFF9C27B0),
                    ),
                    const Divider(height: 1),
                    // تسجيل الخروج
                    _LogoutTile(
                      onTap: () {
                        context.read<AuthBloc>().add(const LogoutEvent());
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // الإصدار
            const Text(
              'Team Academy · الإصدار ١.٢.٠١',
              style: AppTextStyles.labelSmall,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  final String label;

  const _DarkChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool value;
  final void Function(bool) onChanged;

  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: 4,
      ),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
          const Spacer(),
          Text(label, style: AppTextStyles.titleMedium),
          const SizedBox(width: 12),
          _SettingIconBox(icon: icon, color: color),
        ],
      ),
    );
  }
}

class _SettingArrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;

  const _SettingArrow({
    required this.icon,
    required this.label,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: 12,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textHint,
            size: 20,
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 4),
            Text(subtitle!, style: AppTextStyles.bodyMedium),
          ],
          const Spacer(),
          Text(label, style: AppTextStyles.titleMedium),
          const SizedBox(width: 12),
          _SettingIconBox(icon: icon, color: color),
        ],
      ),
    );
  }
}

class _SettingIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingIconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: 14,
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            const Spacer(),
            Text(
              'تسجيل الخروج',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
