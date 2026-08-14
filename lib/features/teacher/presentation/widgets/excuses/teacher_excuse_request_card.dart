import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_theme.dart';
import 'teacher_excuse_list_item_data.dart';
import 'teacher_excuse_status_chip.dart';

/// Figma B1 history card for one excuse / absence request.
class TeacherExcuseRequestCard extends StatelessWidget {
  final TeacherExcuseListItemData item;

  const TeacherExcuseRequestCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
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
        ],
      ),
    );
  }
}
