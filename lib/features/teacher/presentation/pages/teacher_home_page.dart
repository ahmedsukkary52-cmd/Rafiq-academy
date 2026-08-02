import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_academy/features/post/presentation/pages/posts_list_page.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_classes_page.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_dashboard_tab.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_messages_tab.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_profile_tab.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../presentation/bloc/teacher_bloc.dart';
import '../../presentation/bloc/teacher_event.dart';

/// Figma 1:432 shell — 5 tabs: الرئيسية · الطلاب · المنشورات · الرسائل · حسابي
class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _currentTab = 0;

  static const _tabStudents = 1;
  static const _tabMessages = 3;
  static const _tabProfile = 4;

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

    sl<ChatConversationsBloc>().add(StartWatchingConversationsEvent(uid));
  }

  void _switchTab(int index) {
    if (index < 0 || index > _tabProfile) return;
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentTab,
        children: [
          TeacherDashboardTab(
            onSwitchTab: _switchTab,
            tabStudents: _tabStudents,
            tabMessages: _tabMessages,
            tabProfile: _tabProfile,
          ),
          const TeacherClassesPage(),
          const PostsListPage(halaqaId: 'general'),
          const TeacherMessagesTab(),
          const TeacherProfileTab(),
        ],
      ),
      bottomNavigationBar: _TeacherBottomNav(
        selected: _currentTab,
        onChanged: _switchTab,
      ),
    );
  }
}

class _TeacherBottomNav extends StatelessWidget {
  final int selected;
  final void Function(int) onChanged;

  const _TeacherBottomNav({required this.selected, required this.onChanged});

  static const tabs = [
    (icon: Icons.home_rounded, label: 'الرئيسية'),
    (icon: Icons.groups_rounded, label: 'الطلاب'),
    (icon: Icons.article_outlined, label: 'المنشورات'),
    (icon: Icons.chat_bubble_outline, label: 'الرسائل'),
    (icon: Icons.person_outline, label: 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isSelected = i == selected;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: AppSizes.iconL,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
