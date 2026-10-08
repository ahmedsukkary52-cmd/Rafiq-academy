import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/halaqa_plan.dart';
import '../bloc/halaqa_plan_bloc.dart';

/// «خطة الحلقة» tab body. The host provides [HalaqaPlanBloc] and dispatches
/// [LoadStudentHalaqaPlanEvent]; [onRetry] re-dispatches it.
class StudentHalaqaPlanView extends StatelessWidget {
  final VoidCallback onRetry;

  const StudentHalaqaPlanView({super.key, required this.onRetry});

  static const sectionTitles = <String>[
    'أين بدأنا',
    'أين وصلنا',
    'المطلوب القادم',
    'ما تم إنجازه',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('خطة الحلقة')),
        body: BlocBuilder<HalaqaPlanBloc, HalaqaPlanState>(
          builder: (context, state) {
            final plan = state.plan;
            if (plan == null) {
              return switch (state.status) {
                SectionStatus.error => AppErrorWidget(
                  message: state.error ?? 'تعذر تحميل خطة الحلقة',
                  onRetry: onRetry,
                ),
                _ => const AppLoadingWidget(),
              };
            }
            if (plan.isEmpty) {
              return AppEmptyState(
                icon: Icons.route_outlined,
                title: 'لا توجد خطة مسجّلة بعد',
                message:
                    'ستظهر هنا مقاطع الحفظ والمراجعة فور تكليفك بها من المعلم.',
                actionLabel: 'تحديث',
                onAction: onRetry,
              );
            }
            return RefreshIndicator(
              onRefresh: () async => onRetry(),
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                children: [
                  _TrackCard(title: 'الجديد', track: plan.newMemorization),
                  const SizedBox(height: 12),
                  _TrackCard(title: 'المراجعة', track: plan.review),
                  const SizedBox(height: 12),
                  Text(
                    'تُبنى الخطة من واجبات المعلم المسجّلة؛ بداية الخطة هي أول واجب مسجّل.',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final String title;
  final HalaqaPlanTrack track;

  const _TrackCard({required this.title, required this.track});

  @override
  Widget build(BuildContext context) {
    const titles = StudentHalaqaPlanView.sectionTitles;
    final completed = track.completed;
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          if (track.isEmpty)
            Text(
              'لا توجد مقاطع مسجّلة في هذا المسار',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            _PointRow(label: titles[0], entry: track.startPoint),
            _PointRow(label: titles[1], entry: track.reachedPoint),
            _PointRow(label: titles[2], entry: track.nextPortion),
            const Divider(height: 24),
            Text(
              '${titles[3]} (${completed.length})',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 4),
            if (completed.isEmpty)
              Text('لم يُنجز أي مقطع بعد', style: AppTextStyles.labelSmall)
            else
              for (final e in completed.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                  ),
                  title: Text(e.portion),
                  subtitle: Text(_date(e.completedAt ?? e.dueDate)),
                ),
            const Divider(height: 24),
            Text('آخر التكليفات', style: AppTextStyles.titleMedium),
            for (final e in track.recent())
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.portion),
                subtitle: Text('الموعد: ${_date(e.dueDate)}'),
                trailing: AppStatusChip(
                  label: e.isCompleted ? 'تم' : 'قيد التنفيذ',
                  tone: e.isCompleted
                      ? AppStatusTone.success
                      : AppStatusTone.info,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final String label;
  final HalaqaPlanEntry? entry;

  const _PointRow({required this.label, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.labelMedium),
          ),
          Expanded(
            child: Text(entry?.portion ?? '—', style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String _date(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
