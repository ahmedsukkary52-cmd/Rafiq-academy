import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/halaqa_day_readiness.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../domain/read_models/supervisor_day_board.dart';
import '../escalation/supervisor_escalation_guidance.dart';
import '../escalation/supervisor_fact_provenance.dart';
import 'supervisor_loading_skeletons.dart';

/// Presentation-only ordering for Rule 3 (exception-first).
///
/// Does **not** live in the projector or use case (Rule 5).
@visibleForTesting
List<SupervisorDayBoardItem> exceptionFirstItems(
  List<SupervisorDayBoardItem> items,
) {
  final exceptions = <SupervisorDayBoardItem>[];
  final healthy = <SupervisorDayBoardItem>[];
  for (final item in items) {
    if (item.needsAttention) {
      exceptions.add(item);
    } else {
      healthy.add(item);
    }
  }
  return [...exceptions, ...healthy];
}

/// W6 — supervisor day oversight board (observation / guidance, not teaching).
class SupervisorDayBoardSection extends StatelessWidget {
  final SectionStatus status;
  final SupervisorDayBoard board;
  final String? error;
  final VoidCallback onRetry;

  /// Injectable navigation policy for tests (Rule 6 permission fallback).
  /// When null, each gap uses [SupervisorEscalationPaths.isAllowed].
  final bool? forceNavigationAllowed;

  const SupervisorDayBoardSection({
    super.key,
    required this.status,
    required this.board,
    required this.error,
    required this.onRetry,
    this.forceNavigationAllowed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BoardHeader(),
        const SizedBox(height: 12),
        switch (status) {
          SectionStatus.initial || SectionStatus.loading => const SizedBox(
            height: 220,
            child: SupervisorListCardsSkeleton(itemCount: 2),
          ),
          SectionStatus.error => _BoardCard(
            child: Column(
              children: [
                Text(
                  error ?? 'تعذر تحميل نظرة اليوم',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لا تُعرض استنتاجات تشغيلية دون حقائق W1–W5 محمّلة',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
          SectionStatus.loaded => _BoardBody(
            board: board,
            forceNavigationAllowed: forceNavigationAllowed,
          ),
        },
      ],
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('متابعة يوم الحلقات', style: AppTextStyles.titleLarge),
        const SizedBox(height: 2),
        Text(
          'تحديد الحلقات المحجوبة وتوجيه الانتباه لمالك سير العمل',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BoardBody extends StatelessWidget {
  final SupervisorDayBoard board;
  final bool? forceNavigationAllowed;

  const _BoardBody({required this.board, this.forceNavigationAllowed});

  @override
  Widget build(BuildContext context) {
    if (board.sessionsTodayCount == 0) {
      return _BoardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'لا توجد حصص مجدوَلة اليوم تحت إشرافك',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const _ProvenanceBlock(
              provenance: SupervisorFactProvenance.noSessionToday,
            ),
          ],
        ),
      );
    }

    final ordered = exceptionFirstItems(board.items);
    final exceptions = ordered.where((i) => i.needsAttention).toList();
    final healthy = ordered.where((i) => i.isComplete).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تحتاج انتباه: ${exceptions.length} · مكتملة: ${healthy.length}',
          textAlign: TextAlign.right,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (exceptions.isEmpty)
          _BoardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'لا توجد استثناءات اليوم — كل حلقات اليوم مكتملة تشغيلياً',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const _ProvenanceBlock(
                  provenance: SupervisorFactProvenance.complete,
                ),
              ],
            ),
          )
        else
          for (final item in exceptions) ...[
            _ExceptionHalaqaCard(
              item: item,
              forceNavigationAllowed: forceNavigationAllowed,
            ),
            const SizedBox(height: 10),
          ],
        if (healthy.isNotEmpty) ...[
          const SizedBox(height: 4),
          _HealthyCollapse(items: healthy),
        ],
      ],
    );
  }
}

