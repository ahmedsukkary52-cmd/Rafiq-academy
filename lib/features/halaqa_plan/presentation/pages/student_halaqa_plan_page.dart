import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../bloc/halaqa_plan_bloc.dart';

/// «خطة الحلقة» — ثلاث بطاقات منفصلة: الجديد · الماضي القريب · المراجعة الجديدة.
class StudentHalaqaPlanView extends StatelessWidget {
  final VoidCallback onRetry;

  const StudentHalaqaPlanView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
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
              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: _PlanHero()),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.route_outlined,
                      title: 'لا توجد خطة مسجّلة بعد',
                      message:
                          'ستظهر هنا مقاطع الحفظ والمراجعة فور تكليفك بها من المعلم.',
                      actionLabel: 'تحديث',
                      onAction: onRetry,
                    ),
                  ),
                ],
              );
            }

            final neu = plan.newMemorization;
            final review = plan.review;

            return RefreshIndicator(
              onRefresh: () async => onRetry(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: _PlanHero()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _PlanBucketCard(
                          title: 'الجديد',
                          subtitle: 'المطلوب للحفظ الآن',
                          icon: Icons.auto_stories_rounded,
                          accent: AppColors.primary,
                          portion: neu.nextPortion?.portion ??
                              neu.reachedPoint?.portion ??
                              neu.startPoint?.portion,
                          emptyHint: 'لا يوجد مقطع جديد حالياً',
                          meta: neu.nextPortion != null
                              ? 'موعد: ${_date(neu.nextPortion!.dueDate)}'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _PlanBucketCard(
                          title: 'الماضي القريب',
                          subtitle: 'آخر ما أتممته من حفظ أو مراجعة',
                          icon: Icons.history_rounded,
                          accent: AppColors.secondaryDeep,
                          portion: neu.reachedPoint?.portion ??
                              (review.completed.isNotEmpty
                                  ? review.completed.first.portion
                                  : null),
                          emptyHint: 'لم يُسجَّل إنجاز قريب بعد',
                          meta: () {
                            final e = neu.reachedPoint ??
                                (review.completed.isNotEmpty
                                    ? review.completed.first
                                    : null);
                            if (e == null) return null;
                            final when = e.completedAt ?? e.dueDate;
                            return 'أُنجز: ${_date(when)}';
                          }(),
                        ),
                        const SizedBox(height: 12),
                        _PlanBucketCard(
                          title: 'المراجعة الجديدة',
                          subtitle: 'مراجعة مطلوبة من المعلم',
                          icon: Icons.replay_circle_filled_rounded,
                          accent: AppColors.info,
                          portion: review.nextPortion?.portion ??
                              review.startPoint?.portion,
                          emptyHint: 'لا توجد مراجعة جديدة حالياً',
                          meta: review.nextPortion != null
                              ? 'موعد: ${_date(review.nextPortion!.dueDate)}'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'تُبنى الخطة من واجبات المعلم المسجّلة.',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ]),
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

class _PlanHero extends StatelessWidget {
  const _PlanHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          Text(
            'خطة الحلقة',
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جديد · ماضي قريب · مراجعة جديدة',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBucketCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String? portion;
  final String emptyHint;
  final String? meta;

  const _PlanBucketCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.portion,
    required this.emptyHint,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final has = portion != null && portion!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accent.withValues(alpha: 0.14),
            AppColors.surface,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              has ? portion!.trim() : emptyHint,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: has ? FontWeight.w700 : FontWeight.w500,
                color: has ? AppColors.textPrimary : AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          if (meta != null) ...[
            const SizedBox(height: 8),
            Text(
              meta!,
              style: AppTextStyles.labelSmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _date(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
