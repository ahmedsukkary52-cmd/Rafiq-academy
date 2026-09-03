import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_preferences_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/confirm_logout.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/pages/notification_page.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_loading_skeletons.dart';

class SupervisorAccountTab extends StatefulWidget {
  const SupervisorAccountTab({super.key});

  @override
  State<SupervisorAccountTab> createState() => _SupervisorAccountTabState();
}

class _SupervisorAccountTabState extends State<SupervisorAccountTab> {
  bool _loadingStats = true;
  int _studentCount = 0;
  int _teacherCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    for (final h in halaqat) {
      final result = await sl<GetHalaqaStudentsUseCase>()(
        HalaqaStudentsParams(h.id),
      );
      if (!mounted) return;
      result.fold((_) {}, (list) => byHalaqa[h.id] = list);
    }

    final roster = SupervisorRoster.mergeSummaries(
      halaqat: halaqat,
      byHalaqaId: byHalaqa,
    );
    final teachers = <String>{
      for (final h in halaqat)
        if (h.teacherId.trim().isNotEmpty) h.teacherId.trim(),
    };

    if (!mounted) return;
    setState(() {
      _studentCount = roster.length;
      _teacherCount = teachers.length;
      _loadingStats = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'المشرف';
    final email = user?.email?.trim() ?? '';

    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) => p.halaqat != c.halaqat,
      listener: (_, __) => _loadStats(),
      child: Directionality(
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
                        child: SizedBox(height: 300),
                      ),
                    ),
                    Column(
                      children: [
                        _ProfileHeader(
                          name: name,
                          email: email,
                          imageUrl: user?.profileImageUrl,
                        ),
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                            child: BlocBuilder<SupervisorBloc, SupervisorState>(
                              buildWhen: (p, c) =>
                                  p.halaqat != c.halaqat ||
                                  p.halaqatStatus != c.halaqatStatus,
                              builder: (context, state) {
                                return Column(
                                  children: [
                                    if (_loadingStats ||
                                        state.halaqatStatus ==
                                            SectionStatus.loading)
                                      const SupervisorStatsGridSkeleton()
                                    else
                                      _StatsCard(
                                        halaqat: state.halaqat.length,
                                        students: _studentCount,
                                        teachers: _teacherCount,
                                      ),
                                    const SizedBox(height: 12),
                                    _SettingsCard(
                                      onNotifications: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const NotificationsPage(),
                                          ),
                                        );
                                      },
                                      onLogout: () => confirmAndLogout(context),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'بواسطة Team Academy — التطوير المستمر · إصدار 2.0',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textHint,
                                        fontSize: 11,
                                      ),
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
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? imageUrl;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : 'م';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 24,
        18,
        52,
      ),
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
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.onPrimary,
                  backgroundImage: imageUrl?.trim().isNotEmpty == true
                      ? NetworkImage(imageUrl!)
                      : null,
                  child: imageUrl?.trim().isNotEmpty == true
                      ? null
                      : Text(
                          initial,
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.gradeGood,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.onPrimary, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Text(
              'مشرف عام',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'منصة Team Academy${email.isNotEmpty ? ' · $email' : ''}',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int halaqat;
  final int students;
  final int teachers;

  const _StatsCard({
    required this.halaqat,
    required this.students,
    required this.teachers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
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
      child: Row(
        children: [
          Expanded(
            child: _StatCell(value: '$halaqat', label: 'حلقة'),
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(
            child: _StatCell(value: '$students', label: 'طالب'),
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(
            child: _StatCell(value: '$teachers', label: 'معلم'),
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
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  const _SettingsCard({required this.onNotifications, required this.onLogout});

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
          const _NavRow(
            icon: Icons.language_rounded,
            iconBg: Color(0xFFFEF3C7),
            iconColor: AppColors.secondary,
            label: 'اللغة',
            trailing: 'العربية',
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
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: AppColors.textHint.withValues(alpha: 0.7),
                ),
              ],
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
