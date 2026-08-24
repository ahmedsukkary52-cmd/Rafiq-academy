import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/achievement_entity.dart';
import '../../../student/domain/usecases/get_achievements_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../bloc/parent_bloc.dart';
import '../parent_child_access.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentAchievementsPage extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ParentAchievementsPage({super.key, this.studentId, this.studentName});

  @override
  State<ParentAchievementsPage> createState() => _ParentAchievementsPageState();
}

class _ParentAchievementsPageState extends State<ParentAchievementsPage> {
  String? _studentId;
  bool _loading = true;
  String? _error;
  List<AchievementEntity> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<ParentBloc>().state;
      final id =
          widget.studentId ??
          state.selectedChildId ??
          (state.childrenIds.isNotEmpty ? state.childrenIds.first : null);
      setState(() => _studentId = id);
      _load(id);
    });
  }

  Future<void> _load(String? studentId) async {
    if (studentId == null) {
      setState(() {
        _loading = false;
        _items = const [];
      });
      return;
    }
    final parentState = context.read<ParentBloc>().state;
    if (!ParentChildAccess.owns(state: parentState, studentId: studentId)) {
      setState(() {
        _loading = false;
        _error = ParentChildAccess.deniedMessage;
        _items = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetAchievementsUseCase>()(
      StudentUidParams(studentId),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (items) => setState(() {
        _loading = false;
        _items = [...items]..sort((a, b) => b.date.compareTo(a.date));
      }),
    );
  }

  int get _badgeCount => _items.where((item) {
    return item.type == AchievementType.badge ||
        item.type == AchievementType.completionBadge ||
        item.type == AchievementType.studentOfWeek;
  }).length;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ParentBloc>().state;
    final verses = _studentId == null
        ? 0
        : state.snapshotFor(_studentId!)?.totalVersesMemorized ?? 0;

    return ParentSubpageScaffold(
      title: 'إنجازات أبنائي',
      backgroundColor: AppColors.dark,
      headerColor: AppColors.dark,
      foregroundColor: AppColors.onPrimary,
      actions: [
        if (state.childrenIds.length > 1)
          PopupMenuButton<String>(
            tooltip: 'اختيار الابن',
            color: AppColors.surface,
            onSelected: (id) {
              setState(() => _studentId = id);
              _load(id);
            },
            itemBuilder: (context) => [
              for (final id in state.childrenIds)
                PopupMenuItem(
                  value: id,
                  child: Text(state.childDisplayName(id)),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _studentId == null
                        ? 'الكل'
                        : state.childDisplayName(_studentId!),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _HeaderStat(
                  value: parentEasternDigits('${_items.length}'),
                  label: 'إنجاز',
                ),
                _HeaderStat(
                  value: parentEasternDigits('$_badgeCount'),
                  label: 'شارة',
                ),
                _HeaderStat(
                  value: verses > 0 ? parentEasternDigits('$verses') : '—',
                  label: 'آية',
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _loading
                  ? const ParentListCardsSkeleton()
                  : _error != null
                  ? AppErrorWidget(
                      message: _error!,
                      onRetry: () => _load(_studentId),
                    )
                  : _items.isEmpty
                  ? const ParentEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'لا توجد إنجازات بعد',
                      message: 'تظهر هنا الجوائز التي يمنحها المعلم فقط.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length.clamp(0, 4),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.05,
                              ),
                          itemBuilder: (context, index) {
                            return _AchievementTile(item: _items[index]);
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'آخر الإنجازات',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in _items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _styleFor(item.type).accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.titleMedium,
                                  ),
                                ),
                                Text(
                                  formatDateDmy(item.date),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
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

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimaryMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementEntity item;

  const _AchievementTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(item.type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: style.bg, shape: BoxShape.circle),
            child: Icon(style.icon, color: style.accent),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDateDmy(item.date),
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color bg, Color accent}) _styleFor(AchievementType type) {
  return switch (type) {
    AchievementType.star ||
    AchievementType.performanceStars ||
    AchievementType.performance => (
      icon: Icons.star_rounded,
      bg: const Color(0xFFFFF3E0),
      accent: AppColors.secondary,
    ),
    AchievementType.studentOfWeek => (
      icon: Icons.emoji_events_rounded,
      bg: const Color(0xFFF3E5F5),
      accent: AppColors.awardWeekly,
    ),
    AchievementType.perfectAttendance || AchievementType.attendance => (
      icon: Icons.event_available_rounded,
      bg: AppColors.primaryLight,
      accent: AppColors.primaryDark,
    ),
    AchievementType.completionBadge || AchievementType.completion => (
      icon: Icons.verified_rounded,
      bg: const Color(0xFFE8F5E9),
      accent: AppColors.success,
    ),
    _ => (
      icon: Icons.workspace_premium_rounded,
      bg: const Color(0xFFE8F5E9),
      accent: AppColors.success,
    ),
  };
}
