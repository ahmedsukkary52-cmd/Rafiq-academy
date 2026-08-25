import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';
import '../supervisor_home_nav.dart';
import '../widgets/supervisor_day_board_section.dart';

class SupervisorDashboardTab extends StatefulWidget {
  final ValueChanged<int> onSwitchTab;

  const SupervisorDashboardTab({super.key, required this.onSwitchTab});

  @override
  State<SupervisorDashboardTab> createState() => _SupervisorDashboardTabState();
}

class _SupervisorDashboardTabState extends State<SupervisorDashboardTab> {
  List<SupervisorStudentRow> _atRisk = const [];
  bool _atRiskLoading = false;
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
      _loadAtRiskIfNeeded(context.read<SupervisorBloc>().state);
    });
  }

  Future<void> _loadAtRiskIfNeeded(SupervisorState state) async {
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
        _atRisk = const [];
        _atRiskLoading = false;
      });
      return;
    }

    setState(() => _atRiskLoading = true);
    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    final getStudents = sl<GetHalaqaStudentsUseCase>();
    await Future.wait(
      state.halaqat.map((h) async {
        final result = await getStudents(HalaqaStudentsParams(h.id));
        result.fold((_) {}, (list) => byHalaqa[h.id] = list);
      }),
    );
    if (!mounted || gen != _loadGen) return;

    final rows = SupervisorRoster.mergeSummaries(
      halaqat: state.halaqat,
      byHalaqaId: byHalaqa,
    ).where((r) => r.isAtRisk).take(5).toList();

    setState(() {
      _atRisk = rows;
      _atRiskLoading = false;
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
      listener: (context, state) => _loadAtRiskIfNeeded(state),
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
        final students = SupervisorRoster.uniqueStudentIds(
          state.halaqat,
        ).length;
        final absences = state.absenceRequests.length;

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
                        child: SizedBox(height: 280),
                      ),
                    ),
                    Column(
                      children: [
                        _Header(
                          name: name,
                          onAccount: () => widget.onSwitchTab(
                            SupervisorHomeNav.accountIndex,
                          ),
                          onStudents: () => widget.onSwitchTab(
                            SupervisorHomeNav.studentsIndex,
                          ),
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
                                  padding: EdgeInsets.all(48),
                                  child: AppLoadingWidget(),
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
                              : state.halaqat.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.fromLTRB(24, 40, 24, 48),
                                  child: _EmptyHalaqat(),
                                )
                              : _Body(
                                  state: state,
                                  studentsCount: students,
                                  absencesCount: absences,
                                  atRisk: _atRisk,
                                  atRiskLoading: _atRiskLoading,
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

class _Header extends StatelessWidget {
  final String name;
  final VoidCallback onAccount;
  final VoidCallback onStudents;

  const _Header({
    required this.name,
    required this.onAccount,
    required this.onStudents,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 16,
        18,
        28,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'لوحة إشراف اليوم',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onStudents,
            icon: const Icon(Icons.groups_rounded, color: AppColors.onPrimary),
          ),
          IconButton(
            onPressed: onAccount,
            icon: const Icon(Icons.person_outline, color: AppColors.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final SupervisorState state;
  final int studentsCount;
  final int absencesCount;
  final List<SupervisorStudentRow> atRisk;
  final bool atRiskLoading;
  final ValueChanged<int> onSwitchTab;

  const _Body({
    required this.state,
    required this.studentsCount,
    required this.absencesCount,
    required this.atRisk,
    required this.atRiskLoading,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KpiRow(
            students: studentsCount,
            halaqat: state.halaqat.length,
            absences: absencesCount,
            sessionsToday: state.dayBoard.sessionsTodayCount,
          ),
          const SizedBox(height: 16),
          const _QuickActions(),
          const SizedBox(height: 20),
          _SectionLabel(
            title: 'حلقاتي',
            action: 'الكل',
            onAction: () => SupervisorDestinations.halaqat(context),
          ),
          const SizedBox(height: 10),
          ...state.halaqat.map(
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
          const SizedBox(height: 12),
          _SectionLabel(
            title: 'طلاب في خطر',
            action: 'المزيد',
            onAction: () => onSwitchTab(SupervisorHomeNav.studentsIndex),
          ),
          const SizedBox(height: 10),
          if (atRiskLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: AppLoadingWidget(),
            )
          else if (atRisk.isEmpty)
            AppCard(
              child: Text(
                'لا يوجد طلاب مصنّفون في خطر حالياً',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            )
          else
            ...atRisk.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AtRiskTile(
                  row: row,
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
          if (state.dayBoardStatus == SectionStatus.loaded ||
              state.dayBoardStatus == SectionStatus.loading ||
              state.dayBoardStatus == SectionStatus.error) ...[
            const SizedBox(height: 16),
            SupervisorDayBoardSection(
              status: state.dayBoardStatus,
              board: state.dayBoard,
              error: state.dayBoardError,
              onRetry: () => context.read<SupervisorBloc>().add(
                const LoadSupervisorDayBoardEvent(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final int students;
  final int halaqat;
  final int absences;
  final int sessionsToday;

  const _KpiRow({
    required this.students,
    required this.halaqat,
    required this.absences,
    required this.sessionsToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCell(value: '$students', label: 'طلاب'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCell(value: '$halaqat', label: 'حلقات'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCell(value: '$absences', label: 'استئذان'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCell(value: '$sessionsToday', label: 'اليوم'),
        ),
      ],
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String value;
  final String label;

  const _KpiCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textHint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, VoidCallback)>[
      (
        Icons.person_add_alt_1_rounded,
        'تسجيل طالب',
        () => SupervisorDestinations.register(context),
      ),
      (
        Icons.groups_rounded,
        'إدارة المجموعات',
        () => SupervisorDestinations.halaqat(context),
      ),
      (
        Icons.assessment_outlined,
        'تقرير سريع',
        () => SupervisorDestinations.reportsQuick(context),
      ),
      (
        Icons.warning_amber_rounded,
        'بلاغ في خطر',
        () => SupervisorDestinations.followUp(context),
      ),
      (
        Icons.emoji_events_outlined,
        'الجوائز',
        () => SupervisorDestinations.awardsHub(context),
      ),
      (
        Icons.event_busy_outlined,
        'الاعتذارات',
        () => SupervisorDestinations.excuses(context),
      ),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (icon, label, onTap) = actions[i];
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: SizedBox(
                width: 92,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.primaryDark, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                  '$students طالب',
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

class _AtRiskTile extends StatelessWidget {
  final SupervisorStudentRow row;
  final VoidCallback onTap;

  const _AtRiskTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.error.withValues(alpha: 0.12),
            backgroundImage:
                row.profileImageUrl != null && row.profileImageUrl!.isNotEmpty
                ? NetworkImage(row.profileImageUrl!)
                : null,
            child: row.profileImageUrl == null || row.profileImageUrl!.isEmpty
                ? Text(
                    row.displayName.isNotEmpty ? row.displayName[0] : '؟',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  row.halaqaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8EE),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Text(
              'في خطر',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHalaqat extends StatelessWidget {
  const _EmptyHalaqat();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.school_outlined,
          size: 48,
          color: AppColors.textHint.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'لا توجد حلقات تحت إشرافك',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'ستظهر الحلقات المعيَّنة لك هنا',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
