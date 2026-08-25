import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Shared stacked-page chrome for Supervisor (mirrors ParentSubpageScaffold).
class SupervisorSubpageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color? backgroundColor;

  const SupervisorSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.background;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            ColoredBox(
              color: AppColors.surface,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (actions != null && actions!.isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, children: actions!)
                      else
                        const SizedBox(width: 44, height: 44),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceGrey,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