class _ExceptionHalaqaCard extends StatelessWidget {
  final SupervisorDayBoardItem item;
  final bool? forceNavigationAllowed;

  const _ExceptionHalaqaCard({required this.item, this.forceNavigationAllowed});

  @override
  Widget build(BuildContext context) {
    return _BoardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatTimeHm12Ar(item.startAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  item.halaqaName.trim().isEmpty ? 'حلقة' : item.halaqaName,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'المعلم المسؤول: ${escalationOwnerName(item)}',
            textAlign: TextAlign.end,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final gap in item.readiness.gaps)
            _GapEscalationGuidance(
              guidance: SupervisorEscalationGuidance.fromGap(
                item: item,
                gap: gap,
                navigationAllowed: forceNavigationAllowed,
              ),
              gap: gap,
            ),
        ],
      ),
    );
  }
}

class _HealthyCollapse extends StatelessWidget {
  final List<SupervisorDayBoardItem> items;

  const _HealthyCollapse({required this.items});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'حلقات مكتملة اليوم (${items.length})',
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BoardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.halaqaName.trim().isEmpty ? 'حلقة' : item.halaqaName,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.titleMedium,
                    ),
                    Text(
                      'المعلم المسؤول: ${escalationOwnerName(item)}',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _ProvenanceBlock(
                      provenance: SupervisorFactProvenance.complete,
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

/// Rule 6 — guidance row: who / why / where; CTA only when navigable.
class _GapEscalationGuidance extends StatelessWidget {
  final SupervisorEscalationGuidance guidance;
  final HalaqaDayGap gap;

  const _GapEscalationGuidance({required this.guidance, required this.gap});

  @override
  Widget build(BuildContext context) {
    final provenance = SupervisorFactProvenance.forGap(gap);
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (guidance.canNavigate)
                const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textSecondary,
                )
              else
                const SizedBox(width: 24),
              const Spacer(),
              Flexible(
                child: Text(
                  guidance.why,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Icon(_iconFor(gap.kind), size: 18, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'المسؤول: ${guidance.ownerName}',
            textAlign: TextAlign.end,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'الحلقة: ${guidance.halaqaName}',
            textAlign: TextAlign.end,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'أين؟ ${guidance.whereLabel}',
            textAlign: TextAlign.end,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _ProvenanceBlock(provenance: provenance),
          if (guidance.canNavigate) ...[
            const SizedBox(height: 4),
            Text(
              'توجيه إلى سير عمل المعلم (بدون تولي التنفيذ)',
              textAlign: TextAlign.end,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );

    if (!guidance.canNavigate) return body;

    return InkWell(
      onTap: () => context.push(guidance.route),
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: body,
    );
  }
}

/// Rule 7 — trace displayed conclusion to W1–W5 facts (presentation only).
class _ProvenanceBlock extends StatelessWidget {
  final SupervisorFactProvenance provenance;

  const _ProvenanceBlock({required this.provenance});

  @override
  Widget build(BuildContext context) {
    final secondary = AppTextStyles.labelSmall.copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الحقائق: ${provenance.academyFacts}',
          textAlign: TextAlign.end,
          style: secondary,
        ),
        Text(
          'ملكية الحقائق: ${provenance.owningWorkflow}',
          textAlign: TextAlign.end,
          style: secondary,
        ),
        if (provenance.isResolvable)
          Text(
            'ما يحلّها: ${provenance.resolvingAction}',
            textAlign: TextAlign.end,
            style: secondary,
          ),
      ],
    );
  }
}

class _BoardCard extends StatelessWidget {
  final Widget child;

  const _BoardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

IconData _iconFor(HalaqaDayGapKind kind) => switch (kind) {
  HalaqaDayGapKind.attendanceIncomplete => Icons.how_to_reg_outlined,
  HalaqaDayGapKind.homeworkPending => Icons.assignment_outlined,
  HalaqaDayGapKind.reviewsPending => Icons.rate_review_outlined,
};
