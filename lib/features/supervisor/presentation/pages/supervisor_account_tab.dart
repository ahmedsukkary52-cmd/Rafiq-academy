import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/confirm_logout.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class SupervisorAccountTab extends StatelessWidget {
  const SupervisorAccountTab({super.key});

  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'المشرف';
    final email = user?.email?.trim() ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: SizedBox(height: 240),
                    ),
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          MediaQuery.paddingOf(context).top + 28,
                          18,
                          36,
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.onPrimary,
                              backgroundImage:
                                  (user?.profileImageUrl?.trim().isNotEmpty ==
                                      true)
                                  ? NetworkImage(user!.profileImageUrl!)
                                  : null,
                              child:
                                  (user?.profileImageUrl?.trim().isNotEmpty ==
                                      true)
                                  ? null
                                  : Text(
                                      name.isNotEmpty ? name[0] : 'م',
                                      style: AppTextStyles.headlineMedium
                                          .copyWith(
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                email,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.onPrimary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.onPrimary.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusFull,
                                ),
                              ),
                              child: Text(
                                'مشرف',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                          child: Column(
                            children: [
                              const _SettingsCard(),
                              const SizedBox(height: 16),
                              Text(
                                'بوابة المشرف — فريق الأكاديمية · الإصدار $_appVersion',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(
                                height:
                                    MediaQuery.paddingOf(context).bottom + 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferencesScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: prefs.themeMode,
            builder: (context, mode, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dark_mode_rounded,
                        size: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'الوضع الليلي',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: mode == ThemeMode.dark,
                      onChanged: prefs.setDarkMode,
                      activeThumbColor: AppColors.onPrimary,
                      activeTrackColor: AppColors.primary,
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 0.8, thickness: 0.8, color: AppColors.border),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => confirmAndLogout(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 17,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تسجيل الخروج',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
