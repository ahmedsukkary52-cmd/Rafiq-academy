import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../../notifications/presentation/pages/notification_page.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';
import '../supervisor_home_nav.dart';
import '../widgets/supervisor_loading_skeletons.dart';

String _easternDigits(String input) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final code in input.runes) {
    final ch = String.fromCharCode(code);
    final i = western.indexOf(ch);
    buffer.write(i >= 0 ? eastern[i] : ch);
  }
  return buffer.toString();
}

class SupervisorDashboardTab extends StatefulWidget {
  final ValueChanged<int> onSwitchTab;

  const SupervisorDashboardTab({super.key, required this.onSwitchTab});

  @override
  State<SupervisorDashboardTab> createState() => _SupervisorDashboardTabState();
}

class _SupervisorDashboardTabState extends State<SupervisorDashboardTab> {
  List<SupervisorStudentRow> _roster = const [];
  bool _rosterLoading = false;
  int _loadGen = 0;
  List<String> _loadedHalaqaKey = const [];

  void _reload(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<SupervisorBloc>().add(
      LoadSupervisedHalaqatEvent(auth.user.uid),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRosterIfNeeded(context.read<SupervisorBloc>().state);
    });
  }

  Future<void> _loadRosterIfNeeded(SupervisorState state) async {
    if (state.halaqatStatus != SectionStatus.loaded) return;
    final key = state.halaqat.map((h) => h.id).toList()..sort();
    final same =
        key.length == _loadedHalaqaKey.length &&
        [
          for (var i = 0; i < key.length; i++) key[i] == _loadedHalaqaKey[i],
        ].every((e) => e);
    if (same) return;
    _loadedHalaqaKey = List<String>.from(key);
    final gen = ++_loadGen;
    if (state.halaqat.isEmpty) {
      if (!mounted) return;
      setState(() {
        _roster = const [];
        _rosterLoading = false;
      });
      return;
    }

    setState(() => _rosterLoading = true);
    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    final getStudents = sl<GetHalaqaStudentsUseCase>();

    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      final studentIds = <String>{
        for (final h in state.halaqat) ...h.studentIds,
      }.toList();
      context.read<SupervisorBloc>().add(
        LoadSupervisedPaymentsEvent(
          supervisorId: auth.user.uid,
          studentIds: studentIds,
        ),
      );
    }

    await Future.wait(
      state.halaqat.map((h) async {
        final result = await getStudents(HalaqaStudentsParams(h.id));
        result.fold((_) {}, (list) => byHalaqa[h.id] = list);
      }),
    );
    if (!mounted || gen != _loadGen) return;

    setState(() {
      _roster = SupervisorRoster.mergeSummaries(
        halaqat: state.halaqat,
        byHalaqaId: byHalaqa,
      );
      _rosterLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final name = (user?.name.trim().isNotEmpty == true)
        ? user!.name.trim()
        : 'المشرف';

    return BlocConsumer<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) =>
          p.halaqatStatus != c.halaqatStatus || p.halaqat != c.halaqat,
      listener: (context, state) => _loadRosterIfNeeded(state),
      buildWhen: (p, c) =>
          p.halaqatStatus != c.halaqatStatus ||
          p.halaqat != c.halaqat ||
          p.halaqatError != c.halaqatError ||
          p.dayBoardStatus != c.dayBoardStatus ||
          p.dayBoard != c.dayBoard ||
          p.dayBoardError != c.dayBoardError ||
          p.absenceRequestsStatus != c.absenceRequestsStatus ||
          p.absenceRequests != c.absenceRequests,
      builder: (context, state) {
        final loading =
            state.halaqatStatus == SectionStatus.initial ||
            state.halaqatStatus == SectionStatus.loading;
        final failed = state.halaqatStatus == SectionStatus.error;
        final atRisk = _roster.where((r) => r.isAtRisk).toList();
        final teachers = <String>{
          for (final h in state.halaqat)
            if (h.teacherId.trim().isNotEmpty) h.teacherId.trim(),
        }.length;
        final students = SupervisorRoster.uniqueStudentIds(
          state.halaqat,
        ).length;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _loadedHalaqaKey = const [];
            _reload(context);
          },
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
                        _SupervisorHomeHeader(
                          name: name,
                          imageUrl: user?.profileImageUrl,
                          halaqatCount: state.halaqat.length,
                          onAccount: () => widget.onSwitchTab(
                            SupervisorHomeNav.accountIndex,
                          ),
                          onSearch: () => widget.onSwitchTab(
                            SupervisorHomeNav.studentsIndex,
                          ),
                          onNotifications: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                          },
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
                              ? const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                                  child: SupervisorStatsGridSkeleton(),
                                )
                              : failed
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                  ),
                                  child: AppErrorWidget(
                                    message:
                                        state.halaqatError ??
                                        'تعذر تحميل الحلقات',
                                    onRetry: () => _reload(context),
                                  ),
                                )
                              : _Body(
                                  state: state,
                                  studentsCount: students,
                                  teachersCount: teachers,
                                  atRisk: atRisk,
                                  rosterLoading: _rosterLoading,
                                  roster: _roster,
                                  onSwitchTab: widget.onSwitchTab,
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

class _SupervisorHomeHeader extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final int halaqatCount;
  final VoidCallback onAccount;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  const _SupervisorHomeHeader({
    required this.name,
    required this.imageUrl,
    required this.halaqatCount,
    required this.onAccount,
    required this.onSearch,
    required this.onNotifications,
  });

  String _hijriChipLabel() {
    HijriCalendar.setLocal('ar');
    return HijriCalendar.now().toFormat('dd MMMM yyyy');
  }

  String _roleSubtitle() {
    if (halaqatCount <= 0) return 'مشرف أكاديمية رفيق';
    return 'مشرف — ${_easternDigits('$halaqatCount')} حلقات';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'المشرف' : name.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 12,
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
                    onTap: onAccount,
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
                                'المشرف $displayName',
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
                            onTap: onSearch,
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
              'السلام عليكم 👋',
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
              'لوحة الإشراف الكاملة',
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
                  _easternDigits(_hijriChipLabel()),
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
                      color: AppColors.error,
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

class _Body extends StatelessWidget {
  final SupervisorState state;
  final int studentsCount;
  final int teachersCount;
  final List<SupervisorStudentRow> atRisk;
  final List<SupervisorStudentRow> roster;
  final bool rosterLoading;
  final ValueChanged<int> onSwitchTab;

  const _Body({
    required this.state,
    required this.studentsCount,
    required this.teachersCount,
    required this.atRisk,
    required this.roster,
    required this.rosterLoading,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    final alertCount = atRisk.length + state.absenceRequests.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocSelector<ChatConversationsBloc, ChatConversationsState, int>(
            bloc: sl<ChatConversationsBloc>(),
            selector: (s) => s.totalUnreadCount,
            builder: (context, unread) {
              return _StatsGrid(
                students: studentsCount,
                halaqat: state.halaqat.length,
                teachers: teachersCount,
                atRisk: atRisk.length,
                unreadMessages: unread,
                activeSubscriptions: state.payments
                    .where((p) => p.status == PaymentStatus.paid)
                    .length,
                onStudents: () => onSwitchTab(SupervisorHomeNav.studentsIndex),
                onHalaqat: () => SupervisorDestinations.halaqat(context),
                onTeachers: () => SupervisorDestinations.teachers(context),
                onAtRisk: () => SupervisorDestinations.followUp(context),
                onMessages: () => onSwitchTab(SupervisorHomeNav.messagesIndex),
              );
            },
          ),
          const SizedBox(height: 20),
          _QuickActions(onSwitchTab: onSwitchTab),
          const SizedBox(height: 22),
          _AlertsSection(
            alertCount: alertCount,
            atRisk: atRisk.take(5).toList(),
            absences: state.absenceRequests.take(3).toList(),
            loading: rosterLoading,
            onSwitchTab: onSwitchTab,
          ),
          const SizedBox(height: 20),
          _WeeklyAttendanceCard(roster: roster, loading: rosterLoading),
          if (state.halaqat.isEmpty) ...[
            const SizedBox(height: 20),
            const _EmptyHalaqatHint(),
          ] else ...[
            const SizedBox(height: 20),
            _SectionLabel(
              title: 'حلقاتي',
              action: 'الكل',
              onAction: () => SupervisorDestinations.halaqat(context),
            ),
            const SizedBox(height: 10),
            ...state.halaqat
                .take(4)
                .map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HalaqaCard(
                      name: h.name,
                      students: h.studentIds.length,
                      onTap: () => SupervisorDestinations.halaqaDetail(
                        context,
                        halaqaId: h.id,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int students;
  final int halaqat;
  final int teachers;
  final int atRisk;
  final int unreadMessages;
  final int activeSubscriptions;
  final VoidCallback onStudents;
  final VoidCallback onHalaqat;
  final VoidCallback onTeachers;
  final VoidCallback onAtRisk;
  final VoidCallback onMessages;

  const _StatsGrid({
    required this.students,
    required this.halaqat,
    required this.teachers,
    required this.atRisk,
    required this.unreadMessages,
    required this.activeSubscriptions,
    required this.onStudents,
    required this.onHalaqat,
    required this.onTeachers,
    required this.onAtRisk,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      _StatItem(
        icon: Icons.groups_rounded,
        iconBg: AppColors.primaryLight,
        iconColor: AppColors.primaryDark,
        value: students,
        label: 'إجمالي الطلاب',
        footer: halaqat > 0 ? 'ضمن حلقاتك' : 'لا حلقات بعد',
        footerColor: AppColors.success,
        onTap: onStudents,
      ),
      _StatItem(
        icon: Icons.calendar_month_rounded,
        iconBg: AppColors.secondaryBg,
        iconColor: AppColors.secondaryDeep,
        value: halaqat,
        label: 'إجمالي الحلقات',
        footer: halaqat > 0 ? 'تحت إشرافك' : 'بانتظار التعيين',
        footerColor: AppColors.success,
        onTap: onHalaqat,
      ),
      _StatItem(
        icon: Icons.warning_amber_rounded,
        iconBg: const Color(0xFFFFE8EE),
        iconColor: AppColors.error,
        value: atRisk,
        label: 'طلاب في خطر',
        footer: atRisk > 0 ? 'تحتاج متابعة' : 'لا تنبيهات',
        footerColor: atRisk > 0 ? AppColors.error : AppColors.textHint,
        onTap: onAtRisk,
      ),
      _StatItem(
        icon: Icons.person_outline_rounded,
        iconBg: AppColors.successBg,
        iconColor: AppColors.success,
        value: teachers,
        label: 'إجمالي المعلمين',
        footer: teachers > 0 ? 'مربوطون بحلقاتك' : '—',
        footerColor: AppColors.textSecondary,
        onTap: onTeachers,
      ),
      _StatItem(
        icon: Icons.chat_bubble_outline_rounded,
        iconBg: AppColors.messagesBg,
        iconColor: AppColors.awardWeekly,
        value: unreadMessages,
        label: 'رسائل غير مقروءة',
        footer: unreadMessages > 0 ? 'رسائل جديدة' : 'لا جديد',
        footerColor: AppColors.awardWeekly,
        onTap: onMessages,
      ),
      _StatItem(
        icon: Icons.fact_check_outlined,
        iconBg: const Color(0xFFFFF0E6),
        iconColor: const Color(0xFFE67E22),
        value: activeSubscriptions,
        label: 'اشتراكات نشطة',
        footer: 'عرض المدفوعات',
        footerColor: AppColors.textSecondary,
        onTap: () => SupervisorDestinations.payments(context),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, i) => _StatCard(item: items[i]),
    );
  }
}

class _StatItem {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final int value;
  final String label;
  final String footer;
  final Color footerColor;
  final VoidCallback onTap;

  const _StatItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.footer,
    required this.footerColor,
    required this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: AppColors.softShadow,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 22),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _easternDigits('${item.value}'),
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
              Text(
                item.footer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: item.footerColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;

  const _QuickActions({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, Color, String, VoidCallback)>[
      (
        Icons.person_add_alt_1_rounded,
        AppColors.primaryDark,
        'تسجيل طالب',
        () => SupervisorDestinations.register(context),
      ),
      (
        Icons.account_balance_wallet_outlined,
        AppColors.secondaryDeep,
        'المدفوعات',
        () => SupervisorDestinations.payments(context),
      ),
      (
        Icons.emoji_events_outlined,
        AppColors.gradeGood,
        'الجوائز',
        () => SupervisorDestinations.awardsHub(context),
      ),
      (
        Icons.warning_amber_rounded,
        AppColors.error,
        'طلاب في خطر',
        () => SupervisorDestinations.followUp(context),
      ),
    ];

    final more = <(IconData, Color, String, VoidCallback)>[
      (
        Icons.campaign_outlined,
        AppColors.awardWeekly,
        'الإعلانات',
        () => SupervisorDestinations.announcements(context),
      ),
      (
        Icons.calendar_month_outlined,
        AppColors.secondaryDeep,
        'التقويم',
        () => SupervisorDestinations.calendar(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'إجراءات سريعة',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _QuickActionTile(
                  icon: actions[i].$1,
                  color: actions[i].$2,
                  label: actions[i].$3,
                  onTap: actions[i].$4,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < more.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _QuickActionTile(
                  icon: more[i].$1,
                  color: more[i].$2,
                  label: more[i].$3,
                  onTap: more[i].$4,
                ),
              ),
            ],
            const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  final int alertCount;
  final List<SupervisorStudentRow> atRisk;
  final List<AbsenceRequestEntity> absences;
  final bool loading;
  final ValueChanged<int> onSwitchTab;

  const _AlertsSection({
    required this.alertCount,
    required this.atRisk,
    required this.absences,
    required this.loading,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'تنبيهات تحتاج متابعة',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (alertCount > 0)
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _easternDigits(alertCount > 99 ? '99' : '$alertCount'),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (loading)
          const SizedBox(
            height: 200,
            child: SupervisorListCardsSkeleton(itemCount: 2),
          )
        else if (atRisk.isEmpty && absences.isEmpty)
          AppCard(
            child: Text(
              'لا توجد تنبيهات حالياً — ستظهر هنا حالات الغياب والطلاب في خطر',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
          )
        else ...[
          ...atRisk.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AlertTile(
                title: row.displayName,
                subtitle: 'طالب في خطر · ${row.halaqaLabel}',
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.error,
                actionLabel: 'تواصل',
                actionColor: AppColors.error,
                onAction: () => onSwitchTab(SupervisorHomeNav.messagesIndex),
                onTap: () => SupervisorDestinations.studentProfile(
                  context,
                  studentId: row.studentId,
                  halaqaId: row.halaqaIds.isNotEmpty
                      ? row.halaqaIds.first
                      : null,
                ),
              ),
            ),
          ),
          ...absences.map((req) {
            final reason = req.reason.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AlertTile(
                title: 'استئذان غياب',
                subtitle: reason.isEmpty ? 'طلب استئذان يحتاج مراجعة' : reason,
                icon: Icons.event_busy_outlined,
                iconColor: AppColors.warning,
                actionLabel: 'عرض',
                actionColor: AppColors.awardWeekly,
                onAction: () => SupervisorDestinations.excuses(context),
                onTap: () => SupervisorDestinations.excuses(context),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
  final VoidCallback onTap;

  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: actionColor,
              side: BorderSide(color: actionColor.withValues(alpha: 0.55)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
            ),
            child: Text(
              actionLabel,
              style: AppTextStyles.labelSmall.copyWith(
                color: actionColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAttendanceCard extends StatelessWidget {
  final List<SupervisorStudentRow> roster;
  final bool loading;

  const _WeeklyAttendanceCard({required this.roster, required this.loading});

  @override
  Widget build(BuildContext context) {
    const labels = ['س', 'ج', 'خ', 'أ', 'ث', 'ن', 'س'];
    final avg = roster.isEmpty
        ? 0.0
        : roster.map((r) => r.attendancePercent).reduce((a, b) => a + b) /
              roster.length;
    final today = DateTime.now().weekday;
    final highlightIndex = today % 7;
    final values = List<double>.filled(7, roster.isEmpty ? 0.0 : avg);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: AppColors.primaryDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'معدل الحضور الأسبوعي',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                loading
                    ? '…'
                    : roster.isEmpty
                    ? '—'
                    : '${_easternDigits('${avg.round()}')}٪',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          labels[i],
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(values.length, (i) {
                  final highlighted = i == highlightIndex && roster.isNotEmpty;
                  final bare = values[i] <= 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: bare ? 8 : math.max(values[i], 8),
                        width: 14,
                        borderRadius: BorderRadius.circular(6),
                        color: bare
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : highlighted
                            ? AppColors.secondary
                            : AppColors.primary.withValues(alpha: 0.45),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (roster.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'سيظهر المعدل عند توفر بيانات حضور الطلاب',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionLabel({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(action, style: AppTextStyles.labelMedium),
        ),
      ],
    );
  }
}

class _HalaqaCard extends StatelessWidget {
  final String name;
  final int students;
  final VoidCallback onTap;

  const _HalaqaCard({
    required this.name,
    required this.students,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_easternDigits('$students')} طالب',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _EmptyHalaqatHint extends StatelessWidget {
  const _EmptyHalaqatHint();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 36,
            color: AppColors.textHint.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد حلقات تحت إشرافك بعد',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'عند تعيين حلقات لك ستمتلئ الإحصائيات والتنبيهات تلقائياً',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
