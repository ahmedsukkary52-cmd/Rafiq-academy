import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../parent_home_nav.dart';
import 'parent_children_page.dart';
import 'parent_dashboard_tab.dart';
import 'parent_messages_tab.dart';
import 'parent_profile_tab.dart';
import 'parent_subscriptions_page.dart';

/// Parent shell — 5 tabs: الرئيسية · أبنائي · الرسائل · المتجر · الحساب
class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  int _currentTab = ParentHomeNav.homeIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final uid = authState.user.uid;
    context.read<ParentBloc>().add(LoadChildrenEvent(uid));
    sl<NotificationsBloc>().add(
      StartWatchingNotificationsEvent(uid: uid, role: AppRoles.parent),
    );
    sl<ChatConversationsBloc>().add(StartWatchingConversationsEvent(uid));
  }

  void _switchTab(int index) {
    if (index < 0 || index > ParentHomeNav.accountIndex) return;
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
            ParentDashboardTab(onSwitchTab: _switchTab),
            const ParentChildrenPage(),
            const ParentMessagesTab(),
            const ParentSubscriptionsPage(embedded: true),
            ParentProfileTab(onSwitchTab: _switchTab),
          ],
        ),
        bottomNavigationBar: _ParentBottomNav(
          selected: _currentTab,
          onChanged: _switchTab,
        ),
      ),
    );
  }
}

class _ParentBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ParentBottomNav({required this.selected, required this.onChanged});

  static const _icons = [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.chat_bubble_outline,
    Icons.storefront_outlined,
    Icons.person_outline,
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
            children: List.generate(ParentHomeNav.labels.length, (i) {
              final isSelected = i == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i == ParentHomeNav.messagesIndex)
                        BlocSelector<
                          ChatConversationsBloc,
                          ChatConversationsState,
                          int
                        >(
                          bloc: sl<ChatConversationsBloc>(),
                          selector: (state) => state.totalUnreadCount,
                          builder: (context, unread) {
                            return NotificationBadge(
                              count: unread,
                              child: Icon(
                                _icons[i],
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: AppSizes.iconL,
                              ),
                            );
                          },
                        )
                      else
                        Icon(
                          _icons[i],
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: AppSizes.iconL,
                        ),
                      const SizedBox(height: 3),
                      Text(
                        ParentHomeNav.labels[i],
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
