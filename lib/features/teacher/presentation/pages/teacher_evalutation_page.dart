import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/evaluation_policy.dart';
import '../../../../shared/domain/evaluation_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../utils/teacher_workflow_ownership.dart';
import '../widgets/teacher_home_figma_cards.dart';

/// Teacher Evaluations — Figma 1:1056 + Firestore via [TeacherBloc].
class TeacherEvaluationsPage extends StatefulWidget {
  final String halaqaId;

  /// When true, render body only (no route AppBar) for Class Details tabs.
  final bool embedded;

  /// Optional preselect for «تقييم جديد» (query `studentId`).
  final String? initialStudentId;

  const TeacherEvaluationsPage({
    super.key,
    required this.halaqaId,
    this.embedded = false,
    this.initialStudentId,
  });

  @override
  State<TeacherEvaluationsPage> createState() => _TeacherEvaluationsPageState();
}

class _TeacherEvaluationsPageState extends State<TeacherEvaluationsPage> {
  int _filterIndex = 0;
  final _filters = const ['هذا الشهر', 'الشهر الماضي', 'الفصل كله'];

  /// After first successful evaluations load, keep the list visible during reload.
  bool _shellReady = false;
  List<RecitationRecordEntity> _cachedEvaluations = const [];

  @override
  void initState() {
    super.initState();
    final bloc = context.read<TeacherBloc>();
    bloc.add(LoadHalaqaStudentsEvent(widget.halaqaId));
    bloc.add(LoadHalaqaEvaluationsEvent(widget.halaqaId));
    final preselect = widget.initialStudentId?.trim();
    if (preselect != null &&
        preselect.isNotEmpty &&
        TeacherWorkflowOwnership.canExecute(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAddEvaluationSheet(context);
      });
    }
  }

  void _retry() {
    context.read<TeacherBloc>().add(
      LoadHalaqaEvaluationsEvent(widget.halaqaId),
    );
  }

  HalaqaEntity? _halaqaFromState(TeacherState state) {
    for (final h in state.halaqat) {
      if (h.id == widget.halaqaId) return h;
    }
    return null;
  }

  Future<void> _ensureHalaqatLoaded() async {
    final bloc = context.read<TeacherBloc>();
    if (bloc.state.halaqat.any((h) => h.id == widget.halaqaId)) return;

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    bloc.add(LoadTeacherHalaqatEvent(auth.user.uid));
    await bloc.stream.firstWhere(
      (s) =>
          s.halaqatStatus == SectionStatus.loaded ||
          s.halaqatStatus == SectionStatus.error,
    );
  }

  Future<void> _openEvaluateSheet({
    String? preselectStudentId,
    RecitationRecordEntity? existingRecord,
  }) async {
    if (!TeacherWorkflowOwnership.canExecute(context)) return;

    final bloc = context.read<TeacherBloc>();
    await _ensureHalaqatLoaded();
    if (!mounted) return;

    final records = bloc.state.evaluations.isNotEmpty
        ? bloc.state.evaluations
        : _cachedEvaluations;

    final result = sl<EvaluationService>().openEvaluation(
      halaqaId: widget.halaqaId,
      halaqa: _halaqaFromState(bloc.state),
      records: records,
      studentId: preselectStudentId?.trim().isNotEmpty == true
          ? preselectStudentId!.trim()
          : existingRecord?.studentId,
      existingRecord: existingRecord,
    );

    if (!result.isReady) {
      _showOpenEvaluationBlock(result.blockReason!);
      return;
    }

    if (bloc.state.students.isEmpty ||
        bloc.state.studentsStatus == SectionStatus.error) {
      bloc.add(LoadHalaqaStudentsEvent(widget.halaqaId));
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _TeacherEvaluationSheet(
          initial: result.model!,
          seedRecords: records,
        ),
      ),
    ).whenComplete(() {
      bloc.add(const ResetRecitationSubmissionEvent());
    });
  }

  void _showOpenEvaluationBlock(OpenEvaluationBlockReason reason) {
    switch (reason) {
      case OpenEvaluationBlockReason.notEditableSessionEvaluation:
        AppSnackBar.showInfo(
          context,
          'هذا السجل ليس تقييماً جلسياً قابلاً للتعديل من هنا',
        );
      case OpenEvaluationBlockReason.halaqaUnavailable:
        AppSnackBar.showError(context, 'تعذر تحميل بيانات الحلقة');
      case OpenEvaluationBlockReason.noSessionToday:
        AppSnackBar.showInfo(context, 'لا توجد جلسة اليوم للتقييم');
    }
  }

  void _showAddEvaluationSheet(BuildContext context) {
    _openEvaluateSheet(preselectStudentId: widget.initialStudentId);
  }

  void _showEditEvaluationSheet(RecitationRecordEntity record) {
    _openEvaluateSheet(existingRecord: record);
  }

  List<RecitationRecordEntity> _filtered(List<RecitationRecordEntity> records) {
    final now = DateTime.now();
    if (_filterIndex == 2) return records;

    final start = _filterIndex == 0
        ? DateTime(now.year, now.month)
        : DateTime(now.year, now.month - 1);
    final end = _filterIndex == 0
        ? DateTime(now.year, now.month + 1)
        : DateTime(now.year, now.month);

    return records
        .where((r) => !r.date.isBefore(start) && r.date.isBefore(end))
        .toList();
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<TeacherBloc>();
    _retry();
    await bloc.stream.firstWhere(
      (s) =>
          s.evaluationsStatus == SectionStatus.loaded ||
          s.evaluationsStatus == SectionStatus.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = TeacherWorkflowOwnership.canExecute(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<TeacherBloc, TeacherState>(
        listenWhen: (prev, curr) =>
            prev.evaluationsStatus != curr.evaluationsStatus ||
            prev.evaluations != curr.evaluations,
        listener: (context, state) {
          if (state.evaluationsStatus == SectionStatus.loaded) {
            setState(() {
              _shellReady = true;
              _cachedEvaluations = state.evaluations;
            });
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              if (widget.embedded)
                _EmbeddedHeader(
                  canWrite: canWrite,
                  onAdd: () => _showAddEvaluationSheet(context),
                )
              else
                _EvalsHeader(
                  canWrite: canWrite,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/teacher');
                    }
                  },
                  onAdd: () => _showAddEvaluationSheet(context),
                ),
              Expanded(
                child: BlocBuilder<TeacherBloc, TeacherState>(
                  buildWhen: (previous, current) =>
                      previous.evaluationsStatus != current.evaluationsStatus ||
                      previous.evaluations != current.evaluations ||
                      previous.evaluationsError != current.evaluationsError ||
                      previous.studentsStatus != current.studentsStatus ||
                      previous.students != current.students,
                  builder: (context, state) {
                    final isRefreshing = _shellReady &&
                        (state.evaluationsStatus == SectionStatus.loading);

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
                            children: List.generate(_filters.length, (i) {
                              final selected = i == _filterIndex;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: i < _filters.length - 1 ? 8 : 0,
                                  ),
                                  child: Material(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusFull,
                                    ),
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _filterIndex = i),
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusFull,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusFull,
                                          ),
                                          border: selected
                                              ? null
                                              : Border.all(
                                                  color: AppColors.border,
                                                ),
                                        ),
                                        child: Text(
                                          _filters[i],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              AppTextStyles.labelMedium.copyWith(
                                            color: selected
                                                ? AppColors.onPrimary
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        if (isRefreshing)
                          const LinearProgressIndicator(
                            minHeight: 2,
                            color: AppColors.primary,
                          ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildList(state)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(TeacherState state) {
    final isInitialLoading = !_shellReady &&
        (state.evaluationsStatus == SectionStatus.loading ||
            state.evaluationsStatus == SectionStatus.initial);

    if (isInitialLoading) {
      return const AppLoadingWidget();
    }

    if (state.evaluationsStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.evaluationsError ?? 'حدث خطأ',
        onRetry: _retry,
      );
    }

    final source = state.evaluationsStatus == SectionStatus.loaded
        ? state.evaluations
        : _cachedEvaluations;
    final items = _filtered(source);

    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    size: 56,
                    color: AppColors.textHint.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد تقييمات بعد',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final record = items[i];
          return _EvaluationCard(
            record: record,
            isLast: i == items.length - 1,
            onReviewPending: record.isPendingReview &&
                    TeacherWorkflowOwnership.canExecute(context)
                ? () => _showReviewPendingSheet(context, record)
                : null,
            onEdit: !record.isPendingReview &&
                    TeacherWorkflowOwnership.canExecute(context) &&
                    sl<EvaluationService>().canOpenSessionEvaluation(record)
                ? () => _showEditEvaluationSheet(record)
                : null,
          );
        },
      ),
    );
  }

  void _showReviewPendingSheet(
    BuildContext context,
    RecitationRecordEntity record,
  ) {
    final bloc = context.read<TeacherBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _ReviewPendingSheet(record: record),
      ),
    ).whenComplete(() {
      bloc.add(const ResetRecitationSubmissionEvent());
    });
  }
}

// ── Headers ───────────────────────────────────────────────────────────────────

class _EvalsHeader extends StatelessWidget {
  final bool canWrite;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  const _EvalsHeader({
    required this.canWrite,
    required this.onBack,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top + 8, 16, 12),
        child: Row(
          children: [
            if (canWrite)
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: AppColors.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تقييم جديد',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 40),
            Expanded(
              child: Text(
                'التقييمات',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Material(
              color: AppColors.surfaceGrey,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textPrimary,
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

class _EmbeddedHeader extends StatelessWidget {
  final bool canWrite;
  final VoidCallback onAdd;

  const _EmbeddedHeader({required this.canWrite, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: ListTile(
        title: Text(
          'التقييمات',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: canWrite
            ? TextButton(
                onPressed: onAdd,
                child: Text(
                  '+ تقييم جديد',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ── Timeline card ─────────────────────────────────────────────────────────────

class _EvaluationCard extends StatelessWidget {
  final RecitationRecordEntity record;
  final bool isLast;
  final VoidCallback? onReviewPending;
  final VoidCallback? onEdit;

  const _EvaluationCard({
    required this.record,
    required this.isLast,
    this.onReviewPending,
    this.onEdit,
  });

  bool get _isPending => record.isPendingReview;

  Color get _dotColor {
    if (_isPending) return AppColors.secondary;
    final grade = record.grade ?? record.behaviorGrade;
    if (grade == null) return AppColors.textHint;
    return _gradeColor(grade);
  }

  RecitationGrade? get _memorizationGrade =>
      record.type == RecitationType.memorization ? record.grade : null;

  RecitationGrade? get _reviewGrade =>
      record.type == RecitationType.review ? record.grade : null;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline on the start (right in RTL)
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 28),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              elevation: 0,
              shadowColor: AppColors.softShadow,
              child: InkWell(
                onTap: onReviewPending ?? onEdit,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.softShadow,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _hijriDateLabel(record.date),
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              record.studentName.trim().isEmpty
                                  ? 'طالب'
                                  : record.studentName.trim(),
                              textAlign: TextAlign.left,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_isPending) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBg,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusFull,
                                ),
                              ),
                              child: Text(
                                'بانتظار المراجعة',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_isPending) ...[
                        const SizedBox(height: 12),
                        Text(
                          record.audioUrl != null &&
                                  record.audioUrl!.trim().isNotEmpty
                              ? 'تسميع مرسل من الطالب (يتوفر تسجيل صوتي) — اضغط للمراجعة'
                              : 'تسميع مرسل من الطالب — اضغط للمراجعة',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'مراجعة',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _GradeBox(
                                label: 'الحفظ',
                                grade: _memorizationGrade,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GradeBox(
                                label: 'المراجعة',
                                grade: _reviewGrade,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GradeBox(
                                label: 'السلوك',
                                grade: record.behaviorGrade,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!_isPending &&
                          record.notes != null &&
                          record.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGrey,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusM),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _notesIcon,
                                size: 16,
                                color: _notesIconColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  record.notes!.trim(),
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData get _notesIcon {
    final g = record.grade;
    if (g == RecitationGrade.needsRetry) return Icons.error_outline_rounded;
    return Icons.info_outline_rounded;
  }

  Color get _notesIconColor {
    final g = record.grade;
    if (g == RecitationGrade.needsRetry) return AppColors.error;
    return AppColors.info;
  }
}

class _GradeBox extends StatelessWidget {
  final String label;
  final RecitationGrade? grade;

  const _GradeBox({required this.label, required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = grade == null ? AppColors.textHint : _gradeColor(grade!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            grade?.label ?? '—',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color _gradeColor(RecitationGrade grade) => switch (grade) {
  RecitationGrade.excellent => AppColors.gradeExcellent,
  RecitationGrade.veryGood => AppColors.gradeVeryGood,
  RecitationGrade.good => AppColors.gradeGood,
  RecitationGrade.needsRetry => AppColors.gradeNeedsWork,
};

String _hijriDateLabel(DateTime date) {
  HijriCalendar.setLocal('ar');
  final h = HijriCalendar.fromDate(date);
  return teacherHomeEasternDigits(h.toFormat('dd MMMM yyyy'));
}

// ── Review pending sheet ──────────────────────────────────────────────────────

class _ReviewPendingSheet extends StatefulWidget {
  final RecitationRecordEntity record;

  const _ReviewPendingSheet({required this.record});

  @override
  State<_ReviewPendingSheet> createState() => _ReviewPendingSheetState();
}

class _ReviewPendingSheetState extends State<_ReviewPendingSheet> {
  RecitationGrade _typeGrade = RecitationGrade.good;
  RecitationGrade _behGrade = RecitationGrade.good;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _typeLabel =>
      widget.record.type == RecitationType.memorization ? 'الحفظ' : 'المراجعة';

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<TeacherBloc, TeacherState>(
        listenWhen: (prev, curr) =>
            prev.recitationSubmissionStatus != curr.recitationSubmissionStatus,
        listener: (context, state) {
          if (state.recitationSubmissionStatus == SubmissionStatus.success) {
            Navigator.pop(context);
            if (state.recitationEventsUnpublished) {
              AppSnackBar.showInfo(
                context,
                'تم حفظ المراجعة، لكن تعذّر نشر التحديثات',
              );
            } else {
              AppSnackBar.showSuccess(context, 'تم حفظ المراجعة بنجاح');
            }
            context.read<TeacherBloc>().add(
              const ResetRecitationSubmissionEvent(),
            );
          } else if (state.recitationSubmissionStatus ==
              SubmissionStatus.error) {
            AppSnackBar.showError(
              context,
              state.recitationSubmissionError ?? 'فشل حفظ المراجعة',
            );
            context.read<TeacherBloc>().add(
              const ResetRecitationSubmissionEvent(),
            );
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusXL),
            ),
          ),
          padding: EdgeInsets.only(
            top: AppSizes.paddingL,
            left: AppSizes.paddingM,
            right: AppSizes.paddingM,
            bottom:
                MediaQuery.viewInsetsOf(context).bottom + AppSizes.paddingL,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'مراجعة التسميع',
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  record.studentName,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (record.audioUrl != null &&
                    record.audioUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'يتوفر تسجيل صوتي من الطالب',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SheetLabel(_typeLabel),
                _GradeSelector(
                  value: _typeGrade,
                  onChanged: (g) => setState(() => _typeGrade = g),
                ),
                const SizedBox(height: 12),
                const _SheetLabel('السلوك'),
                _GradeSelector(
                  value: _behGrade,
                  onChanged: (g) => setState(() => _behGrade = g),
                ),
                const SizedBox(height: 16),
                const _SheetLabel('ملاحظات (اختياري)'),
                AppTextField(
                  hint: 'أضف ملاحظاتك هنا...',
                  controller: _notesCtrl,
                ),
                const SizedBox(height: 24),
                BlocBuilder<TeacherBloc, TeacherState>(
                  buildWhen: (p, c) =>
                      p.recitationSubmissionStatus !=
                      c.recitationSubmissionStatus,
                  builder: (context, state) {
                    final loading = state.recitationSubmissionStatus ==
                        SubmissionStatus.submitting;
                    return AppButton(
                      label: 'حفظ المراجعة',
                      isLoading: loading,
                      onPressed: loading ? null : _submit,
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

  void _submit() {
    if (!TeacherWorkflowOwnership.canExecute(context)) {
      AppSnackBar.showInfo(context, 'مراجعة التسميع ملك معلم الحلقة');
      return;
    }
    context.read<TeacherBloc>().add(
      UpdateRecitationReviewEvent(
        recordId: widget.record.id,
        halaqaId: widget.record.halaqaId,
        grade: _typeGrade,
        behaviorGrade: _behGrade,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
  }
}

// ── Teacher evaluation sheet (presentation only — model from EvaluationService)

class _TeacherEvaluationSheet extends StatefulWidget {
  final EvaluationOpenModel initial;
  final List<RecitationRecordEntity> seedRecords;

  const _TeacherEvaluationSheet({
    required this.initial,
    required this.seedRecords,
  });

  @override
  State<_TeacherEvaluationSheet> createState() =>
      _TeacherEvaluationSheetState();
}

class _TeacherEvaluationSheetState extends State<_TeacherEvaluationSheet> {
  late EvaluationOpenModel _model;
  late RecitationGrade _typeGrade;
  late RecitationGrade _behGrade;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyModel(widget.initial);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applyModel(EvaluationOpenModel model) {
    _model = model;
    _typeGrade = model.typeGrade;
    _behGrade = model.behaviorGrade;
    if (_notesCtrl.text != model.notes) {
      _notesCtrl.text = model.notes;
    }
  }

  List<RecitationRecordEntity> _recordsSource() {
    final live = context.read<TeacherBloc>().state.evaluations;
    return live.isNotEmpty ? live : widget.seedRecords;
  }

  void _reopenFromService({
    String? studentId,
    RecitationType? type,
  }) {
    final result = sl<EvaluationService>().openEvaluation(
      halaqaId: _model.halaqaId,
      records: _recordsSource(),
      studentId: studentId ?? _model.studentId,
      type: type ?? _model.type,
      sessionId: _model.sessionId,
      sessionDate: _model.sessionDate,
      identityLocked: _model.identityLocked,
    );
    if (!result.isReady) return;
    setState(() => _applyModel(result.model!));
  }

  void _onStudentChanged(String? studentId) {
    if (_model.identityLocked) return;
    _reopenFromService(studentId: studentId);
  }

  void _onTypeChanged(RecitationType type) {
    if (_model.identityLocked) return;
    _reopenFromService(type: type);
  }

  void _retryStudents() {
    context.read<TeacherBloc>().add(
      LoadHalaqaStudentsEvent(_model.halaqaId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _model.mode == EvaluationSheetMode.edit
        ? 'تعديل التقييم'
        : 'تقييم جديد';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<TeacherBloc, TeacherState>(
        listenWhen: (prev, curr) =>
            prev.recitationSubmissionStatus != curr.recitationSubmissionStatus,
        listener: (context, state) {
          if (state.recitationSubmissionStatus == SubmissionStatus.success) {
            Navigator.pop(context);
            AppSnackBar.showSuccess(context, 'تم حفظ التقييم بنجاح');
            context.read<TeacherBloc>().add(
              const ResetRecitationSubmissionEvent(),
            );
          } else if (state.recitationSubmissionStatus ==
              SubmissionStatus.error) {
            AppSnackBar.showError(
              context,
              state.recitationSubmissionError ?? 'فشل حفظ التقييم',
            );
            context.read<TeacherBloc>().add(
              const ResetRecitationSubmissionEvent(),
            );
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusXL),
            ),
          ),
          padding: EdgeInsets.only(
            top: AppSizes.paddingL,
            left: AppSizes.paddingM,
            right: AppSizes.paddingM,
            bottom:
                MediaQuery.viewInsetsOf(context).bottom + AppSizes.paddingL,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                const _SheetLabel('الطالب'),
                BlocBuilder<TeacherBloc, TeacherState>(
                  buildWhen: (previous, current) =>
                      previous.studentsStatus != current.studentsStatus ||
                      previous.students != current.students ||
                      previous.studentsError != current.studentsError,
                  builder: (context, state) {
                    if (state.studentsStatus == SectionStatus.loading ||
                        state.studentsStatus == SectionStatus.initial) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (state.studentsStatus == SectionStatus.error) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            state.studentsError ?? 'فشل تحميل الطلاب',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          TextButton(
                            onPressed: _retryStudents,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      );
                    }
                    if (state.students.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'لا يوجد طلاب في هذه الحلقة',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: _retryStudents,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      );
                    }
                    final value = _model.studentId != null &&
                            state.students.any(
                              (s) => s.uid == _model.studentId,
                            )
                        ? _model.studentId
                        : null;
                    return DropdownButtonFormField<String>(
                      key: ValueKey('student-${_model.studentId}'),
                      initialValue: value,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceGrey,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusM),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      hint: const Text('اختر طالباً'),
                      items: state.students
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.uid,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged:
                          _model.identityLocked ? null : _onStudentChanged,
                    );
                  },
                ),
                const SizedBox(height: 16),
                const _SheetLabel('نوع التقييم'),
                Row(
                  children: [
                    Expanded(
                      child: _TypeChip(
                        label: 'حفظ',
                        selected: _model.type == RecitationType.memorization,
                        onTap: () =>
                            _onTypeChanged(RecitationType.memorization),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TypeChip(
                        label: 'مراجعة',
                        selected: _model.type == RecitationType.review,
                        onTap: () => _onTypeChanged(RecitationType.review),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SheetLabel(
                  _model.type == RecitationType.memorization
                      ? 'الحفظ'
                      : 'المراجعة',
                ),
                _GradeSelector(
                  value: _typeGrade,
                  onChanged: (g) => setState(() => _typeGrade = g),
                ),
                const SizedBox(height: 12),
                const _SheetLabel('السلوك'),
                _GradeSelector(
                  value: _behGrade,
                  onChanged: (g) => setState(() => _behGrade = g),
                ),
                const SizedBox(height: 16),
                const _SheetLabel('ملاحظات (اختياري)'),
                AppTextField(
                  hint: 'أضف ملاحظاتك هنا...',
                  controller: _notesCtrl,
                ),
                const SizedBox(height: 24),
                BlocBuilder<TeacherBloc, TeacherState>(
                  buildWhen: (previous, current) =>
                      previous.recitationSubmissionStatus !=
                      current.recitationSubmissionStatus,
                  builder: (context, state) {
                    final isLoading = state.recitationSubmissionStatus ==
                        SubmissionStatus.submitting;
                    return AppButton(
                      label: _model.mode == EvaluationSheetMode.edit
                          ? 'حفظ التعديل'
                          : 'حفظ التقييم',
                      isLoading: isLoading,
                      onPressed: _model.identity == null || isLoading
                          ? null
                          : _submit,
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

  void _submit() {
    final identity = _model.identity;
    if (identity == null) return;
    if (!TeacherWorkflowOwnership.canExecute(context)) {
      AppSnackBar.showInfo(context, 'حفظ التقييم ملك معلم الحلقة');
      return;
    }
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لحفظ التقييم');
      return;
    }

    final students = context.read<TeacherBloc>().state.students;
    final student = students.firstWhere((s) => s.uid == identity.studentId);

    context.read<TeacherBloc>().add(
      UpsertTeacherEvaluationEvent(
        identity: identity,
        sessionDate: _model.sessionDate,
        teacherId: authState.user.uid,
        studentName: student.name,
        grade: _typeGrade,
        behaviorGrade: _behGrade,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTextStyles.labelLarge),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceGrey,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeSelector extends StatelessWidget {
  final RecitationGrade value;
  final void Function(RecitationGrade) onChanged;

  const _GradeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RecitationGrade.values.map((g) {
        final selected = g == value;
        final color = _gradeColor(g);
        return Material(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: InkWell(
            onTap: () => onChanged(g),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                g.label,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.onPrimary : color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
