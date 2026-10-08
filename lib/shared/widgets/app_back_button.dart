import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Production-safe Back affordance for Arabic RTL (UI-1).
///
/// Uses a chevron that points toward the leading edge exit direction:
/// RTL → [Icons.chevron_right_rounded], LTR → [Icons.chevron_left_rounded].
/// Prefer this over raw [Icons.arrow_back] / mixed chevrons.
class AppBackButton extends StatelessWidget {
  /// Optional override; defaults to router/navigator pop.
  final VoidCallback? onPressed;

  final Color? color;
  final double iconSize;
  final String tooltip;

  /// When true, draws the circular chrome used on parent/teacher headers.
  final bool circular;

  /// Square hit target (Material guideline ≥ 44).
  final double size;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.iconSize = 22,
    this.tooltip = 'رجوع',
    this.circular = false,
    this.size = 44,
  });

  /// AppBar [leading] convenience (tight padding).
  const AppBackButton.appBar({
    super.key,
    this.onPressed,
    this.color,
    this.iconSize = 24,
    this.tooltip = 'رجوع',
  }) : circular = false,
       size = kToolbarHeight;

  static IconData iconFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;
  }

  static void pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final icon = iconFor(direction);
    final resolvedColor = color ?? AppColors.textPrimary;
    final handle = onPressed ?? () => pop(context);

    if (circular) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: InkWell(
            onTap: handle,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: resolvedColor, size: iconSize),
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: handle,
      icon: Icon(icon, color: resolvedColor, size: iconSize),
      constraints: BoxConstraints(minWidth: size, minHeight: size),
    );
  }
}
