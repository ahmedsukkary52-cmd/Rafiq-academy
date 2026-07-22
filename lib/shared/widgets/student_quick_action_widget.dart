import 'package:flutter/material.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';
import '../../../../shared/theme/app_theme.dart';

/// إجراءات سريعة لصفحات «حلقتي» + الروابط الأساسية من الـ Home.
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionItem(
            icon: Icons.videocam_outlined,
            label: 'حصصي',
            color: AppColors.primaryLight,
            iconColor: AppColors.primary,
            onTap: onClassesTap,
          ),
          _ActionItem(
            icon: Icons.calendar_today_outlined,
            label: 'جدول\nالمراجعة',
            color: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF43A047),
            onTap: onReviewScheduleTap,
          ),
          _ActionItem(
            icon: Icons.assignment_outlined,
            label: 'واجباتي',
            color: const Color(0xFFFFF3E0),
            iconColor: AppColors.secondary,
            onTap: onHomeworkTap,
          ),
          _ActionItem(
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

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(icon, color: iconColor, size: AppSizes.iconL),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
