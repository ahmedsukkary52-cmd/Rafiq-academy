import 'package:flutter/material.dart';

import '../../../../../shared/domain/absence_request.dart';
import '../../../../../shared/theme/app_theme.dart';

/// Figma B1 status pill — labels match the design frame (مقبول / معلق / مرفوض).
class TeacherExcuseStatusChip extends StatelessWidget {
  final AbsenceRequestStatus status;

  const TeacherExcuseStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, icon) = switch (status) {
      AbsenceRequestStatus.approved => (
        'مقبول',
        const Color(0xFF2BB673),
        const Color(0xFFD1F5E5),
        Icons.check_rounded,
      ),
      AbsenceRequestStatus.pending => (
        'معلق',
        AppColors.warning,
        const Color(0xFFFEF0D9),
        Icons.access_time_rounded,
      ),
      AbsenceRequestStatus.rejected => (
        'مرفوض',
        const Color(0xFFE74C3C),
        const Color(0xFFFDEAEA),
        Icons.close_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      // Figma: icon after Arabic label in visual LTR-export order;
      // under RTL Directionality this places icon on the outer (left) side.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
