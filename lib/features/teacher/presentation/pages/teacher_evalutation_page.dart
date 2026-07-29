import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../utils/teacher_workflow_ownership.dart';

class TeacherEvaluationsPage extends StatefulWidget {
  final String halaqaId;

  const TeacherEvaluationsPage({super.key, required this.halaqaId});

  @override
  State<TeacherEvaluationsPage> createState() => _TeacherEvaluationsPageState();
}

class _TeacherEvaluationsPageState extends State<TeacherEvaluationsPage> {
  int _filterIndex = 0;
  final _filters = const ['هذا الشهر', 'الشهر الماضي', 'الكل'];

  /// After first successful evaluations load, keep the list visible during reload.
  bool _shellReady = false;
  List<RecitationRecordEntity> _cachedEvaluations = const [];

  @override
  void initState() {
    super.initState();
    final bloc = context.read<TeacherBloc>();
    bloc.add(LoadHalaqaStudentsEvent(widget.halaqaId));
    bloc.add(LoadHalaqaEvaluationsEvent(widget.halaqaId));
  }

  void _retry() {
    context.read<TeacherBloc>().add(
      LoadHalaqaEvaluationsEvent(widget.halaqaId),
    );
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeacherBloc, TeacherState>(
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
        appBar: AppBar(
          title: const Text('التقييمات'),
          actions: [
            if (TeacherWorkflowOwnership.canExecute(context))
              TextButton.icon(
                onPressed: () => _showAddEvaluationSheet(context),
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  '+ تقييم جديد',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        body: BlocBuilder<TeacherBloc, TeacherState>(
          buildWhen: (previous, current) =>
              previous.evaluationsStatus != current.evaluationsStatus ||
              previous.evaluations != current.evaluations ||
              previous.evaluationsError != current.evaluationsError ||
              previous.studentsStatus != current.studentsStatus ||
              previous.students != current.students,
          builder: (context, state) {
            final isRefreshing =
                _shellReady &&
                (state.evaluationsStatus == SectionStatus.loading);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.paddingM,
                    AppSizes.paddingM,
                    AppSizes.paddingM,
                    0,
                  ),
                  child: Row(
                    children: List.generate(_filters.length, (i) {
                      final selected = i == _filterIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _filterIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(left: i < 2 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusFull,
                              ),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              _filters[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 13,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
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
                const SizedBox(height: 16),
                Expanded(child: _buildList(state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(TeacherState state) {
    final isInitialLoading =
        !_shellReady &&
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
        onRefresh: () async {
          _retry();
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'لا توجد تقييمات بعد',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        _retry();
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final record = items[i];
          return _EvaluationCard(
            record: record,
            onReviewPending:
                record.isPendingReview &&
                    TeacherWorkflowOwnership.canExecute(context)
                ? () => _showReviewPendingSheet(context, record)
                : null,
          );
        },
      ),
    );
  }

  void _showAddEvaluationSheet(BuildContext context) {
    final bloc = context.read<TeacherBloc>();
    if (bloc.state.students.isEmpty ||
        bloc.state.studentsStatus == SectionStatus.error) {
      bloc.add(LoadHalaqaStudentsEvent(widget.halaqaId));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _AddEvaluationSheet(halaqaId: widget.halaqaId),
      ),
    ).whenComplete(() {
      bloc.add(const ResetRecitationSubmissionEvent());
    });
  }

  void _showReviewPendingSheet(
    BuildContext context,
    RecitationRecordEntity record,
  ) {
    final bloc = context.read<TeacherBloc>();
    showModalBottomSheet(
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

class _EvaluationCard extends StatelessWidget {
  final RecitationRecordEntity record;
  final VoidCallback? onReviewPending;

  const _EvaluationCard({required this.record, this.onReviewPending});

  bool get _isPending => record.isPendingReview;

  Color get _dotColor {
    if (_isPending) return AppColors.secondary;
    final grade = record.grade;
    if (grade == null) return AppColors.textHint;
    return switch (grade) {
      RecitationGrade.excellent => AppColors.secondary,
      RecitationGrade.veryGood => AppColors.primary,
      RecitationGrade.good => AppColors.info,
      RecitationGrade.needsRetry => AppColors.error,
    };
  }

  String get _dateLabel => formatDateYmd(record.date);

  String get _typeLabel =>
      record.type == RecitationType.memorization ? 'الحفظ' : 'المراجعة';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _dotColor,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 140, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            onTap: onReviewPending,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (_isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        ),
                        child: Text(
                          'بانتظار المراجعة',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(_dateLabel, style: AppTextStyles.labelSmall),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.studentName.isNotEmpty ? record.studentName : 'طالب',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (record.versesRange.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(record.versesRange, style: AppTextStyles.labelSmall),
                ],
                if (_isPending) ...[
                  const SizedBox(height: 10),
                  Text(
                    'تسميع مرسل من الطالب — اضغط للمراجعة',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _GradeBox(label: 'السلوك', grade: record.behaviorGrade),
                      const SizedBox(width: 8),
                      _GradeBox(label: _typeLabel, grade: record.grade),
                    ],
                  ),
                ],
                if (!_isPending &&
                    record.notes != null &&
                    record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          record.notes!,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.info,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GradeBox extends StatelessWidget {
  final String label;
  final RecitationGrade? grade;

  const _GradeBox({required this.label, required this.grade});

  Color get _color {
    if (grade == null) return AppColors.textHint;
    return switch (grade!) {
      RecitationGrade.excellent => AppColors.gradeExcellent,
      RecitationGrade.veryGood => AppColors.gradeVeryGood,
      RecitationGrade.good => AppColors.gradeGood,
      RecitationGrade.needsRetry => AppColors.gradeNeedsWork,
    };
  }

  String get _labelText => grade?.label ?? '—';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Text(
            _labelText,
            style: AppTextStyles.labelMedium.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

/// مراجعة تسميع معلّق — يحدّث نفس مستند recitationRecords (Slice 3).
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
    return BlocListener<TeacherBloc, TeacherState>(
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
        } else if (state.recitationSubmissionStatus == SubmissionStatus.error) {
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
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
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
              const Text('مراجعة التسميع', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 12),
              Text(
                record.studentName.isNotEmpty ? record.studentName : 'طالب',
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.right,
              ),
              if (record.versesRange.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  record.versesRange,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
              if ((record.audioUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'يتوفر تسجيل صوتي من الطالب',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
              const SizedBox(height: 20),
              _Label(_typeLabel),
              _GradeSelector(
                value: _typeGrade,
                onChanged: (g) => setState(() => _typeGrade = g),
              ),
              const SizedBox(height: 12),
              const _Label('السلوك'),
              _GradeSelector(
                value: _behGrade,
                onChanged: (g) => setState(() => _behGrade = g),
              ),
              const SizedBox(height: 16),
              const _Label('ملاحظات (اختياري)'),
              AppTextField(hint: 'أضف ملاحظاتك هنا...', controller: _notesCtrl),
              const SizedBox(height: 24),
              BlocBuilder<TeacherBloc, TeacherState>(
                buildWhen: (previous, current) =>
                    previous.recitationSubmissionStatus !=
                    current.recitationSubmissionStatus,
                builder: (context, state) {
                  final isLoading =
                      state.recitationSubmissionStatus ==
                      SubmissionStatus.submitting;
                  return AppButton(
                    label: 'حفظ المراجعة',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _submit,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لحفظ المراجعة');
      return;
    }

    context.read<TeacherBloc>().add(
      UpdateRecitationReviewEvent(
        recordId: widget.record.id,
        halaqaId: widget.record.halaqaId,
        grade: _typeGrade,
        behaviorGrade: _behGrade,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
      ),
    );
  }
}

class _AddEvaluationSheet extends StatefulWidget {
  final String halaqaId;

  const _AddEvaluationSheet({required this.halaqaId});

  @override
  State<_AddEvaluationSheet> createState() => _AddEvaluationSheetState();
}

class _AddEvaluationSheetState extends State<_AddEvaluationSheet> {
  String? _selectedStudentId;
  RecitationGrade _typeGrade = RecitationGrade.good;
  RecitationGrade _behGrade = RecitationGrade.good;
  RecitationType _type = RecitationType.memorization;
  final _versesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _versesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _retryStudents() {
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(widget.halaqaId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeacherBloc, TeacherState>(
      listenWhen: (prev, curr) =>
          prev.recitationSubmissionStatus != curr.recitationSubmissionStatus,
      listener: (context, state) {
        if (state.recitationSubmissionStatus == SubmissionStatus.success) {
          Navigator.pop(context);
          AppSnackBar.showSuccess(context, 'تم حفظ التقييم بنجاح');
          context.read<TeacherBloc>().add(
            const ResetRecitationSubmissionEvent(),
          );
        } else if (state.recitationSubmissionStatus == SubmissionStatus.error) {
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
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
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
              const Text('تقييم جديد', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 20),
              const _Label('الطالب'),
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
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _retryStudents,
                            child: const Text('إعادة المحاولة'),
                          ),
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
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _retryStudents,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ),
                      ],
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue:
                        _selectedStudentId != null &&
                            state.students.any(
                              (s) => s.uid == _selectedStudentId,
                            )
                        ? _selectedStudentId
                        : null,
                    isExpanded: true,
                    alignment: AlignmentDirectional.centerEnd,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    hint: const Text('اختر طالباً'),
                    items: state.students
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.uid,
                            child: Text(
                              s.name,
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStudentId = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              const _Label('نوع التقييم'),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _TypeChip(
                    label: 'مراجعة',
                    selected: _type == RecitationType.review,
                    onTap: () => setState(() => _type = RecitationType.review),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: 'حفظ',
                    selected: _type == RecitationType.memorization,
                    onTap: () =>
                        setState(() => _type = RecitationType.memorization),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _Label('نطاق الآيات'),
              AppTextField(
                hint: 'مثال: سورة الملك ١-١٠',
                controller: _versesCtrl,
              ),
              const SizedBox(height: 16),
              _Label(
                _type == RecitationType.memorization ? 'الحفظ' : 'المراجعة',
              ),
              _GradeSelector(
                value: _typeGrade,
                onChanged: (g) => setState(() => _typeGrade = g),
              ),
              const SizedBox(height: 12),
              const _Label('السلوك'),
              _GradeSelector(
                value: _behGrade,
                onChanged: (g) => setState(() => _behGrade = g),
              ),
              const SizedBox(height: 16),
              const _Label('ملاحظات (اختياري)'),
              AppTextField(hint: 'أضف ملاحظاتك هنا...', controller: _notesCtrl),
              const SizedBox(height: 24),
              BlocBuilder<TeacherBloc, TeacherState>(
                buildWhen: (previous, current) =>
                    previous.recitationSubmissionStatus !=
                    current.recitationSubmissionStatus,
                builder: (context, state) {
                  final isLoading =
                      state.recitationSubmissionStatus ==
                      SubmissionStatus.submitting;
                  return AppButton(
                    label: 'حفظ التقييم',
                    isLoading: isLoading,
                    onPressed: _selectedStudentId == null || isLoading
                        ? null
                        : _submit,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_selectedStudentId == null) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لحفظ التقييم');
      return;
    }

    final students = context.read<TeacherBloc>().state.students;
    final student = students.firstWhere((s) => s.uid == _selectedStudentId);

    context.read<TeacherBloc>().add(
      AddRecitationRecordEvent(
        RecitationRecordEntity(
          id: '',
          studentId: _selectedStudentId!,
          studentName: student.name,
          teacherId: authState.user.uid,
          halaqaId: widget.halaqaId,
          date: DateTime.now(),
          type: _type,
          versesRange: _versesCtrl.text.trim(),
          grade: _typeGrade,
          behaviorGrade: _behGrade,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTextStyles.labelLarge,
      textAlign: TextAlign.right,
    ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: RecitationGrade.values.map((g) {
        final selected = g == value;
        final color = _colorForGrade(g);
        return GestureDetector(
          onTap: () => onChanged(g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Text(
              g.label,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _colorForGrade(RecitationGrade g) => switch (g) {
    RecitationGrade.excellent => AppColors.gradeExcellent,
    RecitationGrade.veryGood => AppColors.gradeVeryGood,
    RecitationGrade.good => AppColors.gradeGood,
    RecitationGrade.needsRetry => AppColors.gradeNeedsWork,
  };
}
