import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Text(label),
                ],
              ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
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
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
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
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'إعادة المحاولة',
                onPressed: onRetry,
                width: 160,
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
        Positioned(
          top: -4,
          right: -4,
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
