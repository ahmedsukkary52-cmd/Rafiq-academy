import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';

class TeacherEvaluationsPage extends StatefulWidget {
  final String halaqaId;

  const TeacherEvaluationsPage({super.key, required this.halaqaId});

  @override
  State<TeacherEvaluationsPage> createState() => _TeacherEvaluationsPageState();
}

class _TeacherEvaluationsPageState extends State<TeacherEvaluationsPage> {
  int _filterIndex = 0;
  final _filters = const ['هذا الشهر', 'الشهر الماضي', 'الفصل كله'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التقييمات'),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddEvaluationSheet(context),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
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
        builder: (context, state) {
          return Column(
            children: [
              // ── فلاتر الفترة ──────────────────────────────────
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

              const SizedBox(height: 16),

              // ── قائمة التقييمات ────────────────────────────────
              Expanded(
                child: state.studentsStatus == SectionStatus.loading
                    ? const AppLoadingWidget()
                    : const _MockEvaluationsList(),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddEvaluationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<TeacherBloc>(),
        child: _AddEvaluationSheet(halaqaId: widget.halaqaId),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// قائمة تقييمات تجريبية
// ══════════════════════════════════════════════════════════════════════════════

class _MockEvaluationsList extends StatelessWidget {
  const _MockEvaluationsList();

  @override
  Widget build(BuildContext context) {
    // بيانات تجريبية — ستُستبدل بـ stream حقيقي لاحقاً
    final items = [
      (
        student: 'أحمد محمد',
        date: 'يوم الأثنين، ٢٠ رمضان ١٤٤٦',
        memGrade: RecitationGrade.excellent,
        revGrade: RecitationGrade.veryGood,
        behGrade: RecitationGrade.excellent,
        notes: 'أداء استثنائي في الحفظ، ينصح بمراجعة خارج الحروف',
        dotColor: AppColors.secondary,
      ),
      (
        student: 'سارة خالد',
        date: 'يوم الأثنين، ١٤ رمضان ١٤٤٦',
        memGrade: RecitationGrade.excellent,
        revGrade: RecitationGrade.excellent,
        behGrade: RecitationGrade.veryGood,
        notes: 'تقدم مميز. تستحق الطالبة المتفوقة هذا الأسبوع',
        dotColor: AppColors.primary,
      ),
      (
        student: 'عمر سالم',
        date: 'يوم الأثنين، ٧ رمضان ١٤٤٦',
        memGrade: RecitationGrade.needsRetry,
        revGrade: RecitationGrade.needsRetry,
        behGrade: RecitationGrade.good,
        notes: 'يحتاج متابعة أسرية عاجلة. تم التواصل مع ولي الأمر',
        dotColor: AppColors.error,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        return _EvaluationCard(
          studentName: item.student,
          dateLabel: item.date,
          memGrade: item.memGrade,
          revGrade: item.revGrade,
          behGrade: item.behGrade,
          notes: item.notes,
          dotColor: item.dotColor,
        );
      },
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final String studentName;
  final String dateLabel;
  final RecitationGrade memGrade;
  final RecitationGrade revGrade;
  final RecitationGrade behGrade;
  final String notes;
  final Color dotColor;

  const _EvaluationCard({
    required this.studentName,
    required this.dateLabel,
    required this.memGrade,
    required this.revGrade,
    required this.behGrade,
    required this.notes,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot + line
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 180, color: AppColors.border),
          ],
        ),

        const SizedBox(width: 12),

        // الكارت
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // التاريخ واسم الطالب
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(dateLabel, style: AppTextStyles.labelSmall),
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
                  studentName,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 10),

                // التقييمات الثلاث
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _GradeBox(label: 'السلوك', grade: behGrade),
                    const SizedBox(width: 8),
                    _GradeBox(label: 'المراجعة', grade: revGrade),
                    const SizedBox(width: 8),
                    _GradeBox(label: 'الحفظ', grade: memGrade),
                  ],
                ),

                const SizedBox(height: 10),

                // الملاحظات
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notes,
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
            ),
          ),
        ),
      ],
    );
  }
}

