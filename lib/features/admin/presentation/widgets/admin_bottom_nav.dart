import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_floating_bottom_nav.dart';
import '../admin_home_nav.dart';

class AdminBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const AdminBottomNav({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppFloatingBottomNav(
      selected: selected,
      onChanged: onChanged,
      destinations: AppNavIcons.admin(AdminHomeNav.labels),
    );
  }
}
