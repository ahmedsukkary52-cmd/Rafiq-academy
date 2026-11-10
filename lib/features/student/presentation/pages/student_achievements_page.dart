import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../awards/domain/entities/award_entities.dart';
import '../../domain/entities/achievement_entity.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';
import '../widgets/student_loading_skeletons.dart';

/// إنجازات الطالب — مصدر واحد: Firestore عبر StudentBloc.
class StudentAchievementsPage extends StatefulWidget {
  const StudentAchievementsPage({super.key});

  @override
  State<StudentAchievementsPage> createState() =>
      _StudentAchievementsPageState();
}

class _StudentAchievementsPageState extends State<StudentAchievementsPage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<StudentBloc>()
      ..add(LoadStudentProfileEvent(auth.user.uid))
      ..add(LoadAchievementsEvent(auth.user.uid));
  }

  void _retryAchievements() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<StudentBloc>().add(LoadAchievementsEvent(auth.user.uid));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<StudentBloc, StudentState>(
          buildWhen: (prev, curr) =>
              prev.achievementsStatus != curr.achievementsStatus ||
              prev.achievements != curr.achievements ||
              prev.achievementsError != curr.achievementsError ||
              prev.profile != curr.profile,
          builder: (context, state) {
            if (state.achievementsStatus == SectionStatus.initial ||
                (state.achievementsStatus == SectionStatus.loading &&
                    state.achievements.isEmpty)) {
              return const StudentListPageSkeleton();
            }

            if (state.achievementsStatus == SectionStatus.error &&
                state.achievements.isEmpty) {
              return SafeArea(
                child: AppErrorWidget(
                  message: state.achievementsError ?? 'تعذر تحميل الإنجازات',
                  onRetry: _retryAchievements,
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(state: state)),
                if (state.achievements.isEmpty)
                  const _EmptyAchievements()
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'إنجازاتي',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: state.achievements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _AchievementRow(
                          achievement: state.achievements[index],
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyAchievements extends StatelessWidget {
  const _EmptyAchievements();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد إنجازات بعد',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر هنا الإنجازات التي يمنحها المعلمون أو المشرفون.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final StudentState state;

  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final completed = state.achievements.length;
    final stars = profile?.totalStars ?? 0;
    final memorizationProgress = (profile?.overallProgressPercent ?? 0)
        .clamp(0, 100)
        .round();

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  _HeaderButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => Navigator.maybePop(context),
                  )
                else
                  const SizedBox(width: 48),
                const Spacer(),
                Text(
                  '🏆 الإنجازات',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(AppRoutes.studentBadges),
                  child: const Text(
                    'الشارات',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatTile(
                  value: '$completed',
                  label: 'إنجاز مكتمل',
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                _StatTile(
                  value: '$stars',
                  label: 'نجمة',
                  color: const Color(0xFF24C6CF),
                ),
                if (AppCapabilities.memorizationProgressAvailable) ...[
                  const SizedBox(width: 10),
                  _StatTile(
                    value: '$memorizationProgress%',
                    label: 'نسبة التقدم',
                    color: const Color(0xFF34D18B),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  final AchievementEntity achievement;

  const _AchievementRow({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final title = achievement.title.trim().isEmpty
        ? 'إنجاز'
        : achievement.title.trim();
    final issuer = achievement.issuedBy.trim().isEmpty
        ? 'غير متوفر'
        : achievement.issuedBy.trim();
    final dateLabel = _formatDate(achievement.date);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7FF),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              _iconFor(achievement.type),
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'بواسطة $issuer',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _typeLabel(achievement.type),
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _iconFor(AchievementType type) => switch (type) {
    AchievementType.star => '⭐',
    AchievementType.badge => '🎖️',
    AchievementType.certificate => '📜',
    AchievementType.completionBadge || AchievementType.completion => '✅',
    AchievementType.performanceStars || AchievementType.performance => '🌟',
    AchievementType.perfectAttendance || AchievementType.attendance => '📅',
    AchievementType.studentOfWeek || AchievementType.achievement => '🏆',
    AchievementType.custom => '🎖️',
  };

  static String _typeLabel(AchievementType type) =>
      type.awardType?.formCategory.title ??
      switch (type) {
        AchievementType.star => 'نجمة',
        AchievementType.badge => 'شارة',
        AchievementType.certificate => 'شهادة',
        _ => type.awardType?.title ?? 'جائزة',
      };

  static String _formatDate(DateTime date) => formatDateDmy(date);
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
