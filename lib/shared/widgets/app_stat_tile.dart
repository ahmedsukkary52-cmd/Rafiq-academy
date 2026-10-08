import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual layout for [AppStatTile] — presentation only.
enum AppStatTileVariant {
  /// Dashboard card: icon chip + large value + label (Teacher home style).
  dashboard,

  /// Compact grey cell: value + label (mini metrics).
  compact,

  /// Light text on primary/gradient headers (class detail chips).
  onPrimary,
}

/// Shared statistic tile. Callers format values and supply colors/icons.
class AppStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? iconBg;
  final Color? iconColor;
  final VoidCallback? onTap;
  final AppStatTileVariant variant;

  const AppStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.iconBg,
    this.iconColor,
    this.onTap,
    this.variant = AppStatTileVariant.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppStatTileVariant.dashboard => _DashboardStatTile(
        value: value,
        label: label,
        icon: icon,
        iconBg: iconBg,
        iconColor: iconColor,
        onTap: onTap,
      ),
      AppStatTileVariant.compact => _CompactStatTile(
        value: value,
        label: label,
      ),
      AppStatTileVariant.onPrimary => _OnPrimaryStatTile(
        value: value,
        label: label,
      ),
    };
  }
}

class _DashboardStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? iconBg;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _DashboardStatTile({
    required this.value,
    required this.label,
    this.icon,
    this.iconBg,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (icon != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconBg ?? AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor ?? AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    value,
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.displayLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      height: 1.05,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    label,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.25,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactStatTile extends StatelessWidget {
  final String value;
  final String label;

  const _CompactStatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textHint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnPrimaryStatTile extends StatelessWidget {
  final String value;
  final String label;

  const _OnPrimaryStatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.onPrimaryOverlay,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onPrimaryMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight non-scrollable grid of [AppStatTile] (or any widgets).
///
/// Uses [Column]/[Row] rather than [GridView] so callers remain compatible
/// with `pumpAndSettle` (no lingering scrollable tickers).
class AppStatsGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;

  const AppStatsGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += crossAxisCount) {
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: spacing));
      }
      final slice = children
          .skip(i)
          .take(crossAxisCount)
          .toList(growable: false);
      rows.add(
        Row(
          children: [
            for (var j = 0; j < crossAxisCount; j++) ...[
              if (j > 0) SizedBox(width: spacing),
              Expanded(
                child: j < slice.length ? slice[j] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
