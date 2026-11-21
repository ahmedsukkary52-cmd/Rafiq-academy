import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_floating_bottom_nav.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../parent_home_nav.dart';
import 'parent_children_page.dart';
import 'parent_dashboard_tab.dart';
import 'parent_messages_tab.dart';
import 'parent_profile_tab.dart';
import 'parent_subscriptions_page.dart';

/// Parent shell — 5 tabs: الرئيسية · أبنائي · الرسائل · المدفوعات · الحساب
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
    context.read<ParentBloc>().add(LoadPaymentsEvent(uid));
    sl<NotificationsBloc>().add(
      StartWatchingNotificationsEvent(uid: uid, role: AppRoles.parent),
    );
    sl<ChatConversationsBloc>().add(StartWatchingConversationsEvent(
      uid,
      pageSize: ChatConversationsBloc.defaultInboxPageSize,
    ));
  }

  void _switchTab(int index) {
    if (index < 0 || index > ParentHomeNav.accountIndex) return;
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      extendBody: true,
      body: AppFloatingBottomNav.padBody(
        context,
        child: IndexedStack(
          index: _currentTab,
          children: [
            ParentDashboardTab(onSwitchTab: _switchTab),
            const ParentChildrenPage(),
            const ParentMessagesTab(),
            ParentSubscriptionsPage(embedded: true, onSwitchTab: _switchTab),
            ParentProfileTab(onSwitchTab: _switchTab),
          ],
        ),
      ),
      bottomNavigationBar: BlocSelector<
        ChatConversationsBloc,
        ChatConversationsState,
        int
      >(
        bloc: sl<ChatConversationsBloc>(),
        selector: (state) => state.totalUnreadCount,
        builder: (context, unread) {
          final base = AppNavIcons.parent(ParentHomeNav.labels);
          final destinations = [
            for (var i = 0; i < base.length; i++)
              if (i == ParentHomeNav.messagesIndex)
                AppNavDestination(
                  icon: base[i].icon,
                  selectedIcon: base[i].selectedIcon,
                  label: base[i].label,
                  badge: unread > 0
                      ? Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                )
              else
                base[i],
          ];
          return AppFloatingBottomNav(
            selected: _currentTab,
            onChanged: _switchTab,
            destinations: destinations,
          );
        },
      ),
    );
  }
}
