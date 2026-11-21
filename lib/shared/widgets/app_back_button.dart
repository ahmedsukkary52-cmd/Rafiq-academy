import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Production-safe Back affordance for Arabic RTL (UI-1).
///
/// Uses a chevron that points toward the leading edge (the exit direction):
/// [Icons.chevron_left_rounded], which [Icon] mirrors under RTL (see [iconFor]).
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

  /// [Icons.chevron_left_rounded] has `matchTextDirection: true`, so [Icon]
  /// mirrors it under RTL: it points right (toward the leading edge) in RTL
  /// and left in LTR. Picking chevron_right for RTL would be mirrored to
  /// point left, i.e. reversed.
  static IconData iconFor(TextDirection direction) {
    return Icons.chevron_left_rounded;
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
      // Light icons on dark headers need translucent chrome — solid white
      // reads as an empty square when the chevron contrast fails.
      final onDark = resolvedColor.computeLuminance() > 0.72;
      return Tooltip(
        message: tooltip,
        child: Material(
          color: onDark
              ? Colors.white.withValues(alpha: 0.16)
              : AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: handle,
            customBorder: const CircleBorder(),
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
