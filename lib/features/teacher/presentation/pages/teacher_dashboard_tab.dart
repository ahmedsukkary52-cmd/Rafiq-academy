import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../domain/read_models/teacher_day_agenda.dart';
import '../../presentation/bloc/teacher_bloc.dart';
import '../../presentation/bloc/teacher_event.dart';
import '../../presentation/bloc/teacher_state.dart';
import '../widgets/teacher_home_figma_cards.dart';

/// Figma 1:432 Teacher Home body (full screen composition).
class TeacherDashboardTab extends StatelessWidget {
  final ValueChanged<int>? onSwitchTab;
  final int tabStudents;
  final int tabMessages;
  final int tabProfile;

  /// Temporary preview copy until admin announcements are wired to Firestore.
  final String adminAnnouncement;

  const TeacherDashboardTab({
    super.key,
    this.onSwitchTab,
    this.tabStudents = 1,
    this.tabMessages = 3,
    this.tabProfile = 4,
    this.adminAnnouncement =
        'تذكير: موعد رفع التقييمات الشهرية غداً قبل الساعة 12 ظهراً',
  });

  void _retryHalaqat(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<TeacherBloc>().add(LoadTeacherHalaqatEvent(auth.user.uid));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final auth = authState is AuthAuthenticated ? authState : null;
    final teacherName = auth?.user.name ?? '';

    return BlocBuilder<TeacherBloc, TeacherState>(
      buildWhen: (previous, current) =>
          previous.halaqat != current.halaqat ||
          previous.halaqatStatus != current.halaqatStatus ||
          previous.halaqatError != current.halaqatError ||
          previous.todayAgenda != current.todayAgenda ||
          previous.todayAgendaStatus != current.todayAgendaStatus ||
          previous.todayAgendaError != current.todayAgendaError,
      builder: (context, state) {
        final halaqat = state.halaqat;
        final nextHalaqa = halaqat.isNotEmpty ? halaqat.first : null;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (auth == null) return;
            final bloc = context.read<TeacherBloc>();
            bloc.add(LoadTeacherHalaqatEvent(auth.user.uid));
            await bloc.stream.firstWhere((s) {
              if (s.halaqatStatus == SectionStatus.error) return true;
              if (s.halaqatStatus != SectionStatus.loaded) return false;
              return s.todayAgendaStatus == SectionStatus.loaded ||
                  s.todayAgendaStatus == SectionStatus.error;
            });
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // 1. Background Gradient for the header area
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 340,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                      ),
                    ),
                    // 2. Main Content
                    Column(
                      children: [
                        _TeacherHeader(
                          name: teacherName,
                          halaqaName: nextHalaqa?.name ?? '',
                          imageUrl: auth?.user.profileImageUrl,
                          onProfileTap: onSwitchTab == null
                              ? null
                              : () => onSwitchTab!(tabProfile),
                        ),
                        // Overlapping Body
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(AppSizes.radiusXL),
                              topRight: Radius.circular(AppSizes.radiusXL),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _bodyChildren(context, state),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _bodyChildren(BuildContext context, TeacherState state) {
    if (state.halaqatStatus == SectionStatus.initial ||
        state.halaqatStatus == SectionStatus.loading) {
      return const [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: _HomeBodySkeleton(),
        ),
      ];
    }

    if (state.halaqatStatus == SectionStatus.error) {
      return [
        SizedBox(
          height: 240,
          child: AppErrorWidget(
            message: state.halaqatError ?? 'تعذر تحميل الحلقات',
            onRetry: () => _retryHalaqat(context),
          ),
        ),
      ];
    }

    final totalStudents = state.halaqat
        .expand((h) => h.studentIds)
        .toSet()
        .length;
    final sessionsToday = state.todayAgenda.sessionsTodayCount;
    final pendingTasks = state.todayAgenda.items.fold<int>(
      0,
      (sum, item) => sum + item.pendingActions.length,
    );
    final agenda = state.todayAgenda;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: BlocSelector<ChatConversationsBloc, ChatConversationsState, int>(
          bloc: sl<ChatConversationsBloc>(),
          selector: (s) => s.totalUnreadCount,
          builder: (context, unreadMessages) {
            return TeacherHomeStatsGrid(
              studentsCount: totalStudents,
              sessionsToday: sessionsToday,
              pendingTasks: pendingTasks,
              newMessages: unreadMessages,
              onSessionsTap: onSwitchTab == null
                  ? null
                  : () => onSwitchTab!(tabStudents),
              onStudentsTap: onSwitchTab == null
                  ? null
                  : () => onSwitchTab!(tabStudents),
              onPendingTap: () => _openFirstPendingAction(context, agenda),
              onMessagesTap: onSwitchTab == null
                  ? null
                  : () => onSwitchTab!(tabMessages),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: _TodaySessionSection(
          status: state.todayAgendaStatus,
          agenda: agenda,
          error: state.todayAgendaError,
          onRetry: () =>
              context.read<TeacherBloc>().add(const LoadTodayAgendaEvent()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: TeacherHomeAnnouncementBanner(message: adminAnnouncement),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: TeacherHomeRecentActivities(
          items: _previewActivities,
          onSeeAll: onSwitchTab == null
              ? null
              : () => onSwitchTab!(tabStudents),
        ),
      ),
    ];
  }

  /// Temporary Figma preview rows — replace with Firestore feed later.
  static const _previewActivities = <TeacherHomeActivityVm>[
    TeacherHomeActivityVm(
      title: 'تقييم أحمد محمد',
      subtitle: 'ممتاز',
      icon: Icons.star_rounded,
      iconBg: AppColors.successBg,
      iconColor: AppColors.success,
      timeLabel: 'منذ ساعة',
    ),
    TeacherHomeActivityVm(
      title: 'تسجيل حضور',
      subtitle: 'حلقة الفجر',
      icon: Icons.how_to_reg_outlined,
      iconBg: AppColors.primaryLight,
      iconColor: AppColors.primaryDark,
      timeLabel: 'منذ ساعتين',
    ),
    TeacherHomeActivityVm(
      title: 'منح شارة "المتفوق"',
      subtitle: 'سارة علي',
      icon: Icons.military_tech_outlined,
      iconBg: AppColors.secondaryBg,
      iconColor: AppColors.secondary,
      timeLabel: 'أمس',
    ),
  ];

  void _openFirstPendingAction(BuildContext context, TeacherDayAgenda agenda) {
    for (final item in agenda.items) {
      if (item.pendingActions.isEmpty) continue;
      context.push(_routeFor(item.pendingActions.first, item.halaqaId));
      return;
    }
    onSwitchTab?.call(tabStudents);
  }

  String _routeFor(TeacherAgendaAction action, String halaqaId) =>
      switch (action) {
        TeacherAgendaAction.takeAttendance => '/teacher/attendance/$halaqaId',
        TeacherAgendaAction.sendHomework =>
          '/teacher/halaqa/$halaqaId?assign=1',
        TeacherAgendaAction.reviewRecitations =>
          '/teacher/halaqa/$halaqaId/evaluations',
      };
}

class _TodaySessionSection extends StatelessWidget {
  final SectionStatus status;
  final TeacherDayAgenda agenda;
  final String? error;
  final VoidCallback onRetry;

  const _TodaySessionSection({
    required this.status,
    required this.agenda,
    required this.error,
    required this.onRetry,
  });

  void _startSession(BuildContext context, TeacherTodaySession session) {
    context.read<TeacherBloc>().add(SelectHalaqaEvent(session.halaqaId));
    context.push('/teacher/halaqa/${session.halaqaId}');
  }

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SectionStatus.initial:
      case SectionStatus.loading:
        return TeacherHomeSessionCard.empty();
      case SectionStatus.error:
        return TeacherHomeSessionCard.error(
          message: error ?? 'تعذر تحميل جلسة اليوم',
          onRetry: onRetry,
        );
      case SectionStatus.loaded:
        final session = agenda.featuredSession;
        if (session == null) {
          return TeacherHomeSessionCard.empty();
        }
        return TeacherHomeSessionCard.filled(
          halaqaName: session.halaqaName,
          startAt: session.startAt,
          studentCount: session.studentCount,
          onStart: () => _startSession(context, session),
        );
    }
  }
}

class _HomeBodySkeleton extends StatelessWidget {
  const _HomeBodySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box({double height = 100}) => Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: box(height: 120)),
            const SizedBox(width: 12),
            Expanded(child: box(height: 120)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: box(height: 120)),
            const SizedBox(width: 12),
            Expanded(child: box(height: 120)),
          ],
        ),
        const SizedBox(height: 16),
        box(height: 160),
        const SizedBox(height: 16),
        box(height: 140),
        const SizedBox(height: 16),
        box(height: 160),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Header
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherHeader extends StatelessWidget {
  final String name;
  final String halaqaName;
  final String? imageUrl;
  final VoidCallback? onProfileTap;

  const _TeacherHeader({
    required this.name,
    required this.halaqaName,
    this.imageUrl,
    this.onProfileTap,
  });

  static const _weekdays = [
    '',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  String _hijriChipLabel() {
    HijriCalendar.setLocal('ar');
    return HijriCalendar.now().toFormat('dd MMMM yyyy');
  }

  @override
  Widget build(BuildContext context) {
    final dayName = _weekdays[DateTime.now().weekday];
    final displayName = name.trim().isEmpty ? 'المعلم' : name.trim();
    final subtitle = halaqaName.trim().isEmpty
        ? 'معلم تحفيظ'
        : 'معلم تحفيظ · $halaqaName';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        // Gradient is now handled by the Stack background in the parent
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          bottom: 40, // Keeps some space for the overlap look
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    child: Row(
                      children: [
                        UserAvatar(
                          name: displayName,
                          imageUrl: imageUrl,
                          size: 44,
                          backgroundColor: AppColors.onPrimaryOverlay,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الأستاذ $displayName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.onPrimaryMuted,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BlocSelector<NotificationsBloc, NotificationsState, int>(
                  bloc: sl<NotificationsBloc>(),
                  selector: (state) => state.unreadCount,
                  builder: (context, unreadCount) {
                    return Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeaderCircleButton(
                            icon: Icons.search_rounded,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('قريباً')),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _HeaderCircleButton(
                            icon: Icons.notifications_outlined,
                            showDot: unreadCount > 0,
                            onTap: () =>
                                context.push(AppRoutes.teacherNotifs),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'السلام عليكم 🌿',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'يوم $dayName مبارك!',
              textAlign: TextAlign.right,
              style: AppTextStyles.displayLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 28,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.onPrimaryOverlay,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  teacherHomeEasternDigits(_hijriChipLabel()),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.onPrimaryOverlay,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.onPrimary, size: 20),
            ),
            if (showDot)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.onPrimary, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
