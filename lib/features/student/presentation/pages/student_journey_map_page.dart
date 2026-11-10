import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';
import '../../../../shared/widgets/student_page_skeletons.dart';

/// Journey / progress map — Figma-inspired adventure map chrome, real profile data only.
class StudentJourneyMapPage extends StatelessWidget {
  const StudentJourneyMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentBloc, StudentState>(
      buildWhen: (p, c) =>
          p.profile != c.profile || p.profileStatus != c.profileStatus,
      builder: (context, state) {
        if (state.profileStatus == SectionStatus.loading ||
            state.profileStatus == SectionStatus.initial) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('خريطتي'),
              leading: const AppBackButton.appBar(),
            ),
            body: const StudentHomeBodySkeleton(),
          );
        }
        if (state.profileStatus == SectionStatus.error) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('خريطتي'),
              leading: const AppBackButton.appBar(),
            ),
            body: AppErrorWidget(
              message: state.profileError ?? 'تعذر تحميل التقدم',
              onRetry: () {
                final auth = context.read<AuthBloc>().state;
                if (auth is AuthAuthenticated) {
                  context.read<StudentBloc>().add(
                    LoadStudentProfileEvent(auth.user.uid),
                  );
                }
              },
            ),
          );
        }

        final profile = state.profile;
        final progress = (profile?.overallProgressPercent ?? 0)
            .clamp(0, 100)
            .toDouble();
        final plan = profile?.currentPlanName.trim() ?? '';
        final streak = profile?.streakDays ?? 0;
        final completedSurahs = profile?.completedSurahs ?? 0;
        final level = profile?.level ?? 1;
        final xp = profile?.points ?? 0;
        final xpTarget = ((level) * 500).clamp(500, 5000);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    right: 16,
                    bottom: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Lvl $level',
                              style: const TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Color(0xFF3A2E00),
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Column(
                            children: [
                              Text(
                                'خريطة المغامرة 🏰',
                                style: TextStyle(
                                  fontFamily: 'NotoNaskhArabic',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'رحلتك في الحفظ',
                                style: TextStyle(
                                  fontFamily: 'NotoNaskhArabic',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const AppBackButton(color: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'المستوى ${level + 1}',
                            style: const TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'XP $xp / $xpTarget',
                            style: const TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (xp / xpTarget).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _MapNode(
                      title: 'سور مكتملة',
                      subtitle: '$completedSurahs سورة',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF43A047),
                      badge: 'مكتمل',
                    ),
                    _MapConnector(active: true),
                    _MapNode(
                      title: plan.isNotEmpty ? plan : 'السورة الحالية',
                      subtitle: '${progress.toInt()}% · الآن',
                      icon: Icons.mosque_rounded,
                      color: AppColors.primary,
                      badge: 'الآن',
                      glow: true,
                      onTap: () => context.push(AppRoutes.studentMushaf),
                    ),
                    _MapConnector(active: false),
                    _MapNode(
                      title: 'سلسلة الأيام',
                      subtitle: '$streak يوم متواصل',
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.secondary,
                      badge: 'ستريك',
                      onTap: () => context.push(AppRoutes.studentStreak),
                    ),
                    _MapConnector(active: false),
                    _MapNode(
                      title: 'المراجعة',
                      subtitle: 'جدول المراجعة',
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFFFB300),
                      badge: 'مراجعة',
                      onTap: () =>
                          context.push(AppRoutes.studentReviewSchedule),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.push(AppRoutes.studentProgressReport),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'تقريري الشهري',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapConnector extends StatelessWidget {
  final bool active;
  const _MapConnector({required this.active});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 3,
        height: 28,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badge;
  final bool glow;
  final VoidCallback? onTap;

  const _MapNode({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badge,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: glow ? AppColors.primaryDark : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: glow ? AppColors.primaryDark : AppColors.border,
            ),
          ),
          child: Text(
            '$badge · $title',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: glow ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: glow ? 88 : 72,
              height: glow ? 88 : 72,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: glow ? 0.45 : 0.25),
                    blurRadius: glow ? 18 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: glow ? 30 : 26),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.split('·').first.trim(),
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: glow ? 10 : 9,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
