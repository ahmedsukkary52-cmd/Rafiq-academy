import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
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
            // Wait for halaqat AND agenda — agenda derives after halaqat load.
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
                ),
              ),
              ..._bodySlivers(context, state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _bodySlivers(BuildContext context, TeacherState state) {
    if (state.halaqatStatus == SectionStatus.initial ||
        state.halaqatStatus == SectionStatus.loading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: AppLoadingWidget(),
        ),
      ];
    }

    if (state.halaqatStatus == SectionStatus.error) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
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

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.paddingM,
            16,
            AppSizes.paddingM,
            0,
          ),
          child: _TeacherStatsRow(
            studentsCount: totalStudents,
            halaqatCount: state.halaqat.length,
          ),
        ),
      ),
      if (state.halaqat.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.paddingM,
              16,
              AppSizes.paddingM,
              0,
            ),
            child: _EmptyHalaqatCard(),
          ),
        )
      else
        SliverToBoxAdapter(
          child: Padding(
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
        const Text('عمل اليوم', style: AppTextStyles.titleLarge),
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
// _TeacherHeader
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherHeader extends StatelessWidget {
  final String name;
  final String halaqaName;

  const _TeacherHeader({required this.name, required this.halaqaName});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      '',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final dayName = weekdays[now.weekday];

    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: AppSizes.paddingM,
        right: AppSizes.paddingM,
        bottom: AppSizes.paddingXL,
      ),
      child: Column(
        children: [
          // شريط أيقونات علوي
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الأستاذ $name',
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (halaqaName.isNotEmpty)
                        Text(
                          'معلم تحفيظ · $halaqaName',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0] : 'م',
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              BlocSelector<NotificationsBloc, NotificationsState, int>(
                bloc: sl<NotificationsBloc>(),
                selector: (state) => state.unreadCount,
                builder: (context, unreadCount) {
                  return NotificationBadge(
                    count: unreadCount,
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () => context.push(AppRoutes.teacherNotifs),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // التحية
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'يوم $dayName مبارك!',
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'السلام عليكم',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TeacherStatsRow - إحصاءات حقيقية فقط
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherStatsRow extends StatelessWidget {
  final int studentsCount;
  final int halaqatCount;

  const _TeacherStatsRow({
    required this.studentsCount,
    required this.halaqatCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$studentsCount',
            label: 'إجمالي الطلاب',
            icon: Icons.person_outline_rounded,
            color: AppColors.primaryLight,
            iconColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '$halaqatCount',
            label: 'الحلقات',
            icon: Icons.calendar_today_outlined,
            color: const Color(0xFFE8F5E9),
            iconColor: AppColors.success,
          ),
        ),
      ],
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
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color iconColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(label, style: AppTextStyles.labelSmall),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ],
      ),
    );
  }
}
