import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_household.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';
import '../parent_destinations.dart';
import '../parent_display.dart';
import '../parent_home_nav.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_user_avatar.dart';

class ParentDashboardTab extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;

  const ParentDashboardTab({super.key, required this.onSwitchTab});

  void _reload(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<ParentBloc>().add(LoadChildrenEvent(auth.user.uid));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final rawName = user?.name.trim() ?? '';
    final parentName = rawName.isEmpty ? 'ولي الأمر' : rawName;

    return BlocBuilder<ParentBloc, ParentState>(
      buildWhen: (p, c) =>
          p.childrenStatus != c.childrenStatus ||
          p.childrenIds != c.childrenIds ||
          p.childrenError != c.childrenError ||
          p.selectedChildId != c.selectedChildId ||
          p.childrenSnapshots != c.childrenSnapshots ||
          p.alerts != c.alerts ||
          p.familySummary != c.familySummary,
      builder: (context, state) {
        final loading = state.childrenStatus == SectionStatus.initial ||
            state.childrenStatus == SectionStatus.loading;
        final failed = state.childrenStatus == SectionStatus.error;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _reload(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                        child: SizedBox(height: 340),
                      ),
                    ),
                    Column(
                      children: [
                        _ParentHomeHeader(
                          name: parentName,
                          imageUrl: user?.profileImageUrl,
                          childrenCount: state.childrenIds.length,
                          onNotifications: () =>
                              ParentDestinations.notifications(context),
                          onProfile: () =>
                              onSwitchTab(ParentHomeNav.accountIndex),
                        ),
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(AppSizes.radiusXL),
                              topRight: Radius.circular(AppSizes.radiusXL),
                            ),
                          ),
                          child: loading
                              ? const ParentDashboardSkeleton()
                              : failed
                              ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 48,
                            ),
                            child: AppErrorWidget(
                              message: state.childrenError ??
                                  'تعذر تحميل البيانات',
                              onRetry: () => _reload(context),
                            ),
                          )
                              : _DashboardBody(
                            state: state,
                            onSwitchTab: onSwitchTab,
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
}

class _DashboardBody extends StatelessWidget {
  final ParentState state;
  final ValueChanged<int> onSwitchTab;

  const _DashboardBody({
    required this.state,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _QuickActionsCard(),
          const SizedBox(height: 8),
          _SectionTitle(
            title: 'مركز التنبيهات الذكية',
            actionLabel: 'الكل',
            onAction: () => ParentDestinations.notifications(context),
          ),
          const SizedBox(height: 10),
          if (state.alerts.isEmpty)
            const _AlertsEmptyCard()
          else
            ...state.alerts.map(
                  (alert) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AlertCard(alert: alert),
                  ),
            ),
          const SizedBox(height: 12),
          _SectionTitle(
            title: 'مركز المتابعة السريع',
            actionLabel: 'مشاهدة الكل',
            onAction: () => onSwitchTab(ParentHomeNav.childrenIndex),
          ),
          const SizedBox(height: 10),
          if (state.childrenIds.isEmpty)
            const _ChildrenEmptyBanner()
          else
            _ChildrenCarousel(
              snapshots: state.childrenSnapshots,
              onSupervisor: () => onSwitchTab(ParentHomeNav.messagesIndex),
            ),
          const SizedBox(height: 20),
          _FamilyCard(
            summary: state.familySummary,
            snapshots: state.childrenSnapshots,
            onTap: () => ParentDestinations.reports(context),
          ),
        ],
      ),
    );
  }
}

