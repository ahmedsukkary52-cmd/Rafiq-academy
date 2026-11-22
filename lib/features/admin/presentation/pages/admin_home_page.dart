import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_floating_bottom_nav.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../admin_home_nav.dart';
import 'admin_dashboard_tab.dart';
import 'admin_finance_tab.dart';
import 'admin_management_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_students_tab.dart';
import '../widgets/admin_bottom_nav.dart';

/// Admin shell — 5-tab IA matching Figma designs.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  /// P0-02 callable-backed operations, surfaced on the management tab.
  /// Access reactivation lives only under Settings (not duplicated here).
  static const actionLabels = <String>[
    'إنشاء حساب موظف',
    'ربط ولي أمر بطالب',
    'الحلقات والمواعيد',
    'تعيين طالب لحلقة',
    'مراجعة إيصالات الدفع',
  ];

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentTab = AdminHomeNav.dashboardIndex;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<NotificationsBloc>().add(
        StartWatchingNotificationsEvent(
          uid: auth.user.uid,
          role: AppRoles.admin,
        ),
      );
    }
  }

  void _switchTab(int index) {
    if (index == _currentTab) return;
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: AppFloatingBottomNav.padBody(
          context,
          child: IndexedStack(
            index: _currentTab,
            children: [
              AdminDashboardTab(onSwitchTab: _switchTab),
              const AdminStudentsTab(),
              const AdminManagementTab(),
              const AdminFinanceTab(),
              const AdminSettingsTab(),
            ],
          ),
        ),
        bottomNavigationBar: AdminBottomNav(
          selected: _currentTab,
          onChanged: _switchTab,
        ),
      ),
    );
  }
}
