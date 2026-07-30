import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/achievement_entity.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

enum _RewardTab { badges, certificates, gifts }

class StudentBadgesPage extends StatefulWidget {
  const StudentBadgesPage({super.key});

  @override
  State<StudentBadgesPage> createState() => _StudentBadgesPageState();
}

class _StudentBadgesPageState extends State<StudentBadgesPage> {
  _RewardTab _tab = _RewardTab.badges;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
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
        body: BlocBuilder<StudentBloc, StudentState>(
          buildWhen: (previous, current) =>
              previous.profile != current.profile ||
              previous.profileStatus != current.profileStatus ||
              previous.profileError != current.profileError ||
              previous.achievements != current.achievements ||
              previous.achievementsStatus != current.achievementsStatus ||
              previous.achievementsError != current.achievementsError,
          builder: (context, state) {
            final profileBusy =
                state.profile == null &&
                (state.profileStatus == SectionStatus.initial ||
                    state.profileStatus == SectionStatus.loading);
            final achievementsBusy =
                state.achievementsStatus == SectionStatus.initial ||
                state.achievementsStatus == SectionStatus.loading;

            if (profileBusy || achievementsBusy) {
              return const AppLoadingWidget();
            }

            if (state.profileStatus == SectionStatus.error &&
                state.profile == null) {
              return AppErrorWidget(
                message: state.profileError ?? 'تعذر تحميل بيانات الملف',
                onRetry: _reload,
              );
            }

            if (state.achievementsStatus == SectionStatus.error) {
              return AppErrorWidget(
                message:
                    state.achievementsError ?? 'تعذر تحميل الإنجازات والشارات',
                onRetry: _reload,
              );
            }

            final coins = state.profile?.coins ?? 0;
            final items = _itemsFor(state);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _CoinsHeader(coins: coins)),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -28),
                    child: _Tabs(
                      selected: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _emptyMessageForTab(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverGrid.builder(
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.86,
                          ),
                      itemBuilder: (context, index) {
                        return _BadgeCard(item: items[index]);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _emptyMessageForTab() {
    return switch (_tab) {
      _RewardTab.gifts => 'الهدايا — Coming Soon',
      _RewardTab.certificates => 'لا توجد شهادات ممنوحة حالياً',
      _RewardTab.badges => 'لا توجد شارات مكتسبة حالياً',
    };
  }

  List<_BadgeItem> _itemsFor(StudentState state) {
    final profile = state.profile;
    final badges = profile?.badges ?? const <String>[];
    final achievements = state.achievements;
    final now = DateTime.now();

    bool isRecentUnlock(DateTime date) =>
        now.difference(date).inDays <= 7 && !date.isAfter(now);

    if (_tab == _RewardTab.certificates) {
      final certificates =
          achievements
              .where((a) => a.type == AchievementType.certificate)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      return certificates
          .map(
            (a) => _BadgeItem(
              icon: '📜',
              title: a.title.isNotEmpty ? a.title : 'شهادة',
              subtitle: 'شهادة ممنوحة',
              color: const Color(0xFF24C6CF),
              unlocked: true,
              isNew: isRecentUnlock(a.date),
            ),
          )
          .toList();
    }

    if (_tab == _RewardTab.gifts) {
      // No gift catalog is backed by backend data yet.
      return const [];
    }

    final badgeAchievements =
        achievements.where((a) => a.type == AchievementType.badge).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final fromAchievements = badgeAchievements
        .map(
          (a) => _BadgeItem(
            icon: '🎖️',
            title: a.title.isNotEmpty ? a.title : 'شارة',
            subtitle: 'شارة مكتسبة',
            color: const Color(0xFFF6C42E),
            unlocked: true,
            isNew: isRecentUnlock(a.date),
          ),
        )
        .toList();

    final achievementTitles = badgeAchievements
        .map((a) => a.title.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();

    final fromProfile = badges
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .where((b) => !achievementTitles.contains(b.toLowerCase()))
        .map(
          (b) => _BadgeItem(
            icon: '🏅',
            title: b,
            subtitle: 'شارة في الملف',
            color: const Color(0xFF25AE69),
            unlocked: true,
          ),
        )
        .toList();

    return [...fromAchievements, ...fromProfile];
  }
}

class _CoinsHeader extends StatelessWidget {
  final int coins;

  const _CoinsHeader({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 310,
      decoration: const BoxDecoration(color: Color(0xFFF7C52B)),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
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
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                    ),
                  const Text('🏆', style: TextStyle(fontSize: 54)),
                  const SizedBox(height: 8),
                  Text(
                    '$coins',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'عملاتي المتاحة 🌘',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.56),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final _RewardTab selected;
  final ValueChanged<_RewardTab> onChanged;

  const _Tabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'الشارات 🏅',
            value: _RewardTab.badges,
            selected: selected,
            onChanged: onChanged,
          ),
          const SizedBox(width: 10),
          _TabButton(
            label: 'الشهادات 📜',
            value: _RewardTab.certificates,
            selected: selected,
            onChanged: onChanged,
          ),
          const SizedBox(width: 10),
          _TabButton(
            label: 'الهدايا 🎁',
            value: _RewardTab.gifts,
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final _RewardTab value;
  final _RewardTab selected;
  final ValueChanged<_RewardTab> onChanged;

  const _TabButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF7C52B) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final _BadgeItem item;

  const _BadgeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: item.unlocked ? 1 : 0.48,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: item.unlocked ? const Color(0xFFFFE49A) : Colors.transparent,
          ),
        ),
        child: Stack(
          children: [
            if (item.isNew)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7C52B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'جديد!',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.icon,
                      style: const TextStyle(fontSize: 34),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
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

class _BadgeItem {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool unlocked;
  final bool isNew;

  const _BadgeItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.unlocked = false,
    this.isNew = false,
  });
}
