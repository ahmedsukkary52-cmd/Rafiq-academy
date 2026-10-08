import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/theme/app_theme.dart';

/// Parent thin wrapper around [AppSubpageScaffold] (stable import path).
class ParentSubpageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? headerColor;
  final Color? foregroundColor;

  const ParentSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.backgroundColor,
    this.headerColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppSubpageScaffold(
      title: title,
      body: body,
      actions: actions,
      backgroundColor: backgroundColor,
      headerColor: headerColor,
      foregroundColor: foregroundColor,
    );
  }
}

/// Parent thin wrapper around [AppEmptyState] (stable import path).
class ParentEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const ParentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(icon: icon, title: title, message: message);
  }
}

class ParentFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ParentFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.onPrimary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
