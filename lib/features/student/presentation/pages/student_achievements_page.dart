import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/achievement_entity.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

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
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<StudentBloc>()
        ..add(LoadStudentProfileEvent(auth.user.uid))
        ..add(LoadAchievementsEvent(auth.user.uid));
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
            builder: (context, state) {
              if (state.achievementsStatus == SectionStatus.loading &&
                  state.achievements.isEmpty) {
                return const AppLoadingWidget();
              }

              final completed = _completedItems(state);
              final locked = _lockedItems(state);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Header(state: state)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'إنجازات مكتملة ⭐',
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SliverList.separated(
                    itemCount: completed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        index == 0 ? 22 : 0,
                        24,
                        0,
                      ),
                      child: _AchievementRow(item: completed[index]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'إنجازات قادمة 🔒',
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SliverList.separated(
                    itemCount: locked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        index == 0 ? 22 : 0,
                        24,
                        index == locked.length - 1 ? 28 : 0,
                      ),
                      child: _AchievementRow(item: locked[index], locked: true),
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

  List<_AchievementItem> _completedItems(StudentState state) {
    final profile = state.profile;
    final items = <_AchievementItem>[
      const _AchievementItem(
        icon: '⭐',
        title: 'أول سورة',
        subtitle: 'حفظت سورة الفاتحة كاملة',
        points: 10,
        color: Color(0xFFFFF1B8),
      ),
      const _AchievementItem(
        icon: '📖',
        title: 'قارئ مداوم',
        subtitle: 'حضرت 10 حصص متتالية',
        points: 20,
        color: Color(0xFFCFF5E4),
      ),
      _AchievementItem(
        icon: '🔥',
        title: 'أسبوع ذهبي',
        subtitle: '${profile?.streakDays ?? 0} أيام متواصلة بدون انقطاع',
        points: 15,
        color: const Color(0xFFFFD9DE),
        onTapRoute: AppRoutes.studentStreak,
      ),
    ];

    for (final achievement in state.achievements) {
      items.add(
        _AchievementItem(
          icon: _iconFor(achievement.type),
          title: achievement.title,
          subtitle: 'تم منحها بواسطة ${achievement.issuedBy}',
          points: achievement.type == AchievementType.certificate ? 30 : 10,
          color: const Color(0xFFE6F7FF),
        ),
      );
    }
    return items;
  }

  List<_AchievementItem> _lockedItems(StudentState state) {
    final completedJuz = state.profile?.completedJuz ?? 0;
    return [
      _AchievementItem(
        icon: '🌙',
        title: 'حافظ الجزء',
        subtitle: 'أتمم حفظ جزء كامل',
        points: 50,
        color: const Color(0xFFECEFF3),
        unlocked: completedJuz > 0,
      ),
      const _AchievementItem(
        icon: '🏆',
        title: 'بطل الشهر',
        subtitle: 'تصدر القائمة أسبوعين',
        points: 30,
        color: Color(0xFFECEFF3),
      ),
    ];
  }

  String _iconFor(AchievementType type) => switch (type) {
    AchievementType.star => '⭐',
    AchievementType.badge => '🎖️',
    AchievementType.certificate => '📜',
  };
}

class _Header extends StatelessWidget {
  final StudentState state;

  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final completed = state.achievements.length + 3;
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
                  label: 'دقة الحفظ',
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
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
  final _AchievementItem item;
  final bool locked;

  const _AchievementRow({required this.item, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final effectiveLocked = locked && !item.unlocked;
    return InkWell(
      onTap: item.onTapRoute == null
          ? null
          : () => context.push(item.onTapRoute!),
      borderRadius: BorderRadius.circular(26),
      child: Opacity(
        opacity: effectiveLocked ? 0.48 : 1,
        child: Container(
          height: 132,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                  color: item.color,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(item.icon, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.subtitle, style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0B6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  '${item.points}++',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: const Color(0xFFD6A200),
                    fontWeight: FontWeight.w900,
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
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _AchievementItem {
  final String icon;
  final String title;
  final String subtitle;
  final int points;
  final Color color;
  final bool unlocked;
  final String? onTapRoute;

  const _AchievementItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.color,
    this.unlocked = false,
    this.onTapRoute,
  });
}
