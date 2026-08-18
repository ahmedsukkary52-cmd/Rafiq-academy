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
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';
import '../parent_destinations.dart';
import '../parent_display.dart';
import '../parent_home_nav.dart';
import '../../domain/parent_household.dart';
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
    final parentName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'ظˆظ„ظٹ ط§ظ„ط£ظ…ط±';

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
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _reload(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _DashboardHeader(
                  name: parentName,
                  imageUrl: user?.profileImageUrl,
                  childrenCount: state.childrenIds.length,
                  onNotifications: () =>
                      ParentDestinations.notifications(context),
                  onProfile: () => onSwitchTab(ParentHomeNav.accountIndex),
                ),
              ),
              if (state.childrenStatus == SectionStatus.initial ||
                  state.childrenStatus == SectionStatus.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: ParentDashboardSkeleton(),
                )
              else if (state.childrenStatus == SectionStatus.error)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorWidget(
                    message: state.childrenError ?? 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط§ظ„ط¨ظٹط§ظ†ط§طھ',
                    onRetry: () => _reload(context),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const _QuickActionsGrid(),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: 'ظ…ط±ظƒط² ط§ظ„طھظ†ط¨ظٹظ‡ط§طھ',
                        actionLabel: 'ط§ظ„ظƒظ„',
                        onAction: () =>
                            ParentDestinations.notifications(context),
                      ),
                      const SizedBox(height: 10),
                      if (state.alerts.isEmpty)
                        const _AlertsEmptyCard()
                      else
                        ...state.alerts.map(
                          (alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AlertCard(alert: alert),
                          ),
                        ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: 'ظ…طھط§ط¨ط¹ط© ط§ظ„ط£ط¨ظ†ط§ط،',
                        actionLabel: 'ظ…ط´ط§ظ‡ط¯ط© ط§ظ„ظƒظ„',
                        onAction: () =>
                            onSwitchTab(ParentHomeNav.childrenIndex),
                      ),
                      const SizedBox(height: 10),
                      if (state.childrenIds.isEmpty)
                        const _ChildrenEmptyBanner()
                      else
                        _ChildrenCarousel(snapshots: state.childrenSnapshots),
                      const SizedBox(height: 20),
                      _FamilyCard(
                        summary: state.familySummary,
                        onTap: () => ParentDestinations.reports(context),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final int childrenCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _DashboardHeader({
    required this.name,
    required this.imageUrl,
    required this.childrenCount,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.now();
    final dateLabel =
        '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear}';

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BlocSelector<NotificationsBloc, NotificationsState, int>(
                    bloc: sl<NotificationsBloc>(),
                    selector: (s) => s.unreadCount,
                    builder: (context, unread) {
                      return NotificationBadge(
                        count: unread,
                        child: _HeaderIconButton(
                          icon: Icons.notifications_outlined,
                          onTap: onNotifications,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onProfile,
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.onPrimary,
                              ),
                            ),
                            Text(
                              childrenCount == 0
                                  ? 'ظˆظ„ظٹ ط§ظ„ط£ظ…ط±'
                                  : 'ظˆظ„ظٹ ط£ظ…ط± â€” $childrenCount ط£ط¨ظ†ط§ط،',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.onPrimaryMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        ParentUserAvatar(
                          name: name,
                          imageUrl: imageUrl,
                          radius: 22,
                          backgroundColor: AppColors.onPrimaryOverlay,
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'ط§ظ„ط³ظ„ط§ظ… ط¹ظ„ظٹظƒظ…',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
              Text(
                'ظ…طھط§ط¨ط¹ط© ط£ط¨ظ†ط§ط¦ظƒظ… ط§ظ„ظٹظˆظ…',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onPrimaryMuted,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.onPrimaryOverlay,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    dateLabel,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

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
          child: Icon(icon, color: AppColors.onPrimary),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, Color color, String label, VoidCallback onTap})>[
      (
        icon: Icons.assessment_outlined,
        color: AppColors.success,
        label: 'ط§ظ„طھظ‚ط§ط±ظٹط±',
        onTap: () => ParentDestinations.reports(context),
      ),
      (
        icon: Icons.calendar_month_outlined,
        color: AppColors.info,
        label: 'ط§ظ„ط¬ط¯ظˆظ„',
        onTap: () => ParentDestinations.schedule(context),
      ),
      (
        icon: Icons.notifications_outlined,
        color: const Color(0xFFE91E63),
        label: 'ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ',
        onTap: () => ParentDestinations.notifications(context),
      ),
      (
        icon: Icons.fact_check_outlined,
        color: AppColors.primary,
        label: 'ط§ظ„ط­ط¶ظˆط±',
        onTap: () => _openNeedsChild(context, ParentDestinations.attendance),
      ),
      (
        icon: Icons.grade_outlined,
        color: AppColors.secondary,
        label: 'ط§ظ„طھظ‚ظٹظٹظ…ط§طھ',
        onTap: () => _openNeedsChild(context, ParentDestinations.evaluations),
      ),
      (
        icon: Icons.emoji_events_outlined,
        color: AppColors.awardWeekly,
        label: 'ط§ظ„ط¥ظ†ط¬ط§ط²ط§طھ',
        onTap: () => ParentDestinations.achievements(context),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final item in items)
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: item.color, size: 28),
                  const SizedBox(height: 8),
                  Text(item.label, style: AppTextStyles.titleMedium),
                ],
              ),
            ),
          ),
      ],
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
    final id = state.selectedChildId ??
        (state.childrenIds.isNotEmpty ? state.childrenIds.first : null);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ظ„ط§ ظٹظˆط¬ط¯ ط·ط§ظ„ط¨ ظ…ط±طھط¨ط· ظ„ط¹ط±ط¶ ظ‡ط°ظ‡ ط§ظ„طµظپط­ط©')),
      );
      return;
    }
    final name = state.childDisplayName(id);
    open(context, studentId: id, studentName: name);
  }
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
        TextButton(onPressed: onAction, child: Text(actionLabel)),
        const Spacer(),
        Text(title, style: AppTextStyles.headlineMedium),
      ],
    );
  }
}

