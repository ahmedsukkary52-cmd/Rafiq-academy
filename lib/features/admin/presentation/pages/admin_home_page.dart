import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
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

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentTab = AdminHomeNav.dashboardIndex;

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
        body: IndexedStack(
          index: _currentTab,
          children: [
            AdminDashboardTab(onSwitchTab: _switchTab),
            const AdminStudentsTab(),
            const AdminManagementTab(),
            const AdminFinanceTab(),
            const AdminSettingsTab(),
          ],
        ),
        bottomNavigationBar: AdminBottomNav(
          selected: _currentTab,
          onChanged: _switchTab,
        ),
      ),
    );
  }
}
