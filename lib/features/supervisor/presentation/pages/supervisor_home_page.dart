import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_floating_bottom_nav.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_home_nav.dart';
import 'supervisor_account_tab.dart';
import 'supervisor_dashboard_tab.dart';
import 'supervisor_messages_tab.dart';
import 'supervisor_reports_tab.dart';
import 'supervisor_students_tab.dart';

/// Supervisor shell — 5 tabs: الرئيسية · الطلاب · الرسائل · التقارير · حسابي
class SupervisorHomePage extends StatefulWidget {
  const SupervisorHomePage({super.key});

  @override
  State<SupervisorHomePage> createState() => _SupervisorHomePageState();
}

class _SupervisorHomePageState extends State<SupervisorHomePage> {
  int _currentTab = SupervisorHomeNav.homeIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final uid = authState.user.uid;
    context.read<SupervisorBloc>().add(LoadSupervisedHalaqatEvent(uid));
    sl<NotificationsBloc>().add(
      StartWatchingNotificationsEvent(uid: uid, role: AppRoles.supervisor),
    );
    sl<ChatConversationsBloc>().add(StartWatchingConversationsEvent(
      uid,
      pageSize: ChatConversationsBloc.defaultInboxPageSize,
    ));
  }

  void _switchTab(int index) {
    if (index < 0 || index > SupervisorHomeNav.accountIndex) return;
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SupervisorBloc, SupervisorState>(
          listenWhen: (p, c) =>
              p.issueAchievementStatus != c.issueAchievementStatus,
          listener: (context, state) {
            if (state.issueAchievementStatus == SubmissionStatus.success) {
              AppSnackBar.showSuccess(context, 'تم منح الإنجاز بنجاح');
              context.read<SupervisorBloc>().add(
                const ResetIssueAchievementEvent(),
              );
            } else if (state.issueAchievementStatus == SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.issueAchievementError ?? 'تعذر منح الإنجاز',
              );
            }
          },
        ),
        BlocListener<SupervisorBloc, SupervisorState>(
          listenWhen: (p, c) => p.submitReportStatus != c.submitReportStatus,
          listener: (context, state) {
            if (state.submitReportStatus == SubmissionStatus.success) {
              AppSnackBar.showSuccess(context, 'تم إرسال التقرير');
              context.read<SupervisorBloc>().add(
                const ResetSubmitReportEvent(),
              );
            } else if (state.submitReportStatus == SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.submitReportError ?? 'تعذر إرسال التقرير',
              );
            }
          },
        ),
      ],
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          extendBody: true,
          body: AppFloatingBottomNav.padBody(
            context,
            child: IndexedStack(
              index: _currentTab,
              children: [
                SupervisorDashboardTab(onSwitchTab: _switchTab),
                SupervisorStudentsTab(onSwitchTab: _switchTab),
                const SupervisorMessagesTab(),
                SupervisorReportsTab(onSwitchTab: _switchTab),
                const SupervisorAccountTab(),
              ],
            ),
          ),
          bottomNavigationBar: AppFloatingBottomNav(
            selected: _currentTab,
            onChanged: _switchTab,
            destinations: AppNavIcons.supervisor(SupervisorHomeNav.labels),
          ),
        ),
      ),
    );
  }
}
