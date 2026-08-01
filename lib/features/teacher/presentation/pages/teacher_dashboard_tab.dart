import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
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

class TeacherDashboardTab extends StatelessWidget {
  const TeacherDashboardTab({super.key});

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
                child: _TeacherHeader(
                  name: teacherName,
                  halaqaName: nextHalaqa?.name ?? '',
                  imageUrl: auth?.user.profileImageUrl,
                ),
              ),
              // Figma: white sheet with convex top corners overlapping the header
              // (not a rounded bottom on the teal block).
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _bodyChildren(context, state),
                    ),
                  ),
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
      return [
        const SizedBox(
          height: 220,
          child: AppLoadingWidget(),
        ),
      ];
    }

    if (state.halaqatStatus == SectionStatus.error) {
      return [
        SizedBox(
          height: 220,
          child: AppErrorWidget(
            message: state.halaqatError ?? 'تعذر تحميل الحلقات',
            onRetry: () => _retryHalaqat(context),
          ),
        ),
      ];
    }

    final totalStudents = state.halaqat.fold<int>(
      0,
      (sum, h) => sum + h.studentIds.length,
    );
    final sessionsToday = state.todayAgenda.sessionsTodayCount;
    final pendingTasks = state.todayAgenda.items.fold<int>(
      0,
      (sum, item) => sum + item.pendingActions.length,
    );

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingM,
          20,
          AppSizes.paddingM,
          0,
        ),
        child: BlocSelector<ChatConversationsBloc, ChatConversationsState, int>(
          bloc: sl<ChatConversationsBloc>(),
          selector: (s) => s.totalUnreadCount,
          builder: (context, unreadMessages) {
            return _TeacherStatsGrid(
              studentsCount: totalStudents,
              sessionsToday: sessionsToday,
              pendingTasks: pendingTasks,
              newMessages: unreadMessages,
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingM,
          16,
          AppSizes.paddingM,
          AppSizes.paddingM,
        ),
        child: _TodaySessionSection(
          status: state.todayAgendaStatus,
          agenda: state.todayAgenda,
          error: state.todayAgendaError,
          onRetry: () =>
              context.read<TeacherBloc>().add(const LoadTodayAgendaEvent()),
        ),
      ),
    ];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TodaySessionSection — Figma 1:432 Today's Session card
//
// Presentation only: uses TeacherDayAgenda.featuredSession from GetTodayAgendaUseCase.
// Room omitted until HalaqaEntity exposes it. No agenda-list UI.
// ══════════════════════════════════════════════════════════════════════════════

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

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SectionStatus.initial:
      case SectionStatus.loading:
        return const _SessionCardShell(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.onPrimaryMuted,
                ),
              ),
            ),
          ),
        );
      case SectionStatus.error:
        return _EmptySessionCard(
          message: error ?? 'تعذر تحميل جلسة اليوم',
          onRetry: onRetry,
        );
      case SectionStatus.loaded:
        final session = agenda.featuredSession;
        if (session == null) {
          return const _EmptySessionCard(
            message: 'لا توجد حصص مجدوَلة اليوم',
          );
        }
        return _TodaySessionCard(session: session);
    }
  }
}

class _TodaySessionCard extends StatelessWidget {
  final TeacherTodaySession session;

  const _TodaySessionCard({required this.session});

  void _startSession(BuildContext context) {
    context.read<TeacherBloc>().add(SelectHalaqaEvent(session.halaqaId));
    context.push('/teacher/halaqa/${session.halaqaId}');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _SessionCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.onPrimaryMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'اليوم — ${formatTimeHm12Ar(session.startAt)}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              session.halaqaName,
              textAlign: TextAlign.right,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: AppColors.onPrimaryMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${session.studentCount} طالباً',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _StartSessionButton(onTap: () => _startSession(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartSessionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StartSessionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 22,
                  color: AppColors.onPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'ابدأ الجلسة',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySessionCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _EmptySessionCard({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _SessionCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.onPrimaryMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'اليوم',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.right,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'إعادة المحاولة',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}

class _SessionCardShell extends StatelessWidget {
  final Widget child;

  const _SessionCardShell({required this.child});

  /// Matches Figma featured-card radius (~28) used by the Home sheet overlap.
  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TeacherHeader — Figma 1:432 (Commit 1 polish)
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherHeader extends StatelessWidget {
  final String name;
  final String halaqaName;
  final String? imageUrl;

  const _TeacherHeader({
    required this.name,
    required this.halaqaName,
    this.imageUrl,
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

    // Extra bottom padding so the overlapping white sheet (radius 28) sits
    // correctly over the teal without clipping header content.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 14,
          left: AppSizes.paddingM,
          right: AppSizes.paddingM,
          bottom: 44,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
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
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                BlocSelector<NotificationsBloc, NotificationsState, int>(
                  bloc: sl<NotificationsBloc>(),
                  selector: (state) => state.unreadCount,
                  builder: (context, unreadCount) {
                    // Force LTR icon order: Search → Notifications (Figma).
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
            const SizedBox(height: 22),
            Text(
              'السلام عليكم 🌿',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'يوم $dayName مبارك!',
              textAlign: TextAlign.right,
              style: AppTextStyles.displayMedium.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 26,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.onPrimaryOverlay,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  _hijriChipLabel(),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimary,
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
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.onPrimaryOverlay,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.onPrimary, size: 22),
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

// ══════════════════════════════════════════════════════════════════════════════
// _TeacherStatsGrid — Figma 1:432 (Commit 2)
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherStatsGrid extends StatelessWidget {
  final int studentsCount;
  final int sessionsToday;
  final int pendingTasks;
  final int newMessages;

  const _TeacherStatsGrid({
    required this.studentsCount,
    required this.sessionsToday,
    required this.pendingTasks,
    required this.newMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: sessionsToday,
                  label: 'حصص اليوم',
                  icon: Icons.calendar_today_outlined,
                  iconBg: AppColors.primaryLight,
                  iconColor: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  value: studentsCount,
                  label: 'إجمالي الطلاب',
                  icon: Icons.person_outline_rounded,
                  iconBg: AppColors.successBg,
                  iconColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: pendingTasks,
                  label: 'مهام معلقة',
                  icon: Icons.checklist_rtl_rounded,
                  iconBg: AppColors.secondaryBg,
                  iconColor: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  value: newMessages,
                  label: 'رسائل جديدة',
                  icon: Icons.chat_bubble_outline_rounded,
                  iconBg: AppColors.messagesBg,
                  iconColor: AppColors.awardWeekly,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            textAlign: TextAlign.right,
            style: AppTextStyles.displayMedium.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.right,
            style: AppTextStyles.labelMedium.copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}
