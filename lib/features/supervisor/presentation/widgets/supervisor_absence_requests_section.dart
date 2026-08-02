import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../parent/domain/absence_request_projection.dart';
import '../../../parent/domain/entities/parent_entities.dart';

/// Read-only استئذان context for supervised halaqat (W7 Rule 2).
///
/// Projects existing request docs — no approve/reject, no attendance rewrite.
class SupervisorAbsenceRequestsSection extends StatelessWidget {
  final SectionStatus status;
  final List<AbsenceRequestEntity> requests;
  final String? error;
  final VoidCallback onRetry;
  final String Function(String halaqaId) halaqaName;

  const SupervisorAbsenceRequestsSection({
    super.key,
    required this.status,
    required this.requests,
    required this.error,
    required this.onRetry,
    required this.halaqaName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'استئذان اليوم (عرض فقط)',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          'قراءة من طلبات الاستئذان الحالية — القرار والتنفيذ لمعلم الحلقة.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        if (status == SectionStatus.initial || status == SectionStatus.loading)
          const SizedBox(height: 80, child: AppLoadingWidget())
        else if (status == SectionStatus.error)
          AppErrorWidget(
            message: error ?? 'تعذر تحميل طلبات الاستئذان',
            onRetry: onRetry,
          )
        else if (requests.isEmpty)
          AppCard(
            child: Text(
              'لا توجد طلبات استئذان لهذا اليوم في الحلقات المشرفة.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          AbsenceRequestProjection.statusLabel(request.status),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatDateDmy(request.date),
                          style: AppTextStyles.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.reason,
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'حلقة: ${halaqaName(request.halaqaId)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    if (AbsenceRequestProjection.isDecided(request) &&
                        (request.reviewedBy?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 2),
                      Text(
                        'راجع: ${request.reviewedBy}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textHint,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => context.push(
                          AppRoutes.teacherAttend.replaceFirst(
                            ':halaqaId',
                            request.halaqaId,
                          ),
                        ),
                        child: const Text('توجيه لسجل الحضور'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
