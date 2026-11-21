import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared search field chrome. Query logic stays in the caller.
///
/// App-wide standard: fixed height 48, bordered surface, clear affordance.
class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool showClear;
  final bool autofocus;
  final bool enabled;
  final Widget? trailing;

  const AppSearchField({
    super.key,
    this.controller,
    required this.hint,
    this.onChanged,
    this.onClear,
    this.showClear = true,
    this.autofocus = false,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final field = SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textHint,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 22,
            color: AppColors.textSecondary,
          ),
          suffixIcon: showClear && controller != null
              ? ListenableBuilder(
                  listenable: controller!,
                  builder: (context, _) {
                    if (controller!.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: 'مسح',
                      onPressed: () {
                        controller?.clear();
                        onChanged?.call('');
                        onClear?.call();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                    );
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );

    if (trailing == null) return field;

    return Row(
      children: [
        trailing!,
        const SizedBox(width: 10),
        Expanded(child: field),
      ],
    );
  }
}
