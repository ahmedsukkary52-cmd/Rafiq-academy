import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../awards/domain/entities/award_entities.dart';
import '../../domain/student_awards_stats.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

/// Student center-tab Awards — receive/view only. No grant controls.
class StudentBadgesPage extends StatefulWidget {
  const StudentBadgesPage({super.key});

  @override
  State<StudentBadgesPage> createState() => _StudentBadgesPageState();
}

class _StudentBadgesPageState extends State<StudentBadgesPage> {
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<StudentBloc>().add(LoadAchievementsEvent(auth.user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocBuilder<StudentBloc, StudentState>(
            buildWhen: (previous, current) =>
            previous.achievements != current.achievements ||
                previous.achievementsStatus != current.achievementsStatus ||
                previous.achievementsError != current.achievementsError,
            builder: (context, state) {
              if (state.achievementsStatus == SectionStatus.initial ||
                  (state.achievementsStatus == SectionStatus.loading &&
                      state.achievements.isEmpty)) {
                return const AppLoadingWidget();
              }

              if (state.achievementsStatus == SectionStatus.error &&
                  state.achievements.isEmpty) {
                return AppErrorWidget(
                  message:
                  state.achievementsError ?? 'تعذر تحميل الجوائز',
                  onRetry: _reload,
                );
              }

              final stats = computeStudentAwardsStats(state.achievements);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        'الجوائز',
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _StudentAwardsStatsRow(stats: stats),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'أنواع الجوائز',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.05,
                            children: AwardType.values
                                .map(
                                  (type) =>
                                  _StudentAwardTypeCard(
                                    type: type,
                                    earned: stats.earnedTypes.contains(type),
                                  ),
                            )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StudentAwardsStatsRow extends StatelessWidget {
  final StudentAwardsStats stats;

  const _StudentAwardsStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          value: '${stats.totalCount}',
          label: 'إجمالي الجوائز',
          icon: Icons.emoji_events_outlined,
          iconBg: AppColors.secondaryBg,
          iconColor: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${stats.thisMonthCount}',
          label: 'هذا الشهر',
          icon: Icons.calendar_month_outlined,
          iconBg: AppColors.primaryLight,
          iconColor: AppColors.primaryDark,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${stats.typesEarnedCount}',
          label: 'أنواع مكتسبة',
          icon: Icons.workspace_premium_outlined,
          iconBg: AppColors.successBg,
          iconColor: AppColors.success,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAwardTypeCard extends StatelessWidget {
  final AwardType type;
  final bool earned;

  const _StudentAwardTypeCard({
    required this.type,
    required this.earned,
  });

  Color get _color =>
      switch (type) {
        AwardType.completionBadge => AppColors.awardCompletion,
        AwardType.performanceStars => AppColors.awardPerformance,
        AwardType.perfectAttendance => AppColors.awardAttendance,
        AwardType.studentOfWeek => AppColors.awardWeekly,
      };

  IconData get _icon =>
      switch (type) {
        AwardType.completionBadge => Icons.verified_rounded,
        AwardType.performanceStars => Icons.star_rounded,
        AwardType.perfectAttendance => Icons.person_rounded,
        AwardType.studentOfWeek => Icons.emoji_events_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1 : 0.48,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: earned
              ? Border.all(color: _color.withValues(alpha: 0.35))
              : null,
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
              ),
              child: Icon(_icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              type.title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              type.description,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              earned ? 'مكتسبة' : 'لم تُمنح بعد',
              style: AppTextStyles.labelSmall.copyWith(
                color: earned ? _color : AppColors.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
