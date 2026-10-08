import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_quick_action_grid.dart';
import '../../../../shared/widgets/confirm_logout.dart';

/// Admin home — P0-02 operational hub. Each action opens a focused subpage
/// backed by an authoritative callable; there is no aggregate dashboard.
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  static const actionLabels = <String>[
    'إنشاء حساب',
    'ربط ولي أمر بطالب',
    'الحلقات والمواعيد',
    'قبول ونقل الطلاب',
    'مراجعة إيصالات الدفع',
    'إعادة تفعيل الوصول',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('نافذة المدير'),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => confirmAndLogout(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          children: [
            Text('العمليات الإدارية', style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text(
              'كل عملية تُنفَّذ عبر الخادم مع التحقق من الصلاحيات وتسجيلها.',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            AppQuickActionGrid(
              items: [
                AppQuickActionItem(
                  icon: Icons.person_add_alt_1_rounded,
                  label: actionLabels[0],
                  color: AppColors.primary,
                  onTap: () => context.push(AppRoutes.adminAccounts),
                ),
                AppQuickActionItem(
                  icon: Icons.family_restroom_rounded,
                  label: actionLabels[1],
                  color: AppColors.secondary,
                  onTap: () => context.push(AppRoutes.adminParentLinks),
                ),
                AppQuickActionItem(
                  icon: Icons.groups_rounded,
                  label: actionLabels[2],
                  color: AppColors.success,
                  onTap: () => context.push(AppRoutes.adminHalaqat),
                ),
                AppQuickActionItem(
                  icon: Icons.swap_horiz_rounded,
                  label: actionLabels[3],
                  color: AppColors.info,
                  onTap: () => context.push(AppRoutes.adminMembership),
                ),
                AppQuickActionItem(
                  icon: Icons.receipt_long_rounded,
                  label: actionLabels[4],
                  color: AppColors.warning,
                  onTap: () => context.push(AppRoutes.adminPayments),
                ),
                AppQuickActionItem(
                  icon: Icons.lock_open_rounded,
                  label: actionLabels[5],
                  color: AppColors.error,
                  onTap: () => context.push(AppRoutes.adminAccess),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
