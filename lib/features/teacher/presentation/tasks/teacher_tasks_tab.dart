import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../halaqa_activity/domain/usecases/halaqa_activity_usecases.dart';
import '../../../halaqa_activity/presentation/halaqa_activity_ui_mapper.dart';
import 'create_halaqa_activity_sheet.dart';
import 'teacher_activity_detail_page.dart';

/// Class Details → المهام — lightweight activities + entry to حفظ/مراجعة.
class TeacherTasksTab extends StatefulWidget {
  final String halaqaId;
  final bool canWrite;
  final VoidCallback onOpenLessonAssignment;

  const TeacherTasksTab({
    super.key,
    required this.halaqaId,
    required this.canWrite,
    required this.onOpenLessonAssignment,
  });

  @override
  State<TeacherTasksTab> createState() => _TeacherTasksTabState();
}

class _TeacherTasksTabState extends State<TeacherTasksTab> {
  var _status = ActivityListLoadState.loading;
  String? _error;
  List<HalaqaActivityUi> _activities = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _status = ActivityListLoadState.loading;
      _error = null;
    });
    final result = await sl<ListHalaqaActivitiesUseCase>()(
      HalaqaActivityHalaqaParams(widget.halaqaId),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _status = ActivityListLoadState.error;
        _error = failure.message;
        _activities = const [];
      }),
      (items) => setState(() {
        _status = ActivityListLoadState.loaded;
        _activities = items.map(HalaqaActivityUiMapper.toUi).toList();
      }),
    );
  }

  Future<void> _openCreate() async {
    final created = await showCreateHalaqaActivitySheet(
      context,
      halaqaId: widget.halaqaId,
    );
    if (created != null && mounted) await _reload();
  }

  void _openDetail(HalaqaActivityUi activity) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => TeacherActivityDetailPage(
          halaqaId: widget.halaqaId,
          activityId: activity.id,
        ),
      ),
    )
        .then((_) {
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingM,
          AppSizes.paddingM,
          AppSizes.paddingM,
          AppSizes.paddingXL,
        ),
        children: [
          Text('المهام', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'أنشطة خفيفة للحلقة بالكامل — ليست تكليف الحفظ/المراجعة.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          if (widget.canWrite) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('مهمة جديدة'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenLessonAssignment,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('تكليف حفظ/مراجعة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'التنفيذ متاح لمعلم الحلقة فقط — يمكنك استعراض المهام السابقة.',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSizes.paddingL),
          Row(
            children: [
              Text(
                'المهام السابقة',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_status == ActivityListLoadState.loaded)
                Text(
                  '${_activities.length}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_status == ActivityListLoadState.loading)
            const SizedBox(height: 160, child: AppLoadingWidget())
          else if (_status == ActivityListLoadState.error)
            AppErrorWidget(
              message: _error ?? 'حدث خطأ',
              onRetry: _reload,
            )
          else if (_activities.isEmpty)
            const _TasksEmptyState()
          else
            ..._activities.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityHistoryCard(
                  activity: a,
                  onTap: () => _openDetail(a),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TasksEmptyState extends StatelessWidget {
  const _TasksEmptyState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingL),
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text('لا توجد مهام بعد', style: AppTextStyles.titleMedium),
            const SizedBox(height: 6),
            Text(
              'أنشئ مهمة جديدة للحلقة، أو أرسل تكليف حفظ/مراجعة من الزر أعلاه.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityHistoryCard extends StatelessWidget {
  final HalaqaActivityUi activity;
  final VoidCallback onTap;

  const _ActivityHistoryCard({
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final types = activity.allowedResponseTypes
        .map((t) => t.labelAr)
        .join(' · ');
    final deadline = activity.deadline;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textHint,
                size: AppSizes.iconL,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      activity.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أُنشئت ${formatDateDmy(activity.createdAt)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              _MetaChip(
                icon: Icons.forum_outlined,
                label: '${activity.responseCount} ردود',
              ),
              _MetaChip(
                icon: Icons.tune_rounded,
                label: types,
              ),
              if (deadline != null)
                _MetaChip(
                  icon: Icons.event_outlined,
                  label: 'حتى ${formatDateDmy(deadline)}',
                ),
              if (activity.sharedToPosts)
                const _MetaChip(
                  icon: Icons.campaign_outlined,
                  label: 'نُشر في المنشورات',
                  accent: AppColors.gradeGood,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (accent ?? AppColors.primary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }
}
