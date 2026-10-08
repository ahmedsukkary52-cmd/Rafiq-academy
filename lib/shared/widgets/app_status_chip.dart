import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual tone only — domain statuses map here in feature code.
enum AppStatusTone { success, warning, error, info, neutral }

/// Shared status pill. No payment/domain knowledge.
class AppStatusChip extends StatelessWidget {
  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final double? maxWidth;

  const AppStatusChip({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.maxWidth,
  });

  Color get _color => switch (tone) {
    AppStatusTone.success => AppColors.success,
    AppStatusTone.warning => AppColors.warning,
    AppStatusTone.error => AppColors.error,
    AppStatusTone.info => AppColors.info,
    AppStatusTone.neutral => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      constraints: maxWidth == null
          ? null
          : BoxConstraints(maxWidth: maxWidth!),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
