import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Placeholder tab — posts are not implemented for teachers yet.
class TeacherPostsTab extends StatelessWidget {
  const TeacherPostsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('المنشورات')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Text(
            'المنشورات غير متاحة حالياً',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
