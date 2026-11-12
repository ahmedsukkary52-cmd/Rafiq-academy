import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'app_routes.dart';

/// Shown for unknown or malformed links; never echoes the raw router error.
class RouteNotFoundPage extends StatelessWidget {
  const RouteNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الصفحة غير متاحة')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.link_off_rounded,
                color: AppColors.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'هذه الصفحة غير موجودة أو لم تعد متاحة.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'العودة إلى الرئيسية',
                onPressed: () => context.go(AppRoutes.splash),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
