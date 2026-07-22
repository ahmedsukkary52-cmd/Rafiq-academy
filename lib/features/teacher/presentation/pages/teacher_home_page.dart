import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_classes_page.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_dashboard_tab.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_messages_tab.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_post_tab.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_profile_tab.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../presentation/bloc/teacher_bloc.dart';
import '../../presentation/bloc/teacher_event.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.uid;

    context.read<TeacherBloc>().add(LoadTeacherHalaqatEvent(uid));

    sl<NotificationsBloc>().add(
      StartWatchingNotificationsEvent(uid: uid, role: AppRoles.teacher),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentTab,
        children: const [
          TeacherDashboardTab(),
          TeacherClassesPage(),
          TeacherPostsTab(),
          TeacherMessagesTab(),
          TeacherProfileTab(),
        ],
      ),
      bottomNavigationBar: _TeacherBottomNav(
        selected: _currentTab,
        onChanged: (i) => setState(() => _currentTab = i),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom Navigation
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherBottomNav extends StatelessWidget {
  final int selected;
  final void Function(int) onChanged;

  const _TeacherBottomNav({required this.selected, required this.onChanged});

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'الرئيسية'),
    (icon: Icons.groups_rounded, label: 'الطلاب'),
    (icon: Icons.article_outlined, label: 'المنشورات'),
    (icon: Icons.chat_bubble_outline, label: 'الرسائل'),
    (icon: Icons.person_outline, label: 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      bloc: sl<NotificationsBloc>(),
      builder: (context, notifState) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: AppSizes.bottomNavHeight,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final isSelected = i == selected;
                  // الإشعارات على تاب الرسائل
                  final badge = i == 3 ? notifState.unreadCount : 0;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          NotificationBadge(
                            count: badge,
                            child: Icon(
                              tab.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: AppSizes.iconL,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}
