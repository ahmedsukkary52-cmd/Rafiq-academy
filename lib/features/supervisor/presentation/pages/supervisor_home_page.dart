import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
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
    sl<ChatConversationsBloc>().add(StartWatchingConversationsEvent(uid));
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
          body: IndexedStack(
            index: _currentTab,
            children: [
              SupervisorDashboardTab(onSwitchTab: _switchTab),
              SupervisorStudentsTab(onSwitchTab: _switchTab),
              const SupervisorMessagesTab(),
              SupervisorReportsTab(onSwitchTab: _switchTab),
              const SupervisorAccountTab(),
            ],
          ),
          bottomNavigationBar: _SupervisorBottomNav(
            selected: _currentTab,
            onChanged: _switchTab,
          ),
        ),
      ),
    );
  }
}

class _SupervisorBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _SupervisorBottomNav({required this.selected, required this.onChanged});

  static const _icons = [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.chat_bubble_outline,
    Icons.insights_outlined,
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
            children: List.generate(_icons.length, (i) {
              final isSelected = selected == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icons[i],
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SupervisorHomeNav.labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontFamily: 'NotoNaskhArabic',
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
  }
}
