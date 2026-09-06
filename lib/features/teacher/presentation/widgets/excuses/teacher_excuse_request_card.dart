import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_theme.dart';
import 'teacher_excuse_list_item_data.dart';
import 'teacher_excuse_status_chip.dart';

/// Figma B1 history / pending card for one استئذان request.
class TeacherExcuseRequestCard extends StatelessWidget {
  final TeacherExcuseListItemData item;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool reviewing;

  const TeacherExcuseRequestCard({
    super.key,
    required this.item,
    this.onApprove,
    this.onReject,
    this.reviewing = false,
  });

  @override
  Widget build(BuildContext context) {
    final canReview = onApprove != null || onReject != null;
    final subtitle = item.subtitle?.trim() ?? '';

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
                      item.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.dateLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TeacherExcuseStatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.reason,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 12,
              height: 1.5,
              color: const Color(0xFF4A4A5A),
            ),
            textAlign: TextAlign.right,
          ),
          if (canReview) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: reviewing ? null : onReject,
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
                    onPressed: reviewing ? null : onApprove,
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
