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
      if (state.halaqat.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.paddingM,
            16,
            AppSizes.paddingM,
            24,
          ),
          child: _EmptyHalaqatCard(),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.paddingM,
            16,
            AppSizes.paddingM,
            AppSizes.paddingM,
          ),
          child: _TodayAgendaSection(
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
// _TodayAgendaSection — "ماذا عليّ فعله اليوم؟" (W3 Slice 1)
//
// Composition only: renders the already-derived TeacherDayAgenda view model.
// No computation here; every row deep-links into an existing W1/W2 workflow.
// ══════════════════════════════════════════════════════════════════════════════

class _TodayAgendaSection extends StatelessWidget {
  final SectionStatus status;
  final TeacherDayAgenda agenda;
  final String? error;
  final VoidCallback onRetry;

  const _TodayAgendaSection({
    required this.status,
    required this.agenda,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AgendaHeader(),
        const SizedBox(height: 12),
        _buildBody(context),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (status) {
      case SectionStatus.initial:
      case SectionStatus.loading:
        return const _AgendaCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        );
      case SectionStatus.error:
        return _AgendaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                error ?? 'تعذر تحديد عمل اليوم',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ),
        );
      case SectionStatus.loaded:
        final closeout = agenda.closeout;
        if (!agenda.hasActionableItems) {
          // NoSession or Complete — honest idle/done card (D-C1/D-C5).
          return _CloseoutCard(closeout: closeout);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CloseoutSummary(closeout: closeout),
            const SizedBox(height: 12),
            for (final item in agenda.items) ...[
              _AgendaItemCard(item: item),
              const SizedBox(height: 12),
            ],
          ],
        );
    }
  }
}

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('عمل اليوم', style: AppTextStyles.titleLarge),
        const SizedBox(height: 2),
        Text(
          'ما الذي يحتاج إلى إجراء منك اليوم',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AgendaItemCard extends StatelessWidget {
  final TeacherAgendaItem item;

  const _AgendaItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return _AgendaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatTimeHm12Ar(item.startAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  item.halaqaName,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final action in item.pendingActions)
            _AgendaActionRow(halaqaId: item.halaqaId, action: action),
        ],
      ),
    );
  }
}

class _AgendaActionRow extends StatelessWidget {
  final String halaqaId;
  final TeacherAgendaAction action;

  const _AgendaActionRow({required this.halaqaId, required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(_routeFor(action)),
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textSecondary,
            ),
            const Spacer(),
            Text(
              _labelFor(action),
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(width: 8),
            Icon(_iconFor(action), size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  String _labelFor(TeacherAgendaAction action) => switch (action) {
    TeacherAgendaAction.takeAttendance => 'لم يتم تسجيل الحضور بعد',
    TeacherAgendaAction.sendHomework => 'لم يتم إرسال واجب اليوم',
    TeacherAgendaAction.reviewRecitations => 'توجد تسميعات بانتظار المراجعة',
  };

  IconData _iconFor(TeacherAgendaAction action) => switch (action) {
    TeacherAgendaAction.takeAttendance => Icons.how_to_reg_outlined,
    TeacherAgendaAction.sendHomework => Icons.assignment_outlined,
    TeacherAgendaAction.reviewRecitations => Icons.rate_review_outlined,
  };

  String _routeFor(TeacherAgendaAction action) => switch (action) {
    TeacherAgendaAction.takeAttendance => '/teacher/attendance/$halaqaId',
    // Assign sheet lives on class detail — open via existing query deep-link.
    TeacherAgendaAction.sendHomework => '/teacher/halaqa/$halaqaId?assign=1',
    TeacherAgendaAction.reviewRecitations =>
      '/teacher/halaqa/$halaqaId/evaluations',
  };
}

// ── Day closeout (W3 Slice 4) ────────────────────────────────────────────────
// Pure presentation of TeacherDayAgenda.closeout. No computation, no I/O.
// Neutral, assistive wording only (D9): never blames the teacher.

/// Idle / done state when there are no actionable items.
class _CloseoutCard extends StatelessWidget {
  final TeacherDayCloseout closeout;

  const _CloseoutCard({required this.closeout});

  @override
  Widget build(BuildContext context) {
    final isComplete = closeout.status == DayCloseoutStatus.complete;
    final message = switch (closeout.status) {
      DayCloseoutStatus.noSession => 'لا توجد حصص مجدوَلة اليوم',
      DayCloseoutStatus.complete => 'اكتمل عمل اليوم',
      // Defensive: incomplete never reaches this card.
      DayCloseoutStatus.incomplete => 'لا يوجد عمل متبقٍّ اليوم',
    };

    return _AgendaCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (isComplete) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

/// Calm day-level "incomplete" line shown above the remaining agenda cards.
class _CloseoutSummary extends StatelessWidget {
  final TeacherDayCloseout closeout;

  const _CloseoutSummary({required this.closeout});

  @override
  Widget build(BuildContext context) {
    // Fraction only adds signal for multi-halaqa days (D-C2-A).
    final showFraction = closeout.totalHalaqat > 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showFraction) ...[
          Text(
            'مكتمل ${closeout.completedHalaqat} من ${closeout.totalHalaqat} حلقات',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          'لم يكتمل عمل اليوم',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final Widget child;

  const _AgendaCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ),
          const SizedBox(height: 10),
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

class _EmptyHalaqatCard extends StatelessWidget {
  const _EmptyHalaqatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'لا توجد حلقات مسندة إليك حالياً',
        textAlign: TextAlign.center,
        style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
