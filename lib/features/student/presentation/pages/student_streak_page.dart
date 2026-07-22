import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

class StudentStreakPage extends StatefulWidget {
  const StudentStreakPage({super.key});

  @override
  State<StudentStreakPage> createState() => _StudentStreakPageState();
}

class _StudentStreakPageState extends State<StudentStreakPage> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<StudentBloc>().add(LoadStudentProfileEvent(auth.user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            final streak = state.profile?.streakDays ?? 0;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _StreakHero(streak: streak)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  sliver: SliverToBoxAdapter(child: _WeekCard(streak: streak)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'محطات الإنجاز 🎯',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                SliverList.separated(
                  itemCount: _milestones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final milestone = _milestones[index];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        index == _milestones.length - 1 ? 36 : 0,
                      ),
                      child: _MilestoneCard(
                        milestone: milestone,
                        streak: streak,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _milestones = [
    _StreakMilestone(days: 7, title: 'أسبوع كامل', icon: '🏅'),
    _StreakMilestone(days: 14, title: 'أسبوعان متواصلان', icon: '🥇'),
    _StreakMilestone(days: 30, title: 'شهر كامل', icon: '🏆'),
    _StreakMilestone(days: 100, title: 'البطولة الذهبية', icon: '💎'),
  ];
}

class _StreakHero extends StatelessWidget {
  final int streak;

  const _StreakHero({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 382,
      decoration: const BoxDecoration(color: Color(0xFFE9292F)),
      child: Stack(
        children: [
          Positioned(
            top: 74,
            left: -10,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (Navigator.canPop(context))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const Spacer(),
                  const Text('🔥', style: TextStyle(fontSize: 78)),
                  const SizedBox(height: 8),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يوم متواصل 💪',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white.withOpacity(0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final int streak;

  const _WeekCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final completed = streak >= 7 ? 7 : streak.clamp(0, 7);
    const days = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'هذا الأسبوع',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '$completed/7 ✅',
                style: AppTextStyles.titleMedium.copyWith(
                  color: const Color(0xFF20B96D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: List.generate(days.length, (index) {
              final active = index < completed;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 72,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFE9292F)
                          : const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(active ? '🔥' : '○'),
                        const SizedBox(height: 6),
                        Text(
                          days[index],
                          style: AppTextStyles.labelMedium.copyWith(
                            color: active ? Colors.white : AppColors.textHint,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final _StreakMilestone milestone;
  final int streak;

  const _MilestoneCard({required this.milestone, required this.streak});

  @override
  Widget build(BuildContext context) {
    final completed = streak >= milestone.days;
    final isCurrent = !completed && streak < milestone.days;
    final remaining = (milestone.days - streak).clamp(0, milestone.days);

    return Container(
      height: 108,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: completed || isCurrent
            ? Border.all(color: const Color(0xFFFFE5A6))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Opacity(
        opacity: completed || isCurrent ? 1 : 0.48,
        child: Row(
          children: [
            Text(milestone.icon, style: const TextStyle(fontSize: 38)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${milestone.days} يوم',
                    style: AppTextStyles.displayMedium.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(milestone.title, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFFFFF0B6)
                    : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                completed ? 'مكتمل ✅' : 'باقي $remaining',
                style: AppTextStyles.labelMedium.copyWith(
                  color: completed
                      ? const Color(0xFFD6A200)
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakMilestone {
  final int days;
  final String title;
  final String icon;

  const _StreakMilestone({
    required this.days,
    required this.title,
    required this.icon,
  });
}
