import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_state.dart';
import '../widgets/teacher_home_figma_cards.dart';

/// Teacher Profile & Settings — Figma `1:2035` Phase 1 UI.
///
/// Real data only (Auth + TeacherBloc halaqat + AppPreferences).
/// No AI assistant. Unsupported Figma fields are marked Coming Soon.
class TeacherProfileTab extends StatelessWidget {
  const TeacherProfileTab({super.key});

  static const _appVersion = '1.0.0';

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('قريباً')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context
        .watch<AuthBloc>()
        .state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final displayName = user?.name
        .trim()
        .isNotEmpty == true
        ? 'أ. ${user!.name.trim()}'
        : 'المعلم';
    final phone = user?.phone.trim() ?? '';
    final email = user?.email?.trim() ?? '';
    final contact = phone.isNotEmpty
        ? phone
        : (email.isNotEmpty ? email : null);

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
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 320,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _ProfileHeader(
                        name: displayName,
                        imageUrl: user?.profileImageUrl,
                        contact: contact,
                        onEditTap: () => _comingSoon(context),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: BlocBuilder<TeacherBloc, TeacherState>(
                                buildWhen: (p, c) =>
                                p.halaqatStatus != c.halaqatStatus ||
                                    p.halaqat != c.halaqat ||
                                    p.halaqatError != c.halaqatError,
                                builder: (context, state) {
                                  if (state.halaqatStatus ==
                                      SectionStatus.initial ||
                                      state.halaqatStatus ==
                                          SectionStatus.loading) {
                                    return const _StatsSkeleton();
                                  }
                                  if (state.halaqatStatus ==
                                      SectionStatus.error) {
                                    return _StatsError(
                                      message: state.halaqatError ??
                                          'تعذر تحميل الإحصاءات',
                                    );
                                  }
                                  final halaqaCount = state.halaqat.length;
                                  final studentCount = state.halaqat
                                      .expand((h) => h.studentIds)
                                      .toSet()
                                      .length;
                                  return _StatsCard(
                                    halaqaCount: halaqaCount,
                                    studentCount: studentCount,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                              child: Column(
                                children: [
                                  _SettingsCard(
                                    onExcusesTap: () =>
                                        context.push(
                                          AppRoutes.teacherExcuses,
                                        ),
                                    onLogoutTap: () {
                                      context.read<AuthBloc>().add(
                                        const LogoutEvent(),
                                      );
                                    },
                                    onComingSoon: () => _comingSoon(context),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'أكاديمية رفيق · الإصدار $_appVersion',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textHint,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(
                                    height:
                                    MediaQuery
                                        .paddingOf(context)
                                        .bottom +
                                        16,
                                  ),
                                ],
                              ),
                            ),
                          ],
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

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _HeaderAvatar({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? 'م' : trimmed[0];
    return CircleAvatar(
      radius: 44,
      backgroundColor: AppColors.onPrimary,
      backgroundImage:
      imageUrl != null && imageUrl!.trim().isNotEmpty
          ? NetworkImage(imageUrl!)
          : null,
      child: imageUrl == null || imageUrl!.trim().isEmpty
          ? Text(
        initial,
        style: AppTextStyles.displayLarge.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 34,
        ),
      )
          : null,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? contact;
  final VoidCallback onEditTap;

  const _ProfileHeader({
    required this.name,
    required this.imageUrl,
    required this.contact,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery
        .paddingOf(context)
        .top;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, top + 24, 18, 52),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
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
                child: _HeaderAvatar(name: name, imageUrl: imageUrl),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.secondary,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.onPrimary, width: 1.5),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEditTap,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
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
              'معلم تحفيظ',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contact ?? 'سنوات الخبرة · قريباً',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          if (contact != null) ...[
            const SizedBox(height: 4),
            Text(
              'سنوات الخبرة · قريباً',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int halaqaCount;
  final int studentCount;

  const _StatsCard({
    required this.halaqaCount,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
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
              value: teacherHomeEasternDigits('$halaqaCount'),
              label: 'حلقات',
            ),
          ),
          Container(width: 0.8, height: 36, color: const Color(0xFFE8EEF0)),
          Expanded(
            child: _StatCell(
              value: teacherHomeEasternDigits('$studentCount'),
              label: 'طالب',
            ),
          ),
          Container(width: 0.8, height: 36, color: const Color(0xFFE8EEF0)),
          const Expanded(
            child: _StatCell(
              value: '—',
              label: 'رضا الأهالي',
              valueHint: true,
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
  final bool valueHint;

  const _StatCell({
    required this.value,
    required this.label,
    this.valueHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(
            color: valueHint ? AppColors.textHint : AppColors.primaryDark,
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
        if (valueHint)
          Text(
            'قريباً',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textHint,
              fontSize: 9,
            ),
          ),
      ],
    );
  }
}

class _StatsSkeleton extends StatefulWidget {
  const _StatsSkeleton();

  @override
  State<_StatsSkeleton> createState() => _StatsSkeletonState();
}

class _StatsSkeletonState extends State<_StatsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bone = AppColors.border.withValues(alpha: _pulse.value);
        Widget bar(double w, double h) =>
            Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: bone,
                borderRadius: BorderRadius.circular(6),
              ),
            );
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 3; i++)
                Column(
                  children: [
                    bar(28, 16),
                    const SizedBox(height: 8),
                    bar(40, 10),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsError extends StatelessWidget {
  final String message;

  const _StatsError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Settings ──────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final VoidCallback onExcusesTap;
  final VoidCallback onLogoutTap;
  final VoidCallback onComingSoon;

  const _SettingsCard({
    required this.onExcusesTap,
    required this.onLogoutTap,
    required this.onComingSoon,
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
          _ComingSoonRow(
            icon: Icons.notifications_rounded,
            iconBg: const Color(0xFFD6F6F8),
            iconColor: AppColors.primaryDark,
            label: 'الإشعارات',
            onTap: onComingSoon,
          ),
          const _SettingsDivider(),
          const _NavRow(
            icon: Icons.language_rounded,
            iconBg: Color(0xFFFEF3C7),
            iconColor: AppColors.secondary,
            label: 'اللغة',
            trailing: 'العربية',
            onTap: null,
          ),
          const _SettingsDivider(),
          _ComingSoonRow(
            icon: Icons.verified_user_outlined,
            iconBg: const Color(0xFFD1F5E5),
            iconColor: AppColors.success,
            label: 'الخصوصية',
            onTap: onComingSoon,
          ),
          const _SettingsDivider(),
          _ComingSoonRow(
            icon: Icons.help_outline_rounded,
            iconBg: const Color(0xFFF0EAFF),
            iconColor: AppColors.awardWeekly,
            label: 'المساعدة والدعم',
            onTap: onComingSoon,
          ),
          const _SettingsDivider(),
          _NavRow(
            icon: Icons.event_busy_outlined,
            iconBg: AppColors.primaryLight,
            iconColor: AppColors.primaryDark,
            label: 'طلبات الاعتذار',
            onTap: onExcusesTap,
          ),
          const _SettingsDivider(),
          _LogoutRow(onTap: onLogoutTap),
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

  const _RoundIcon({
    required this.icon,
    required this.bg,
    required this.color,
  });

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
              textAlign: TextAlign.right,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
  final String? trailing;
  final VoidCallback? onTap;

  const _NavRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.trailing,
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
                  textAlign: TextAlign.right,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (onTap != null || trailing != null)
                const Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: AppColors.textHint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ComingSoonRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
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
                  textAlign: TextAlign.right,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                'قريباً',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: AppColors.textHint,
              ),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEAEA),
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
                  textAlign: TextAlign.right,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
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
