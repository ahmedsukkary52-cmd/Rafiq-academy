import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/confirm_logout.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_state.dart';
import '../parent_destinations.dart';
import '../parent_home_nav.dart';
import '../widgets/parent_user_avatar.dart';

class ParentProfileTab extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;

  const ParentProfileTab({super.key, required this.onSwitchTab});

  static const _appVersion = '1.0.0';

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('قريباً')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'ولي الأمر';
    final phone = user?.phone.trim() ?? '';
    final email = user?.email?.trim() ?? '';
    final contact = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
    ].join(' — ');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Column(
                      children: [
                        ParentUserAvatar(
                          name: name,
                          imageUrl: user?.profileImageUrl,
                          radius: 40,
                          backgroundColor: AppColors.onPrimary,
                          foregroundColor: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.onPrimaryOverlay,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                          ),
                          child: Text(
                            'ولي الأمر',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                        if (contact.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            contact,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.onPrimaryMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: BlocBuilder<ParentBloc, ParentState>(
                      buildWhen: (p, c) =>
                          p.childrenIds != c.childrenIds ||
                          p.childrenStatus != c.childrenStatus,
                      builder: (context, state) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusL,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            state.childrenStatus == SectionStatus.loaded
                                ? '${state.childrenIds.length} أبناء مرتبطون'
                                : 'عدد الأبناء يظهر بعد التحميل',
                            style: AppTextStyles.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  Text('أبنائي', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 8),
                  BlocBuilder<ParentBloc, ParentState>(
                    buildWhen: (p, c) =>
                        p.childrenIds != c.childrenIds ||
                        p.childrenSnapshots != c.childrenSnapshots,
                    builder: (context, state) {
                      if (state.childrenIds.isEmpty) {
                        return Text(
                          'لا يوجد طلاب مرتبطون.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textHint,
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in state.childrenIds)
                            ActionChip(
                              avatar: const Icon(Icons.person_outline, size: 18),
                              label: Text(state.childDisplayName(id)),
                              onPressed: () => ParentDestinations.childProfile(
                                context,
                                studentId: id,
                                studentName: state.childDisplayName(id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('اختصارات', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 8),
                  _LinkTile(
                    icon: Icons.assessment_outlined,
                    label: 'التقارير',
                    onTap: () => ParentDestinations.reports(context),
                  ),
                  _LinkTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'الجدول',
                    onTap: () => ParentDestinations.schedule(context),
                  ),
                  _LinkTile(
                    icon: Icons.notifications_outlined,
                    label: 'الإشعارات',
                    onTap: () => ParentDestinations.notifications(context),
                  ),
                  _LinkTile(
                    icon: Icons.emoji_events_outlined,
                    label: 'الإنجازات',
                    onTap: () => ParentDestinations.achievements(context),
                  ),
                  _LinkTile(
                    icon: Icons.storefront_outlined,
                    label: 'الاشتراكات',
                    onTap: () => onSwitchTab(ParentHomeNav.storeIndex),
                  ),
                  const SizedBox(height: 16),
                  Text('الإعدادات', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable:
                        AppPreferencesScope.of(context).themeMode,
                    builder: (context, mode, _) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('الوضع الليلي'),
                        value: mode == ThemeMode.dark,
                        onChanged: (v) => AppPreferencesScope.of(context)
                            .setDarkMode(v),
                      );
                    },
                  ),
                  _LinkTile(
                    icon: Icons.notifications_outlined,
                    label: 'تفضيلات الإشعارات',
                    onTap: () => _comingSoon(context),
                  ),
                  _LinkTile(
                    icon: Icons.language_rounded,
                    label: 'اللغة',
                    trailing: 'العربية',
                    onTap: () => _comingSoon(context),
                  ),
                  _LinkTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'الخصوصية',
                    onTap: () => _comingSoon(context),
                  ),
                  _LinkTile(
                    icon: Icons.help_outline_rounded,
                    label: 'الدعم والمساعدة',
                    onTap: () => _comingSoon(context),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: Text(
                      'تسجيل الخروج',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    onTap: () => confirmAndLogout(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بوابة أولياء الأمور — الإصدار $_appVersion',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHint,
                    ),
                    textAlign: TextAlign.center,
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

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: trailing != null
          ? Text(
              trailing!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            )
          : const Icon(Icons.chevron_left_rounded),
      onTap: onTap,
    );
  }
}