class _GradeBox extends StatelessWidget {
  final String label;
  final RecitationGrade grade;

  const _GradeBox({required this.label, required this.grade});

  Color get _color => switch (grade) {
    RecitationGrade.excellent => AppColors.gradeExcellent,
    RecitationGrade.veryGood => AppColors.gradeVeryGood,
    RecitationGrade.good => AppColors.gradeGood,
    RecitationGrade.needsRetry => AppColors.gradeNeedsWork,
  };

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
            grade.label,
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

// ══════════════════════════════════════════════════════════════════════════════
// _AddEvaluationSheet - Bottom Sheet لإضافة تقييم جديد
// ══════════════════════════════════════════════════════════════════════════════

class _AddEvaluationSheet extends StatefulWidget {
  final String halaqaId;

  const _AddEvaluationSheet({required this.halaqaId});

  @override
  State<_AddEvaluationSheet> createState() => _AddEvaluationSheetState();
}

class _AddEvaluationSheetState extends State<_AddEvaluationSheet> {
  String? _selectedStudentId;
  RecitationGrade _memGrade = RecitationGrade.good;
  RecitationGrade _revGrade = RecitationGrade.good;
  RecitationGrade _behGrade = RecitationGrade.good;
  RecitationType _type = RecitationType.memorization;
  final _versesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _grades = RecitationGrade.values;

  @override
  void dispose() {
    _versesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<TeacherBloc>().state;
    final students = state.students;

    return Container(
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
            // Handle
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

            // اختيار الطالب
            const _Label('الطالب'),
            DropdownButtonFormField<String>(
              initialValue: _selectedStudentId,
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
              items: students
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.uid,
                      child: Text(s.name, textDirection: TextDirection.rtl),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedStudentId = v),
            ),

            const SizedBox(height: 16),

            // نوع التقييم
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

            // نطاق الآيات
            const _Label('نطاق الآيات'),
            AppTextField(
              hint: 'مثال: سورة الملك ١-١٠',
              controller: _versesCtrl,
            ),

            const SizedBox(height: 16),

            // تقييمات الثلاثة
            const _Label('الحفظ'),
            _GradeSelector(
              value: _memGrade,
              onChanged: (g) => setState(() => _memGrade = g),
            ),
            const SizedBox(height: 12),
            const _Label('المراجعة'),
            _GradeSelector(
              value: _revGrade,
              onChanged: (g) => setState(() => _revGrade = g),
            ),
            const SizedBox(height: 12),
            const _Label('السلوك'),
            _GradeSelector(
              value: _behGrade,
              onChanged: (g) => setState(() => _behGrade = g),
            ),

            const SizedBox(height: 16),

            // ملاحظات
            const _Label('ملاحظات (اختياري)'),
            AppTextField(hint: 'أضف ملاحظاتك هنا...', controller: _notesCtrl),

            const SizedBox(height: 24),

            // زرار الحفظ
            BlocBuilder<TeacherBloc, TeacherState>(
              builder: (context, state) {
                final isLoading =
                    state.recitationSubmissionStatus ==
                    SubmissionStatus.submitting;
                return AppButton(
                  label: 'حفظ التقييم',
                  isLoading: isLoading,
                  onPressed: _selectedStudentId == null ? null : _submit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_selectedStudentId == null) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    context.read<TeacherBloc>().add(
      AddRecitationRecordEvent(
        RecitationRecordEntity(
          id: '',
          studentId: _selectedStudentId!,
          studentName: context
              .read<TeacherBloc>()
              .state
              .students
              .firstWhere((s) => s.uid == _selectedStudentId!)
              .name,
          teacherId: authState.user.uid,
          halaqaId: widget.halaqaId,
          date: DateTime.now(),
          type: _type,
          versesRange: _versesCtrl.text.trim(),
          grade: _memGrade,
          behaviorGrade: _behGrade,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
        ),
      ),
    );

    Navigator.pop(context);
    AppSnackBar.showSuccess(context, 'تم حفظ التقييم بنجاح');
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
