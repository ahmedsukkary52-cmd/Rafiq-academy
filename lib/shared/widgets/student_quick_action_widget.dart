import 'package:flutter/material.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';
import '../../../../shared/theme/app_theme.dart';
import 'app_quick_action_grid.dart';

/// إجراءات سريعة لصفحات «حلقتي» + الروابط الأساسية من الـ Home.
/// Navigation callbacks stay with the caller.
class StudentQuickActionsWidget extends StatelessWidget {
  final VoidCallback onClassesTap;
  final VoidCallback onReviewScheduleTap;
  final VoidCallback onHomeworkTap;
  final VoidCallback onProgressReportTap;

  const StudentQuickActionsWidget({
    super.key,
    required this.onClassesTap,
    required this.onReviewScheduleTap,
    required this.onHomeworkTap,
    required this.onProgressReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: AppQuickActionGrid(
        layout: AppQuickActionLayout.row,
        items: [
          AppQuickActionItem(
            icon: Icons.videocam_outlined,
            label: 'حصصي',
            color: AppColors.primaryLight,
            iconColor: AppColors.primary,
            onTap: onClassesTap,
          ),
          AppQuickActionItem(
            icon: Icons.calendar_today_outlined,
            label: 'جدول\nالمراجعة',
            color: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF43A047),
            onTap: onReviewScheduleTap,
          ),
          AppQuickActionItem(
            icon: Icons.assignment_outlined,
            label: 'واجباتي',
            color: const Color(0xFFFFF3E0),
            iconColor: AppColors.secondary,
            onTap: onHomeworkTap,
          ),
          AppQuickActionItem(
            icon: Icons.bar_chart_rounded,
            label: 'تقرير\nالتقدم',
            color: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF9C27B0),
            onTap: onProgressReportTap,
          ),
        ],
      ),
    );
  }
}
