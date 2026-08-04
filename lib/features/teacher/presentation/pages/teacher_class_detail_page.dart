import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../analytics/domain/usecases/analytics_usecases.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../parent/domain/repositories/parent_repositories.dart';
import '../../../post/presentation/pages/posts_list_page.dart';
import '../../../schedule/domain/entities/class_session_entity.dart';
import '../../../schedule/domain/mappers/halaqa_schedule_source_from_entity.dart';
import '../../../schedule/domain/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../utils/assign_sheet_deep_link_gate.dart';
import '../utils/teacher_workflow_ownership.dart';
import '../widgets/teacher_home_figma_cards.dart';
import 'teacher_attendance_page.dart';
import 'teacher_evalutation_page.dart';

/// Teacher Class Details — Figma UI (locked) + Firestore business logic.
class TeacherClassDetailPage extends StatefulWidget {
  final String halaqaId;

  /// W3 Slice 3 deep-link (`?assign=1`) — opens assign sheet once students load.
  final bool openAssignSheet;

  const TeacherClassDetailPage({
    super.key,
    required this.halaqaId,
    this.openAssignSheet = false,
  });

  @override
  State<TeacherClassDetailPage> createState() => _TeacherClassDetailPageState();
}

class _TeacherClassDetailPageState extends State<TeacherClassDetailPage>
    with SingleTickerProviderStateMixin {
  static const _tabs = <String>[
    'الطلاب',
    'الحضور',
    'التقييمات',
    'المهام',
    'المنشورات',
  ];
  static const _sessionsMapper = HalaqaWeeklySessionsMapper();

  late final TabController _tabController;
  late final AssignSheetDeepLinkGate _assignGate;
  final _searchController = TextEditingController();
  String _query = '';

  bool _assignSheetVisible = false;
  bool _statsLoading = false;
  double _attendanceRate = 0;
  double _performanceRate = 0;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    final canWrite = TeacherWorkflowOwnership.canExecute(context);
    _assignGate = AssignSheetDeepLinkGate(
      expectedHalaqaId: widget.halaqaId,
      armed: widget.openAssignSheet && canWrite,
    );
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(widget.halaqaId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<TeacherBloc>().state;
      if (state.halaqatStatus == SectionStatus.initial) {
        _retryHalaqat();
      }
      _loadHeaderStats();
      _onStudentsStatus(state);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  HalaqaEntity? _findHalaqa(TeacherState state) {
    for (final h in state.halaqat) {
      if (h.id == widget.halaqaId) return h;
    }
    return null;
  }

  void _retryHalaqat() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<TeacherBloc>().add(LoadTeacherHalaqatEvent(auth.user.uid));
  }

  Future<void> _loadHeaderStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final result = await sl<GetHalaqaAnalyticsUseCase>()(
      HalaqaAnalyticsParams(
        halaqaId: widget.halaqaId,
        from: from,
        to: now,
      ),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _statsLoading = false;
        _statsError = f.message;
      }),
      (analytics) => setState(() {
        _statsLoading = false;
        _attendanceRate = analytics.attendancePercent;
        _performanceRate = analytics.averagePerformancePercent;
      }),
    );
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<TeacherBloc>();
    bloc.add(LoadHalaqaStudentsEvent(widget.halaqaId));
    await Future.wait([
      bloc.stream.firstWhere(
        (s) =>
            s.studentsStatus == SectionStatus.loaded ||
            s.studentsStatus == SectionStatus.error,
      ),
      _loadHeaderStats(),
    ]);
  }

  void _onStudentsStatus(TeacherState state) {
    final shouldOpen = _assignGate.onStudentsStatus(
      isLoaded: state.studentsStatus == SectionStatus.loaded,
      studentsHalaqaId: state.studentsHalaqaId,
    );
    if (!shouldOpen || !mounted) return;
    _openSendAssignmentSheet(context, studentCount: state.students.length);
  }

  void _openSendAssignmentSheet(
    BuildContext context, {
    required int studentCount,
  }) {
    if (_assignSheetVisible) return;
    if (studentCount <= 0) {
      AppSnackBar.showError(
        context,
        'لا يوجد طلاب في هذه الحلقة لإرسال التكليف',
      );
      return;
    }
    final teacherBloc = context.read<TeacherBloc>();
    _assignSheetVisible = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: teacherBloc,
        child: _SendAssignmentSheet(halaqaId: widget.halaqaId),
      ),
    ).whenComplete(() {
      _assignSheetVisible = false;
      teacherBloc.add(const ResetAssignmentSubmissionEvent());
    });
  }

  void _openSessionHistory(HalaqaEntity? halaqa) {
    if (halaqa == null) {
      AppSnackBar.showInfo(context, 'تعذر تحميل جدول الحلقة');
      return;
    }
    final sessions = _sessionsMapper.map(
      halaqaScheduleSourceFromEntity(halaqa),
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'جلسات هذا الأسبوع',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    Text(
                      'لا توجد جلسات مجدولة هذا الأسبوع',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    ...sessions.map((s) => _SessionHistoryTile(session: s)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _contactParent(HalaqaStudentSummaryEntity student) async {
    try {
      final auth = context.read<AuthBloc>().state;
      if (auth is! AuthAuthenticated) {
        AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
        return;
      }

      final parentsEither =
          await sl<ParentRepository>().getParentIdsByStudentIds([student.uid]);
      if (!mounted) return;

      final parentIds = parentsEither.fold<List<String>?>(
        (_) {
          AppSnackBar.showInfo(
            context,
            'تعذر التحقق من ولي الأمر حالياً. حاول مرة أخرى.',
          );
          return null;
        },
        (map) => map[student.uid] ?? const <String>[],
      );
      if (parentIds == null) return;
      if (parentIds.isEmpty) {
        AppSnackBar.showInfo(
          context,
          'لا يوجد ولي أمر مرتبط بهذا الطالب',
        );
        return;
      }

      final parentEither = await sl<GetChatParticipantUseCase>()(
        ChatUidParams(parentIds.first),
      );
      if (!mounted) return;
      final parent = parentEither.fold<ChatParticipantEntity?>((_) {
        AppSnackBar.showInfo(
          context,
          'تعذر فتح محادثة ولي الأمر حالياً. حاول مرة أخرى.',
        );
        return null;
      }, (p) => p);
      if (parent == null) return;

      final chatBloc = sl<ChatConversationsBloc>();
      chatBloc.add(const ResetStartConversationEvent());
      chatBloc.add(
        StartConversationEvent(
          currentUser: ChatParticipantEntity(
            uid: auth.user.uid,
            name: auth.user.name,
            role: auth.user.role,
            profileImageUrl: auth.user.profileImageUrl,
          ),
          otherUser: parent,
        ),
      );

      final state = await chatBloc.stream.firstWhere(
        (s) =>
            s.startConversationStatus == SubmissionStatus.success ||
            s.startConversationStatus == SubmissionStatus.error,
      );
      if (!mounted) return;
      if (state.startConversationStatus == SubmissionStatus.error ||
          state.startedConversation == null) {
        AppSnackBar.showInfo(
          context,
          'تعذر فتح محادثة ولي الأمر حالياً. حاول مرة أخرى.',
        );
        return;
      }

      final conversation = state.startedConversation!;
      context.push(
        '/teacher/chat/${conversation.id}',
        extra: {
          'name': parent.name,
          'imageUrl': parent.profileImageUrl,
        },
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showInfo(
        context,
        'تعذر التواصل مع ولي الأمر حالياً. حاول مرة أخرى.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<TeacherBloc, TeacherState>(
        listenWhen: (previous, current) =>
            widget.openAssignSheet &&
            !_assignGate.hasOpened &&
            (previous.studentsStatus != current.studentsStatus ||
                previous.studentsHalaqaId != current.studentsHalaqaId),
        listener: (context, state) => _onStudentsStatus(state),
        buildWhen: (previous, current) =>
            previous.halaqatStatus != current.halaqatStatus ||
            previous.halaqat != current.halaqat ||
            previous.halaqatError != current.halaqatError ||
            previous.studentsStatus != current.studentsStatus ||
            previous.students != current.students ||
            previous.studentsError != current.studentsError ||
            previous.studentsHalaqaId != current.studentsHalaqaId,
        builder: (context, state) {
          final halaqa = _findHalaqa(state);
          final title = halaqa?.name.trim().isNotEmpty == true
              ? halaqa!.name.trim()
              : 'الحلقة';
          final studentCount = state.studentsStatus == SectionStatus.loaded &&
                  state.studentsHalaqaId == widget.halaqaId
              ? state.students.length
              : (halaqa?.studentIds.length ?? 0);
          final canWrite = TeacherWorkflowOwnership.canExecute(context);

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
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
                      Column(
                        children: [
                          _ClassDetailHeader(
                            title: title,
                            studentCountLabel: teacherHomeEasternDigits(
                              '$studentCount',
                            ),
                            attendanceRateLabel:
                                '${teacherHomeEasternDigits('${_attendanceRate.round()}')}%',
                            performanceRateLabel:
                                '${teacherHomeEasternDigits('${_performanceRate.round()}')}%',
                            statsLoading: _statsLoading,
                            onBack: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/teacher');
                              }
                            },
                            onHistory: () => _openSessionHistory(halaqa),
                          ),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(AppSizes.radiusXL),
                                  topRight: Radius.circular(AppSizes.radiusXL),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Material(
                                    color: AppColors.surface,
                                    child: TabBar(
                                      controller: _tabController,
                                      isScrollable: true,
                                      tabAlignment: TabAlignment.start,
                                      labelColor: AppColors.primary,
                                      unselectedLabelColor:
                                          AppColors.textSecondary,
                                      indicatorColor: AppColors.primary,
                                      indicatorWeight: 3,
                                      labelStyle: AppTextStyles.labelLarge
                                          .copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      unselectedLabelStyle: AppTextStyles
                                          .labelLarge
                                          .copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      tabs: [
                                        for (final t in _tabs) Tab(text: t),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _StudentsTab(
                                          state: state,
                                          halaqaId: widget.halaqaId,
                                          searchController: _searchController,
                                          query: _query,
                                          onQueryChanged: (v) =>
                                              setState(() => _query = v),
                                          onRefresh: _onRefresh,
                                          onContactParent: _contactParent,
                                        ),
                                        TeacherAttendancePage(
                                          halaqaId: widget.halaqaId,
                                          embedded: true,
                                        ),
                                        TeacherEvaluationsPage(
                                          halaqaId: widget.halaqaId,
                                          embedded: true,
                                        ),
                                        _HomeworkTab(
                                          canWrite: canWrite,
                                          onAssign: () =>
                                              _openSendAssignmentSheet(
                                            context,
                                            studentCount: studentCount,
                                          ),
                                        ),
                                        PostsListPage(
                                          halaqaId: widget.halaqaId,
                                          embedded: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_statsError != null)
                  Material(
                    color: AppColors.secondaryBg,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        _statsError!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.secondaryDeep,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Header (Home gradient + sheet transition) ─────────────────────────────────

class _ClassDetailHeader extends StatelessWidget {
  final String title;
  final String studentCountLabel;
  final String attendanceRateLabel;
  final String performanceRateLabel;
  final bool statsLoading;
  final VoidCallback onBack;
  final VoidCallback onHistory;

  const _ClassDetailHeader({
    required this.title,
    required this.studentCountLabel,
    required this.attendanceRateLabel,
    required this.performanceRateLabel,
    required this.statsLoading,
    required this.onBack,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 40),
      child: Column(
        children: [
          Row(
            children: [
              _HeaderCircleButton(
                icon: Icons.history_rounded,
                onTap: onHistory,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _HeaderCircleButton(
                icon: Icons.chevron_right_rounded,
                onTap: onBack,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (statsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.onPrimary,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    value: studentCountLabel,
                    label: 'طالب',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    value: attendanceRateLabel,
                    label: 'نسبة الحضور',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    value: performanceRateLabel,
                    label: 'متوسط الأداء',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onPrimaryOverlay,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.onPrimary, size: AppSizes.iconL),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.onPrimaryOverlay,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onPrimaryMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionHistoryTile extends StatelessWidget {
  final ClassSessionEntity session;

  const _SessionHistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final status = switch (session.status) {
      ClassSessionStatus.live => 'جارية',
      ClassSessionStatus.upcoming => 'قادمة',
      ClassSessionStatus.ended => 'منتهية',
    };
    final time =
        '${teacherHomeEasternDigits('${session.startAt.hour}:${session.startAt.minute.toString().padLeft(2, '0')}')}'
        ' – '
        '${teacherHomeEasternDigits('${session.endAt.hour}:${session.endAt.minute.toString().padLeft(2, '0')}')}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(session.title, style: AppTextStyles.titleMedium),
      subtitle: Text(
        '$time · $status',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Students tab ──────────────────────────────────────────────────────────────

class _StudentsTab extends StatelessWidget {
  final TeacherState state;
  final String halaqaId;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(HalaqaStudentSummaryEntity) onContactParent;

  const _StudentsTab({
    required this.state,
    required this.halaqaId,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onRefresh,
    required this.onContactParent,
  });

  @override
  Widget build(BuildContext context) {
    if (state.studentsStatus == SectionStatus.loading ||
        state.studentsStatus == SectionStatus.initial ||
        state.studentsHalaqaId != halaqaId) {
      return const AppLoadingWidget();
    }
    if (state.studentsStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.studentsError ?? 'حدث خطأ',
        onRetry: () =>
            context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(halaqaId)),
      );
    }

    final students = query.trim().isEmpty
        ? state.students
        : state.students.where((s) => s.name.contains(query.trim())).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: '...بحث في الطلاب',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.25,
                        child: Center(
                          child: Text(
                            state.students.isEmpty
                                ? 'لا يوجد طلاب في هذه الحلقة'
                                : 'لا نتائج للبحث',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final student = students[i];
                      return _StudentCard(
                        student: student,
                        halaqaId: halaqaId,
                        onContactParent: () => onContactParent(student),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final HalaqaStudentSummaryEntity student;
  final String halaqaId;
  final VoidCallback onContactParent;

  const _StudentCard({
    required this.student,
    required this.halaqaId,
    required this.onContactParent,
  });

  Color get _progressColor {
    final p = student.overallProgressPercent;
    if (p < 40) return AppColors.error;
    if (p < 70) return AppColors.warning;
    return AppColors.success;
  }

  Color get _avatarBg {
    final colors = [
      AppColors.primaryLight,
      AppColors.secondaryBg,
      AppColors.successBg,
    ];
    return colors[student.uid.hashCode.abs() % colors.length];
  }

  Color get _accent {
    if (_avatarBg == AppColors.secondaryBg) return AppColors.secondary;
    if (_avatarBg == AppColors.successBg) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final initial = student.name.trim().isEmpty
        ? '?'
        : String.fromCharCodes(student.name.trim().runes.take(1));
    final attendancePct = student.attendancePercent.round();
    final attendanceDot = attendancePct >= 80
        ? AppColors.success
        : attendancePct >= 60
            ? AppColors.warning
            : AppColors.error;
    final lastEval = student.lastGradeLabel;
    final lastEvalColor = switch (lastEval) {
      'ممتاز' || 'جيد جداً' => AppColors.gradeExcellent,
      'جيد' => AppColors.gradeGood,
      'يحتاج تحسين' || 'يحتاج إعادة' => AppColors.secondary,
      _ => AppColors.textSecondary,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarBg,
                backgroundImage: student.profileImageUrl != null &&
                        student.profileImageUrl!.trim().isNotEmpty
                    ? NetworkImage(student.profileImageUrl!)
                    : null,
                child: student.profileImageUrl == null ||
                        student.profileImageUrl!.trim().isEmpty
                    ? Text(
                        initial,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: _accent,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (student.isAtRisk) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusFull),
                            ),
                            child: Text(
                              'في خطر',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _avatarBg,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Text(
                            'المستوى ${teacherHomeEasternDigits('${student.level}')}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: attendanceDot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '%${teacherHomeEasternDigits('$attendancePct')} حضور',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastEval == null
                          ? 'آخر تقييم: —'
                          : 'آخر تقييم: $lastEval',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: lastEvalColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'تقدم الحفظ',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: (student.overallProgressPercent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.surfaceGrey,
              color: _progressColor,
            ),
          ),
          const SizedBox(height: 14),
          if (student.isAtRisk)
            Row(
              children: [
                Expanded(
                  child: _OutlineAction(
                    label: 'الملف الشخصي',
                    color: AppColors.primary,
                    onTap: () =>
                        context.push('/teacher/student/${student.uid}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutlineAction(
                    label: 'تقييم',
                    color: AppColors.secondary,
                    onTap: () => context.push(
                      '/teacher/halaqa/$halaqaId/evaluations',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutlineAction(
                    label: 'تواصل مع الأهل',
                    color: AppColors.error,
                    onTap: onContactParent,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _OutlineAction(
                    label: 'الملف الشخصي',
                    color: AppColors.primary,
                    onTap: () =>
                        context.push('/teacher/student/${student.uid}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutlineAction(
                    label: 'تقييم',
                    color: AppColors.secondary,
                    onTap: () => context.push(
                      '/teacher/halaqa/$halaqaId/evaluations',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutlineAction(
                    label: 'منح شارة',
                    color: AppColors.success,
                    onTap: () =>
                        context.push('/teacher/halaqa/$halaqaId/awards'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: color),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Other tabs ────────────────────────────────────────────────────────────────

class _HomeworkTab extends StatelessWidget {
  final bool canWrite;
  final VoidCallback onAssign;

  const _HomeworkTab({
    required this.canWrite,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('المهام', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'إرسال تكليف الحفظ/المراجعة لطلاب هذه الحلقة',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (canWrite)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onAssign,
                child: const Text('إرسال تكليف'),
              ),
            )
          else
            Text(
              'التنفيذ متاح لمعلم الحلقة فقط',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Assign sheet (W1 / W3 deep-link) ──────────────────────────────────────────

class _SendAssignmentSheet extends StatefulWidget {
  final String halaqaId;

  const _SendAssignmentSheet({required this.halaqaId});

  @override
  State<_SendAssignmentSheet> createState() => _SendAssignmentSheetState();
}

class _SendAssignmentSheetState extends State<_SendAssignmentSheet> {
  final _memorizationCtrl = TextEditingController();
  final _reviewCtrl = TextEditingController();
  late DateTime _dueDay;

  @override
  void initState() {
    super.initState();
    _dueDay = AttendancePolicy.dayStart(DateTime.now());
  }

  @override
  void dispose() {
    _memorizationCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  DateTime get _dueDateEndOfDay =>
      DateTime(_dueDay.year, _dueDay.month, _dueDay.day, 23, 59, 59);

  String get _dueDayLabel {
    final todayOnly = AttendancePolicy.dayStart(DateTime.now());
    if (AttendancePolicy.isSameCalendarDay(_dueDay, todayOnly)) return 'اليوم';
    final tomorrow = todayOnly.add(const Duration(days: 1));
    if (AttendancePolicy.isSameCalendarDay(_dueDay, tomorrow)) {
      return 'غداً';
    }
    return '${_dueDay.year}/${_dueDay.month.toString().padLeft(2, '0')}/${_dueDay.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDueDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDay,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'موعد التسليم',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDay = AttendancePolicy.dayStart(picked));
  }

  void _submit() {
    final bloc = context.read<TeacherBloc>();
    if (bloc.state.assignmentSubmissionStatus == SubmissionStatus.submitting) {
      return;
    }
    final memorization = _memorizationCtrl.text.trim();
    final review = _reviewCtrl.text.trim();
    if (memorization.isEmpty && review.isEmpty) {
      AppSnackBar.showError(
        context,
        'أدخل نطاق الحفظ أو المراجعة على الأقل',
      );
      return;
    }
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لإرسال التكليف');
      return;
    }
    bloc.add(
      SendAssignmentEvent(
        halaqaId: widget.halaqaId,
        newMemorizationRange: memorization,
        reviewRange: review,
        dueDate: _dueDateEndOfDay,
        teacherId: authState.user.uid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return BlocListener<TeacherBloc, TeacherState>(
      listenWhen: (prev, curr) =>
          prev.assignmentSubmissionStatus != curr.assignmentSubmissionStatus,
      listener: (context, state) {
        if (state.assignmentSubmissionStatus == SubmissionStatus.success) {
          Navigator.pop(context);
          AppSnackBar.showSuccess(context, 'تم إرسال التكليف');
        } else if (state.assignmentSubmissionStatus ==
            SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.assignmentSubmissionError ?? 'فشل إرسال التكليف',
          );
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusL),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إرسال تكليف',
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _memorizationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نطاق الحفظ',
                    hintText: 'مثال: البقرة 1–20',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نطاق المراجعة',
                    hintText: 'مثال: الفاتحة',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('موعد التسليم'),
                  subtitle: Text(_dueDayLabel),
                  trailing: const Icon(Icons.calendar_today_rounded),
                  onTap: _pickDueDay,
                ),
                const SizedBox(height: 12),
                BlocBuilder<TeacherBloc, TeacherState>(
                  buildWhen: (p, c) =>
                      p.assignmentSubmissionStatus !=
                      c.assignmentSubmissionStatus,
                  builder: (context, state) {
                    final loading = state.assignmentSubmissionStatus ==
                        SubmissionStatus.submitting;
                    return SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : const Text('إرسال'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
