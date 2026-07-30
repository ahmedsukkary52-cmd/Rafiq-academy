import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';

/// Admin home.
///
/// H6 / A-H9: do **not** wire stats / finance / complaints / broadcast /
/// teacher-management AdminBloc events here — those writers are quarantined
/// (no product UI). Keep this surface free of parallel ops delivery.
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('نافذة المدير')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 48,
                color: AppColors.textHint,
              ),
              SizedBox(height: 16),
              Text(
                'نافذة المدير',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Coming Soon',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
