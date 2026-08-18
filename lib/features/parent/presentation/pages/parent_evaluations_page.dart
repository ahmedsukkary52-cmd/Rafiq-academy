import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../../student/domain/usecases/get_recitation_records_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../domain/parent_performance.dart';
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
      (records) => setState(() {
        _loading = false;
        _records = records;
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _GradeCount(
                  label: RecitationGrades.excellent,
                  color: AppColors.successBg,
                  value: '${counts[RecitationGrades.excellent] ?? 0}',
                ),
                const SizedBox(width: 8),
                _GradeCount(
                  label: RecitationGrades.veryGood,
                  color: AppColors.primaryLight,
                  value: '${counts[RecitationGrades.veryGood] ?? 0}',
                ),
                const SizedBox(width: 8),
                _GradeCount(
                  label: RecitationGrades.good,
                  color: AppColors.secondaryBg,
                  value: '${counts[RecitationGrades.good] ?? 0}',
                ),
                const SizedBox(width: 8),
                _GradeCount(
                  label: 'يحتاج',
                  color: AppColors.surfaceGrey,
                  value: '${counts['يحتاج تحسين'] ?? 0}',
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      final typeLabel =
                          record.type == RecitationType.memorization
                          ? 'حفظ'
                          : 'مراجعة';
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              formatDateDmy(record.date),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textHint,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record.versesRange.trim().isEmpty
                                  ? typeLabel
                                  : '$typeLabel — ${record.versesRange}',
                              style: AppTextStyles.titleLarge,
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                '$typeLabel: ${record.grade?.label ?? '—'}',
                                'سلوك: ${record.behaviorGrade?.label ?? '—'}',
                              ].join(' · '),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: parentGradeColor(record.grade),
                              ),
                              textAlign: TextAlign.right,
                            ),
                            if ((record.notes ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                record.notes!.trim(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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
  final String value;

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
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Text(
          '$value\n$label',
          style: AppTextStyles.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