class _AlertsEmptyCard extends StatelessWidget {
  const _AlertsEmptyCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ظ„ط§ طھظˆط¬ط¯ طھظ†ط¨ظٹظ‡ط§طھ ط­ط§ظ„ظٹط§ظ‹. ط³طھط¸ظ‡ط± ظ‡ظ†ط§ ط§ظ„طھظ†ط¨ظٹظ‡ط§طھ ط§ظ„ظ…ط±طھط¨ط·ط© ط¨ط­ط§ظ„ط© ط§ظ„ط£ط¨ظ†ط§ط،.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.notifications_none_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final ParentAlert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        if (alert.kind == ParentAlertKind.overduePayment) {
          ParentDestinations.subscriptions(context);
          return;
        }
        if (alert.kind == ParentAlertKind.atRiskAbsence) {
          ParentDestinations.attendance(
            context,
            studentId: alert.studentId,
            studentName: alert.studentName,
          );
          return;
        }
        ParentDestinations.evaluations(
          context,
          studentId: alert.studentId,
          studentName: alert.studentName,
        );
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              alert.message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            alert.kind == ParentAlertKind.overduePayment
                ? Icons.payments_outlined
                : Icons.warning_amber_rounded,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _ChildrenEmptyBanner extends StatelessWidget {
  const _ChildrenEmptyBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        'ظ„ط§ ظٹظˆط¬ط¯ ط·ظ„ط§ط¨ ظ…ط±طھط¨ط·ظˆظ† ط¨ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨ ط¨ط¹ط¯.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _ChildrenCarousel extends StatelessWidget {
  final List<ParentChildSnapshot> snapshots;

  const _ChildrenCarousel({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: snapshots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final child = snapshots[index];
          final attendance = parentAttendanceLabel(child.todayAttendanceStatus);
          final payment = parentPaymentLabel(child.paymentStatus);
          return SizedBox(
            width: 260,
            child: AppCard(
              onTap: () => ParentDestinations.childProfile(
                context,
                studentId: child.studentId,
                studentName: child.displayName,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => ParentDestinations.childProfile(
                          context,
                          studentId: child.studentId,
                          studentName: child.displayName,
                        ),
                        child: const Text('ط§ظ„ظ…ظ„ظپ'),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          child.displayName,
                          style: AppTextStyles.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ParentUserAvatar(
                        name: child.displayName,
                        imageUrl: child.profileImageUrl,
                        radius: 18,
                      ),
                    ],
                  ),
                  Text(
                    child.halaqaName.trim().isEmpty
                        ? 'ظ„ظ… طھظڈط­ط¯ط¯ ط­ظ„ظ‚ط© ط¨ط¹ط¯'
                        : child.halaqaName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      'ط§ظ„ظٹظˆظ…: $attendance',
                      if (payment.isNotEmpty) payment,
                      if (child.isAtRisk) 'ظٹط­طھط§ط¬ ظ…طھط§ط¨ط¹ط©',
                    ].join(' آ· '),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: child.isAtRisk
                          ? AppColors.warning
                          : AppColors.textHint,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final ParentFamilySummary summary;
  final VoidCallback onTap;

  const _FamilyCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.dark,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ظ†ط¸ط±ط© ط¹ط§ط¦ظ„ظٹط©',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.secondary,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 4),
              Text(
                'ط£ط¯ط§ط، ط§ظ„ط¹ط§ط¦ظ„ط©',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.onPrimary,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Row(
                  children: [
                    _FamilyMetric(
                      value: '${summary.childrenCount}',
                      label: 'ط£ط¨ظ†ط§ط،',
                    ),
                    _FamilyMetric(
                      value: '${summary.presentTodayCount}',
                      label: 'ط­ط§ط¶ط± ط§ظ„ظٹظˆظ…',
                    ),
                    _FamilyMetric(
                      value: '${summary.atRiskCount}',
                      label: 'ظ…طھط§ط¨ط¹ط©',
                    ),
                    _FamilyMetric(
                      value: '${summary.overduePaymentsCount}',
                      label: 'ظ…طھط£ط®ط±',
                    ),
                  ],
                ),
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

  const _FamilyMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onPrimaryMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
