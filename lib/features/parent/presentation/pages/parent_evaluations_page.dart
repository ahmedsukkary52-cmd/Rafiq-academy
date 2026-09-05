import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../../student/domain/usecases/get_recitation_records_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../domain/parent_performance.dart';
import '../bloc/parent_bloc.dart';
import '../parent_child_access.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentEvaluationsPage extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ParentEvaluationsPage({
    super.key,
    required this.studentId,
    this.studentName,
  });

  @override
  State<ParentEvaluationsPage> createState() => _ParentEvaluationsPageState();
}

class _ParentEvaluationsPageState extends State<ParentEvaluationsPage> {
  bool _loading = true;
  String? _error;
  List<RecitationRecordEntity> _records = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final parentState = context.read<ParentBloc>().state;
    if (!ParentChildAccess.owns(
      state: parentState,
      studentId: widget.studentId,
    )) {
      setState(() {
        _loading = false;
        _error = ParentChildAccess.deniedMessage;
        _records = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetRecitationRecordsUseCase>()(
      StudentUidParams(widget.studentId),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      // Parent only ever sees Supervisor-reviewed evaluations.
      (records) => setState(() {
        _loading = false;
        _records = records.where((r) => !r.isPendingReview).toList();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.studentName ?? '').trim();
    final counts = ParentPerformance.gradeCounts(_records);
    return ParentSubpageScaffold(
      title: name.isEmpty ? 'التقييمات' : 'التقييمات — $name',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _GradeCount(
                  label: RecitationGrades.excellent,
                  color: const Color(0xFFE8F5E9),
                  value: counts[RecitationGrades.excellent] ?? 0,
                ),
                const SizedBox(width: 8),
                _GradeCount(
                  label: RecitationGrades.veryGood,
                  color: AppColors.primaryLight,
                  value: counts[RecitationGrades.veryGood] ?? 0,
                ),
                const SizedBox(width: 8),
                _GradeCount(
                  label: RecitationGrades.good,
                  color: AppColors.secondaryBg,
                  value: counts[RecitationGrades.good] ?? 0,
                ),
                const SizedBox(width: 8),
                _GradeCount(
                  label: 'يحتاج',
                  color: AppColors.surfaceGrey,
                  value: counts['يحتاج تحسين'] ?? 0,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const ParentListCardsSkeleton()
                : _error != null
                ? AppErrorWidget(message: _error!, onRetry: _load)
                : _records.isEmpty
                ? const ParentEmptyState(
                    icon: Icons.grade_outlined,
                    title: 'لا توجد تقييمات معتمدة بعد',
                    message:
                        'يظهر كل سجل تسميع معتمد كتقييم مستقل بمحاور الحفظ والمراجعة والسلوك.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _EvaluationCard(record: _records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final RecitationRecordEntity record;

  const _EvaluationCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final typeLabel = record.type == RecitationType.memorization
        ? 'حفظ'
        : 'مراجعة';
    final title = record.versesRange.trim().isEmpty
        ? typeLabel
        : '$typeLabel — ${record.versesRange}';
    final notes = (record.notes ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatDateDmy(record.date),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AxisPill(
                label: 'الحفظ',
                grade: record.type == RecitationType.memorization
                    ? record.grade
                    : null,
              ),
              _AxisPill(
                label: 'المراجعة',
                grade: record.type == RecitationType.review
                    ? record.grade
                    : null,
              ),
              _AxisPill(label: 'السلوك', grade: record.behaviorGrade),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AxisPill extends StatelessWidget {
  final String label;
  final RecitationGrade? grade;

  const _AxisPill({required this.label, required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = parentGradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          Text(
            grade?.label ?? '—',
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

class _GradeCount extends StatelessWidget {
  final String label;
  final Color color;
  final int value;

  const _GradeCount({
    required this.label,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              parentEasternDigits('$value'),
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
