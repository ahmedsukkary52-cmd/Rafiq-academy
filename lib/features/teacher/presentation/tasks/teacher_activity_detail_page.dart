import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/presentation/halaqa_activities/activity_thread_widgets.dart';
import '../../../../shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../halaqa_activity/domain/usecases/halaqa_activity_usecases.dart';
import '../../../halaqa_activity/presentation/halaqa_activity_ui_mapper.dart';

class TeacherActivityDetailPage extends StatefulWidget {
  final String halaqaId;
  final String activityId;

  const TeacherActivityDetailPage({
    super.key,
    required this.halaqaId,
    required this.activityId,
  });

  @override
  State<TeacherActivityDetailPage> createState() =>
      _TeacherActivityDetailPageState();
}

class _TeacherActivityDetailPageState extends State<TeacherActivityDetailPage> {
  var _status = ActivityListLoadState.loading;
  String? _error;
  HalaqaActivityUi? _activity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = ActivityListLoadState.loading;
      _error = null;
    });
    final result = await sl<GetHalaqaActivityUseCase>()(
      GetHalaqaActivityParams(
        halaqaId: widget.halaqaId,
        activityId: widget.activityId,
        includeThread: true,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _status = ActivityListLoadState.error;
        _error = failure.message;
        _activity = null;
      }),
      (entity) => setState(() {
        _activity = HalaqaActivityUiMapper.toUi(entity);
        _status = ActivityListLoadState.loaded;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تفاصيل المهمة'),
      ),
      body: switch (_status) {
        ActivityListLoadState.loading => const AppLoadingWidget(),
        ActivityListLoadState.error => AppErrorWidget(
            message: _error ?? 'حدث خطأ',
            onRetry: _load,
          ),
        ActivityListLoadState.loaded => _DetailBody(activity: _activity!),
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  final HalaqaActivityUi activity;

  const _DetailBody({required this.activity});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          activity.teacherName,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDateDmy(activity.createdAt),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  UserAvatar(name: activity.teacherName, size: AppSizes.avatarM),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                activity.prompt,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyLarge.copyWith(height: 1.45),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  ...activity.allowedResponseTypes.map(
                    (t) => _TypeBadge(type: t),
                  ),
                  if (activity.deadline != null)
                    _InfoBadge(
                      icon: Icons.event_outlined,
                      label: 'حتى ${formatDateDmy(activity.deadline!)}',
                    ),
                  _InfoBadge(
                    icon: Icons.forum_outlined,
                    label: '${activity.responseCount} طلاب ردّوا',
                  ),
                  if (activity.sharedToPosts)
                    const _InfoBadge(
                      icon: Icons.campaign_outlined,
                      label: 'نُشر في المنشورات',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.paddingM),
        Text(
          'ردود الطلاب',
          textAlign: TextAlign.right,
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (activity.thread.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingL),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 36,
                    color: AppColors.primary.withValues(alpha: 0.65),
                  ),
                  const SizedBox(height: 10),
                  Text('لا توجد ردود بعد', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'ستظهر هنا ردود الطلاب على شكل محادثة.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...activity.thread.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActivityThreadBubble(message: m),
            ),
          ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ActivityResponseTypeUi type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      ActivityResponseTypeUi.text => Icons.notes_rounded,
      ActivityResponseTypeUi.image => Icons.image_outlined,
      ActivityResponseTypeUi.audio => Icons.mic_none_rounded,
    };
    return _InfoBadge(icon: icon, label: type.labelAr);
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: AppColors.primary),
        ],
      ),
    );
  }
}
