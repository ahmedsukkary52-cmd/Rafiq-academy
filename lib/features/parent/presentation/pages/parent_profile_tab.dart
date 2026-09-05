import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/confirm_logout.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/parent_household.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_state.dart';
import '../parent_destinations.dart';
import '../parent_display.dart';
import '../parent_home_nav.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_user_avatar.dart';

class ParentProfileTab extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;

  const ParentProfileTab({super.key, required this.onSwitchTab});

  static const _appVersion = '1.0.0';

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
        backgroundColor: const Color(0xFFF5FAFB),
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
                      child: SizedBox(height: 320),
                    ),
                  ),
                  Column(
                    children: [
                      _ProfileHeader(
                        name: name,
                        imageUrl: user?.profileImageUrl,
                        contact: contact.isEmpty ? null : contact,
                      ),
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                          child: BlocBuilder<ParentBloc, ParentState>(
                            buildWhen: (p, c) =>
                                p.childrenStatus != c.childrenStatus ||
                                p.childrenIds != c.childrenIds ||
                                p.childrenSnapshots != c.childrenSnapshots ||
                                p.familySummary != c.familySummary,
                            builder: (context, state) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (state.childrenStatus ==
                                          SectionStatus.initial ||
                                      state.childrenStatus ==
                                          SectionStatus.loading)
                                    const ParentAccountStatsSkeleton()
                                  else
                                    _StatsCard(state: state),
                                  const SizedBox(height: 12),
                                  _ChildrenCard(
                                    state: state,
                                    onSeeAll: () => onSwitchTab(
                                      ParentHomeNav.childrenIndex,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _SettingsCard(
                                    onNotifications: () =>
                                        ParentDestinations.notifications(
                                          context,
                                        ),
                                    onAbsenceRequests: () =>
                                        ParentDestinations.absenceRequests(
                                          context,
                                        ),
                                    onLogout: () => confirmAndLogout(context),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'بوابة أولياء الأمور — Team Academy · الإصدار $_appVersion',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textHint,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(
                                    height:
                                        MediaQuery.paddingOf(context).bottom +
                                        16,
                                  ),
                                ],
                              );
                            },
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

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? contact;

  const _ProfileHeader({
    required this.name,
    required this.imageUrl,
    required this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 24,
        18,
        52,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.onPrimary.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ParentUserAvatar(
              name: name,
              imageUrl: imageUrl,
              radius: 44,
              backgroundColor: AppColors.onPrimary,
              foregroundColor: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Text(
              'ولي الأمر',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          if (contact != null) ...[
            const SizedBox(height: 8),
            Text(
              contact!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ParentState state;

  const _StatsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final verses = state.childrenSnapshots.fold<int>(
      0,
      (sum, child) => sum + child.totalVersesMemorized,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.13),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              value: parentEasternDigits(
                '${state.familySummary.childrenCount}',
              ),
              label: 'أبناء',
            ),
          ),
          Container(width: 0.8, height: 36, color: const Color(0xFFE8EEF0)),
          Expanded(
            child: _StatCell(
              value: parentPercentLabel(
                state.familySummary.averageAttendancePercent,
              ),
              label: 'حضور',
            ),
          ),
          Container(width: 0.8, height: 36, color: const Color(0xFFE8EEF0)),
          Expanded(
            child: _StatCell(
              value: parentEasternDigits('$verses'),
              label: 'آية',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;

  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ChildrenCard extends StatelessWidget {
  final ParentState state;
  final VoidCallback onSeeAll;

  const _ChildrenCard({required this.state, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أبنائي',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    parentEasternDigits('${state.childrenIds.length}'),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (state.childrenIds.isEmpty)
            Text(
              'لا يوجد طلاب مرتبطون بهذا الحساب بعد.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in state.childrenIds)
                      SizedBox(
                        width: width,
                        child: _ChildMiniCard(
                          studentId: id,
                          snapshot: state.snapshotFor(id),
                          name: state.childDisplayName(id),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChildMiniCard extends StatelessWidget {
  final String studentId;
  final String name;
  final ParentChildSnapshot? snapshot;

  const _ChildMiniCard({
    required this.studentId,
    required this.name,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final atRisk = snapshot?.isAtRisk == true;
    final bg = atRisk ? const Color(0xFFFFE8EE) : const Color(0xFFE8F7EE);
    final accent = atRisk ? AppColors.error : AppColors.success;
    final subtitle = atRisk
        ? 'يحتاج متابعة'
        : ((snapshot?.halaqaName.trim() ?? '').isEmpty
              ? 'لم تُحدد حلقة'
              : snapshot!.halaqaName.trim());

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => ParentDestinations.childProfile(
          context,
          studentId: studentId,
          studentName: name,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            children: [
              ParentUserAvatar(
                name: name,
                imageUrl: snapshot?.profileImageUrl,
                radius: 22,
                backgroundColor: AppColors.surface,
                foregroundColor: accent,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final VoidCallback onNotifications;
  final VoidCallback onAbsenceRequests;
  final VoidCallback onLogout;

  const _SettingsCard({
    required this.onNotifications,
    required this.onAbsenceRequests,
    required this.onLogout,
  });

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
              return _ToggleRow(
                icon: Icons.dark_mode_rounded,
                iconBg: const Color(0xFFE8E8F0),
                iconColor: AppColors.textPrimary,
                label: 'الوضع الليلي',
                value: mode == ThemeMode.dark,
                onChanged: prefs.setDarkMode,
              );
            },
          ),
          const _SettingsDivider(),
          _NavRow(
            icon: Icons.notifications_rounded,
            iconBg: const Color(0xFFD6F6F8),
            iconColor: AppColors.primaryDark,
            label: 'الإشعارات',
            onTap: onNotifications,
          ),
          const _SettingsDivider(),
          _NavRow(
            icon: Icons.event_busy_outlined,
            iconBg: const Color(0xFFFFE8E0),
            iconColor: AppColors.error,
            label: 'الاستئذان',
            onTap: onAbsenceRequests,
          ),
          const _SettingsDivider(),
          _LogoutRow(onTap: onLogout),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 0.8, thickness: 0.8, color: Color(0xFFE8EEF0));
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _RoundIcon(icon: icon, bg: iconBg, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.onPrimary,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _NavRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _RoundIcon(icon: icon, bg: iconBg, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const _RoundIcon(
                icon: Icons.logout_rounded,
                bg: Color(0xFFFFE8EE),
                color: AppColors.error,
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
    );
  }
}
