import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/achievement_entity.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

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
        body: SafeArea(
          child: BlocBuilder<StudentBloc, StudentState>(
            buildWhen: (prev, curr) =>
                prev.achievementsStatus != curr.achievementsStatus ||
                prev.achievements != curr.achievements ||
                prev.achievementsError != curr.achievementsError ||
                prev.profile != curr.profile,
            builder: (context, state) {
              if (state.achievementsStatus == SectionStatus.initial ||
                  (state.achievementsStatus == SectionStatus.loading &&
                      state.achievements.isEmpty)) {
                return const AppLoadingWidget();
              }

              if (state.achievementsStatus == SectionStatus.error &&
                  state.achievements.isEmpty) {
                return AppErrorWidget(
                  message: state.achievementsError ?? 'تعذر تحميل الإنجازات',
                  onRetry: _retryAchievements,
                );
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Header(state: state)),
                  if (state.achievements.isEmpty)
                    const _EmptyAchievements()
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'إنجازاتي',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SliverList.separated(
                      itemCount: state.achievements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final achievement = state.achievements[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            index == 0 ? 22 : 0,
                            24,
                            index == state.achievements.length - 1 ? 28 : 0,
                          ),
                          child: _AchievementRow(achievement: achievement),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
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
            const Text(
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
    final memorizationAccuracy = (profile?.overallProgressPercent ?? 0)
        .clamp(0, 100)
        .round();

    return Container(
      color: AppColors.dark,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                if (Navigator.canPop(context))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: _HeaderButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => Navigator.maybePop(context),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Text(
                      '🏆 الإنجازات',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 16),
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.studentBadges),
                      child: const Text('الشارات'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF2F3B4B),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
            child: Row(
              children: [
                _StatTile(
                  value: '$completed',
                  label: 'إنجاز مكتمل',
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  value: '$stars',
                  label: 'نجمة',
                  color: const Color(0xFF24C6CF),
                ),
                const SizedBox(width: 12),
                _StatTile(
                  value: '$memorizationAccuracy%',
                  label: 'نسبة التقدم',
                  color: const Color(0xFF34D18B),
                ),
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
        height: 108,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white54),
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
      height: 132,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7FF),
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: Text(
              _iconFor(achievement.type),
              style: const TextStyle(fontSize: 30),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text('بواسطة $issuer', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _typeLabel(achievement.type),
            style: AppTextStyles.titleMedium.copyWith(
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
  };

  static String _typeLabel(AchievementType type) => switch (type) {
    AchievementType.star => 'نجمة',
    AchievementType.badge => 'شارة',
    AchievementType.certificate => 'شهادة',
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