class _ParentHomeHeader extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final int childrenCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _ParentHomeHeader({
    required this.name,
    required this.imageUrl,
    required this.childrenCount,
    required this.onNotifications,
    required this.onProfile,
  });

  String _hijriChipLabel() {
    HijriCalendar.setLocal('ar');
    return HijriCalendar.now().toFormat('dd MMMM yyyy');
  }

  String _roleSubtitle() {
    if (childrenCount <= 0) return 'ولي أمر';
    return 'ولي أمر — ${parentEasternDigits('$childrenCount')} أبناء';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery
              .paddingOf(context)
              .top + 12,
          left: 20,
          right: 20,
          bottom: 36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onProfile,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    child: Row(
                      children: [
                        ParentUserAvatar(
                          name: name,
                          imageUrl: imageUrl,
                          radius: 22,
                          backgroundColor: AppColors.onPrimaryOverlay,
                          foregroundColor: AppColors.onPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
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
                                _roleSubtitle(),
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
                  selector: (s) => s.unreadCount,
                  builder: (context, unread) {
                    return Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeaderSquareButton(
                            icon: Icons.search_rounded,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('قريباً')),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _HeaderSquareButton(
                            icon: Icons.notifications_outlined,
                            showDot: unread > 0,
                            onTap: onNotifications,
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
              'السلام عليكم',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'متابعة أبنائكم اليوم',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.displayLarge.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.onPrimaryOverlay,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  parentEasternDigits(_hijriChipLabel()),
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

class _HeaderSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderSquareButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onPrimaryOverlay,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppColors.onPrimary, size: 20),
              if (showDot)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAction>[
      _QuickAction(
        icon: Icons.assessment_outlined,
        color: AppColors.success,
        label: 'التقارير',
        onTap: () => ParentDestinations.reports(context),
      ),
      _QuickAction(
        icon: Icons.calendar_month_outlined,
        color: AppColors.info,
        label: 'الجدول',
        onTap: () => ParentDestinations.schedule(context),
      ),
      _QuickAction(
        icon: Icons.notifications_outlined,
        color: const Color(0xFFE53935),
        label: 'الإشعارات',
        onTap: () => ParentDestinations.notifications(context),
      ),
      _QuickAction(
        icon: Icons.fact_check_outlined,
        color: AppColors.primary,
        label: 'الحضور',
        onTap: () => _openNeedsChild(context, ParentDestinations.attendance),
      ),
      _QuickAction(
        icon: Icons.grade_outlined,
        color: AppColors.secondary,
        label: 'التقييمات',
        onTap: () => _openNeedsChild(context, ParentDestinations.evaluations),
      ),
      _QuickAction(
        icon: Icons.emoji_events_outlined,
        color: AppColors.awardWeekly,
        label: 'الإنجازات',
        onTap: () => ParentDestinations.achievements(context),
      ),
    ];

    return Material(
      color: AppColors.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 4,
          childAspectRatio: 1.05,
          children: [
            for (final item in items)
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, color: item.color, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _openNeedsChild(
    BuildContext context,
    Future<void> Function(
      BuildContext context, {
      required String studentId,
      String? studentName,
    })
    open,
  ) {
    final state = context.read<ParentBloc>().state;
    final selected = state.selectedChildId?.trim();
    final fallback =
    state.childrenIds.isEmpty ? null : state.childrenIds.first.trim();
    final id = (selected != null && selected.isNotEmpty) ? selected : fallback;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طالب مرتبط لعرض هذه الصفحة')),
      );
      return;
    }
    open(
      context,
      studentId: id,
      studentName: state.childDisplayName(id),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _AlertsEmptyCard extends StatelessWidget {
  const _AlertsEmptyCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لا توجد تنبيهات حالياً. ستظهر هنا التنبيهات المرتبطة بحالة الأبناء.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final ParentAlert alert;

  const _AlertCard({required this.alert});

  Color get _accent {
    return switch (alert.kind) {
      ParentAlertKind.overduePayment => AppColors.warning,
      ParentAlertKind.atRiskAbsence => AppColors.error,
      ParentAlertKind.atRiskNoEval => AppColors.info,
    };
  }

  IconData get _icon {
    return switch (alert.kind) {
      ParentAlertKind.overduePayment => Icons.payments_outlined,
      ParentAlertKind.atRiskAbsence => Icons.event_busy_rounded,
      ParentAlertKind.atRiskNoEval => Icons.warning_amber_rounded,
    };
  }

  String get _actionLabel {
    return switch (alert.kind) {
      ParentAlertKind.overduePayment => 'سداد',
      ParentAlertKind.atRiskAbsence => 'الحضور',
      ParentAlertKind.atRiskNoEval => 'التقييم',
    };
  }

  Future<void> _open(BuildContext context) {
    final studentId = alert.studentId.trim();
    if (alert.kind == ParentAlertKind.overduePayment) {
      return ParentDestinations.subscriptions(context);
    }
    if (studentId.isEmpty) return Future.value();
    if (alert.kind == ParentAlertKind.atRiskAbsence) {
      return ParentDestinations.attendance(
        context,
        studentId: studentId,
        studentName: alert.studentName,
      );
    }
    return ParentDestinations.evaluations(
      context,
      studentId: studentId,
      studentName: alert.studentName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(AppSizes.radiusL),
                      bottomRight: Radius.circular(AppSizes.radiusL),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        Icon(_icon, color: _accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alert.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _open(context),
                          style: TextButton.styleFrom(
                            foregroundColor: _accent,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Text(_actionLabel),
                        ),
                      ],
                    ),
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

class _ChildrenEmptyBanner extends StatelessWidget {
  const _ChildrenEmptyBanner();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Text(
        'لا يوجد طلاب مرتبطون بهذا الحساب بعد.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ChildrenCarousel extends StatelessWidget {
  final List<ParentChildSnapshot> snapshots;
  final VoidCallback onSupervisor;

  const _ChildrenCarousel({
    required this.snapshots,
    required this.onSupervisor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: snapshots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 292,
            child: _ChildFollowUpCard(
              child: snapshots[index],
              onSupervisor: onSupervisor,
            ),
          );
        },
      ),
    );
  }
}

class _ChildFollowUpCard extends StatelessWidget {
  final ParentChildSnapshot child;
  final VoidCallback onSupervisor;

  const _ChildFollowUpCard({
    required this.child,
    required this.onSupervisor,
  });

  @override
  Widget build(BuildContext context) {
    final name = child.displayName;
    final halaqa = child.halaqaName.trim();
    final attendance = parentAttendanceLabel(child.todayAttendanceStatus);
    final payment = parentPaymentLabel(child.paymentStatus);
    final hasSupervisor = (child.supervisorId ?? '')
        .trim()
        .isNotEmpty;
    final progress = parentPercentLabel(
      child.overallProgressPercent > 0 ? child.overallProgressPercent : null,
    );
    final attendancePct = parentPercentLabel(child.attendancePercentInWindow);

    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ParentUserAvatar(
                name: name,
                imageUrl: child.profileImageUrl,
                radius: 20,
                backgroundColor: AppColors.secondaryBg,
                foregroundColor: AppColors.secondaryDeep,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleLarge.copyWith(height: 1.2),
                    ),
                    Text(
                      halaqa.isEmpty ? 'لم تُحدد حلقة بعد' : halaqa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                label: child.isAtRisk ? 'يحتاج متابعة' : 'متابعة جيدة',
                color: child.isAtRisk ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(value: progress, label: 'أداء'),
              const SizedBox(width: 6),
              _MiniStat(value: attendancePct, label: 'حضور'),
              const SizedBox(width: 6),
              _MiniStat(value: attendance, label: 'اليوم'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Text(
              halaqa.isEmpty ? 'لا توجد حلقة مرتبطة اليوم' : 'الحلقة: $halaqa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (payment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: child.paymentStatus == PaymentStatus.overdue
                    ? AppColors.secondaryBg
                    : AppColors.successBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
              ),
              child: Row(
                children: [
                  Icon(
                    child.paymentStatus == PaymentStatus.paid
                        ? Icons.check_circle_rounded
                        : Icons.payments_outlined,
                    size: 16,
                    color: child.paymentStatus == PaymentStatus.overdue
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'الاشتراك: $payment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      ParentDestinations.childProfile(
                        context,
                        studentId: child.studentId,
                        studentName: name,
                      ),
                  style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.all(
                          Radius.circular(8)),
                    ),
                    backgroundColor: AppColors.primaryGradientMid,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(0, 42),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('الملف'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ParentDestinations.reports(
                        context,
                        studentId: child.studentId,
                        studentName: name,
                      ),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.all(
                          Radius.circular(8)),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(0, 42),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('تقرير'),
                ),
              ),
              if (hasSupervisor) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSupervisor,
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadiusGeometry.all(Radius.circular(
                            8)),
                      ),
                      backgroundColor: AppColors.awardWeekly.withValues(
                          alpha: 0.12),
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(0, 42),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.awardWeekly,
                    ),
                    child: const Text('المشرف'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final ParentFamilySummary summary;
  final List<ParentChildSnapshot> snapshots;
  final VoidCallback onTap;

  const _FamilyCard({
    required this.summary,
    required this.snapshots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final verses = snapshots.fold<int>(
      0,
          (sum, child) => sum + child.totalVersesMemorized,
    );
    final attendance = parentPercentLabel(summary.averageAttendancePercent);

    return Material(
      color: AppColors.dark,
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أداء العائلة خلال ١٤ يوماً',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                        Text(
                          'من نافذة الحضور والمتابعة الحالية',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.onPrimaryMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.onPrimaryOverlay,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      'نظرة عائلية',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _FamilyMetric(
                    value: parentEasternDigits('${summary.childrenCount}'),
                    label: 'أبناء',
                  ),
                  _FamilyMetric(value: attendance, label: 'متوسط الحضور'),
                  _FamilyMetric(
                    value: parentEasternDigits('$verses'),
                    label: 'آيات محفوظة',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FamilyMetric(
                    value: parentEasternDigits('${summary.presentTodayCount}'),
                    label: 'حاضر اليوم',
                  ),
                  _FamilyMetric(
                    value: parentEasternDigits('${summary.atRiskCount}'),
                    label: 'يحتاج متابعة',
                    emphasize: summary.atRiskCount > 0,
                  ),
                  _FamilyMetric(
                    value: parentEasternDigits(
                      '${summary.overduePaymentsCount}',
                    ),
                    label: 'متأخر سداد',
                    emphasize: summary.overduePaymentsCount > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyMetric extends StatelessWidget {
  final String value;
  final String label;
  final bool emphasize;

  const _FamilyMetric({
    required this.value,
    required this.label,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineMedium.copyWith(
                color: emphasize ? AppColors.error : AppColors.onPrimary,
                fontSize: 16,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.onPrimaryMuted,
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
