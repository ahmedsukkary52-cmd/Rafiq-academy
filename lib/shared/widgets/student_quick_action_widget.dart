import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Quick actions — Figma home: مصحفي / المراجعة / المعلم / خريطتي (square tiles).
class StudentQuickActionsWidget extends StatelessWidget {
  final VoidCallback onMushafTap;
  final VoidCallback onReviewTap;
  final VoidCallback onTeacherTap;
  final VoidCallback onMapTap;

  const StudentQuickActionsWidget({
    super.key,
    required this.onMushafTap,
    required this.onReviewTap,
    required this.onTeacherTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionItem(
            icon: Icons.menu_book_rounded,
            label: 'مصحفي',
            onTap: onMushafTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionItem(
            icon: Icons.sync_rounded,
            label: 'المراجعة',
            onTap: onReviewTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionItem(
            icon: Icons.school_rounded,
            label: 'المعلم',
            onTap: onTeacherTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionItem(
            icon: Icons.map_outlined,
            label: 'خريطتي',
            onTap: onMapTap,
          ),
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
