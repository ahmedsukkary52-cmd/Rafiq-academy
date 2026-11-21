import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One quick-action entry — presentation data only.
class AppQuickActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final Color? iconColor;
  final VoidCallback? onTap;

  const AppQuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.iconColor,
    this.onTap,
  });
}

/// Visual layout for [AppQuickActionGrid].
enum AppQuickActionLayout {
  /// Parent-style 3-column grid in a surface card.
  grid,

  /// Student-style horizontal row of actions.
  row,
}

/// Shared quick-action chrome. Navigation/policy stay in the caller.
class AppQuickActionGrid extends StatelessWidget {
  final List<AppQuickActionItem> items;
  final AppQuickActionLayout layout;
  final int crossAxisCount;

  const AppQuickActionGrid({
    super.key,
    required this.items,
    this.layout = AppQuickActionLayout.grid,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      AppQuickActionLayout.grid => _GridActions(
        items: items,
        crossAxisCount: crossAxisCount,
      ),
      AppQuickActionLayout.row => _RowActions(items: items),
    };
  }
}

class _GridActions extends StatelessWidget {
  final List<AppQuickActionItem> items;
  final int crossAxisCount;

  const _GridActions({required this.items, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += crossAxisCount) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 8));
      }
      final slice = items.skip(i).take(crossAxisCount).toList(growable: false);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < crossAxisCount; j++) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(
                  child: j < slice.length
                      ? _GridActionCell(item: slice[j])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

class _GridActionCell extends StatelessWidget {
  final AppQuickActionItem item;

  const _GridActionCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: item.iconColor ?? item.color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  final List<AppQuickActionItem> items;

  const _RowActions({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final item in items)
          Expanded(
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.iconColor ?? AppColors.primary,
                        size: AppSizes.iconL,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
