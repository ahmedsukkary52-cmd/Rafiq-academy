import 'package:flutter/material.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/absence_request.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import 'excuses/teacher_excuse_status_chip.dart';
import 'teacher_loading_skeletons.dart';

/// Pending parent استئذان for the attendance day — approve/reject only.
class TeacherPendingAbsenceSection extends StatelessWidget {
  final SectionStatus status;
  final List<AbsenceRequestEntity> requests;
  final String? error;
  final bool canReview;
  final bool reviewing;
  final String Function(String studentId) studentName;
  final VoidCallback onRetry;
  final void Function(
    AbsenceRequestEntity request,
    AbsenceRequestStatus decision,
  )
  onReview;

  const TeacherPendingAbsenceSection({
    super.key,
    required this.status,
    required this.requests,
    required this.error,
    required this.canReview,
    required this.reviewing,
    required this.studentName,
    required this.onRetry,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'طلبات الاستئذان',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          'مراجعة طلب ولي الأمر فقط — لا يعدّل سجل الحضور تلقائياً.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textHint,
            fontSize: 12,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 10),
        if (status == SectionStatus.initial || status == SectionStatus.loading)
          const TeacherRosterRowsSkeleton(itemCount: 2)
        else if (status == SectionStatus.error)
          AppErrorWidget(
            message: error ?? 'تعذر تحميل طلبات الاستئذان',
            onRetry: onRetry,
          )
        else if (requests.isEmpty)
          AppCard(
            child: Text(
              'لا توجد طلبات استئذان لهذا اليوم.',
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
              child: _PendingAbsenceCard(
                request: request,
                studentLabel: studentName(request.studentId),
                canReview: canReview && !reviewing,
                reviewing: reviewing,
                onApprove: () =>
                    onReview(request, AbsenceRequestStatus.approved),
                onReject: () =>
                    onReview(request, AbsenceRequestStatus.rejected),
              ),
            ),
      ],
    );
  }
}

class _PendingAbsenceCard extends StatelessWidget {
  final AbsenceRequestEntity request;
  final String studentLabel;
  final bool canReview;
  final bool reviewing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingAbsenceCard({
    required this.request,
    required this.studentLabel,
    required this.canReview,
    required this.reviewing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'استئذان — $studentLabel',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateDmy(request.date),
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TeacherExcuseStatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.reason,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 12,
              height: 1.5,
              color: const Color(0xFF4A4A5A),
            ),
            textAlign: TextAlign.right,
          ),
          if (canReview || reviewing) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canReview ? onReject : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'رفض',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: canReview ? onApprove : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: reviewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : Text(
                            'قبول',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.onPrimary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
