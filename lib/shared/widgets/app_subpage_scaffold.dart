import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_back_button.dart';

/// Shared subpage chrome: header + back + title + body.
/// Does not own navigation policy beyond [AppBackButton] pop.
class AppSubpageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? headerColor;
  final Color? foregroundColor;
  final VoidCallback? onBack;

  const AppSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.backgroundColor,
    this.headerColor,
    this.foregroundColor,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.background;
    final headerBg = headerColor ?? bg;
    final fg = foregroundColor ?? AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          ColoredBox(
            color: headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    AppBackButton(
                      circular: true,
                      color: fg,
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: fg,
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
    );
  }
}
