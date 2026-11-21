import 'package:flutter/material.dart';

import '../../core/error/user_facing_error.dart';
import '../theme/app_theme.dart';

export 'app_search_field.dart';

/// Forward CTA arrow — mirrors in RTL (points left under Arabic layout).
class AppForwardIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const AppForwardIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.arrow_forward_rounded, size: size, color: color);
  }
}

/// Trailing “go” chevron for list rows — points left (into the page) in RTL.
class AppGoChevron extends StatelessWidget {
  final double size;
  final Color? color;

  const AppGoChevron({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    // Force LTR so chevron_left is not mirrored into pointing right.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Icon(Icons.chevron_left_rounded, size: size, color: color),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AppButton - زرار موحّد للتطبيق
// ══════════════════════════════════════════════════════════════════════════════

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final Widget? leading;
  final Widget? trailing;
  final Gradient? gradient;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 52,
    this.leading,
    this.trailing,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Colors.white;
    // Default primary CTA uses the brand gradient unless a flat [backgroundColor]
    // is set or an explicit [gradient] is provided.
    final effectiveGradient =
        gradient ??
        (backgroundColor == null ? AppColors.primaryGradient : null);
    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: fg, strokeWidth: 2.5),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontFamily: AppTextStyles.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          );

    if (effectiveGradient != null) {
      final enabled = !isLoading && onPressed != null;
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled ? effectiveGradient : null,
            color: enabled ? null : AppColors.border,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              child: Center(child: child),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: fg,
        ),
        child: child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AppTextField - حقل إدخال موحّد
// ══════════════════════════════════════════════════════════════════════════════

class AppTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AppCard - كارت موحّد
// ══════════════════════════════════════════════════════════════════════════════

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final VoidCallback? onTap;
  final double? borderRadius;
  final bool hasBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.borderRadius,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius ?? AppSizes.radiusL),
          border: hasBorder ? Border.all(color: AppColors.border) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// UserAvatar - صورة المستخدم الدائرية مع حرف افتراضي
// ══════════════════════════════════════════════════════════════════════════════

class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AppSizes.avatarM,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '؟';

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AppColors.primary,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GradeChip - بادج التقييم (ممتاز، جيد جداً...)
// ══════════════════════════════════════════════════════════════════════════════

class GradeChip extends StatelessWidget {
  final String label;

  const GradeChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _colorForGrade(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _colorForGrade(String label) => switch (label) {
    'ممتاز' => AppColors.gradeExcellent,
    'جيد جداً' => AppColors.gradeVeryGood,
    'جيد' => AppColors.gradeGood,
    'يحتاج تحسين' => AppColors.gradeNeedsWork,
    'قيد المراجعة' => AppColors.textSecondary,
    _ => AppColors.gradeGood,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// SectionHeader - عنوان قسم مع زرار "الكل"
// ══════════════════════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleLarge),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AppSnackBar - رسائل النظام الموحّدة
// ══════════════════════════════════════════════════════════════════════════════

class AppSnackBar {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    final text = userFacingErrorText(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.right),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LoadingWidget + ErrorWidget
// ══════════════════════════════════════════════════════════════════════════════

class AppLoadingWidget extends StatelessWidget {
  const AppLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PulseLoadingSkeleton();
  }
}

class _PulseLoadingSkeleton extends StatefulWidget {
  const _PulseLoadingSkeleton();

  @override
  State<_PulseLoadingSkeleton> createState() => _PulseLoadingSkeletonState();
}

class _PulseLoadingSkeletonState extends State<_PulseLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bone = AppColors.border.withValues(alpha: _pulse.value);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: bone,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              userFacingErrorText(message),
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'إعادة المحاولة',
                onPressed: onRetry,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NotificationBadge - عداد الإشعارات على الأيقونة
// ══════════════════════════════════════════════════════════════════════════════

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          top: -4,
          end: -4,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
