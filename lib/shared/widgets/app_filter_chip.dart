import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill filter chip used by list filters (Admin, complaints).
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool disabled;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: AppColors.softShadow,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
