import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/recitation_record_entity.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

class StudentEvaluationsPage extends StatefulWidget {
  const StudentEvaluationsPage({super.key});

  @override
  State<StudentEvaluationsPage> createState() => _StudentEvaluationsPageState();
}

class _StudentEvaluationsPageState extends State<StudentEvaluationsPage> {
  int _filterIndex = 0;
  final _filters = const ['هذا الشهر', 'الشهر الماضي', 'الكل'];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<StudentBloc>().add(
        LoadRecitationRecordsEvent(authState.user.uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocBuilder<StudentBloc, StudentState>(
            builder: (context, state) {
              if (state.recitationStatus == SectionStatus.loading &&
                  state.recitationRecords.isEmpty) {
                return const AppLoadingWidget();
              }

              if (state.recitationStatus == SectionStatus.error &&
                  state.recitationRecords.isEmpty) {
                return AppErrorWidget(
                  message: state.recitationError ?? 'تعذر تحميل التقييمات',
                  onRetry: _reload,
                );
              }

              final records = _filteredRecords(state.recitationRecords);

              return Column(
                children: [
                  _EvaluationsHeader(onBack: () => Navigator.maybePop(context)),
                  _PeriodTabs(
                    filters: _filters,
                    selectedIndex: _filterIndex,
                    onChanged: (index) => setState(() => _filterIndex = index),
                  ),
                  _EvaluationMetrics(records: records),
                  Expanded(
                    child: records.isEmpty
                        ? const _EmptyEvaluations()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                            itemCount: records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 22),
                            itemBuilder: (context, index) {
                              return _EvaluationTimelineItem(
                                record: records[index],
                                color: index.isEven
                                    ? AppColors.secondary
                                    : const Color(0xFF28C5CF),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _reload() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<StudentBloc>().add(
        LoadRecitationRecordsEvent(auth.user.uid),
      );
    }
  }

  List<RecitationRecordEntity> _filteredRecords(
    List<RecitationRecordEntity> records,
  ) {
    final now = DateTime.now();
    return records.where((record) {
      if (_filterIndex == 2) return true;
      final target = _filterIndex == 0
          ? DateTime(now.year, now.month)
          : DateTime(now.year, now.month - 1);
      return record.date.year == target.year &&
          record.date.month == target.month;
    }).toList();
  }
}

class _EvaluationsHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _EvaluationsHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _SoftIconButton(
              icon: Icons.chevron_left_rounded,
              onTap: onBack,
            ),
          ),
          const Text(
            '📋 التقييمات',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _PeriodTabs({
    required this.filters,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
      child: Row(
        children: List.generate(filters.length, (index) {
          final selected = index == selectedIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: GestureDetector(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 54,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF24C6CF)
                        : const Color(0xFFF3F5F8),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    filters[index],
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EvaluationMetrics extends StatelessWidget {
  final List<RecitationRecordEntity> records;

  const _EvaluationMetrics({required this.records});

  @override
  Widget build(BuildContext context) {
    final memorization = _averageFor(RecitationType.memorization);
    final review = _averageFor(RecitationType.review);
    final behavior = records.isEmpty
        ? 0
        : () {
            final scored = records
                .map((record) => record.behaviorGrade)
                .whereType<RecitationGrade>()
                .map(_gradePercent)
                .toList();
            if (scored.isEmpty) return 0;
            return scored.reduce((a, b) => a + b) ~/ scored.length;
          }();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          _MetricTile(
            value: '$memorization%',
            label: 'الحفظ',
            color: const Color(0xFFCFF4DF),
            textColor: const Color(0xFF20AF68),
          ),
          const SizedBox(width: 10),
          _MetricTile(
            value: '${((memorization + review) / 2).round()}%',
            label: 'التجويد',
            color: const Color(0xFFCFF4F6),
            textColor: const Color(0xFF14AEB8),
          ),
          const SizedBox(width: 10),
          _MetricTile(
            value: '$behavior%',
            label: 'الحضور',
            color: const Color(0xFFFFF2BF),
            textColor: const Color(0xFFD9A409),
          ),
          const SizedBox(width: 10),
          _MetricTile(
            value: '${records.length}',
            label: 'الواجبات',
            color: const Color(0xFFE9E1FF),
            textColor: const Color(0xFF8858FF),
          ),
        ],
      ),
    );
  }

  int _averageFor(RecitationType type) {
    final typed = records
        .where((record) => record.type == type && record.grade != null)
        .toList();
    if (typed.isEmpty) return 0;
    final total = typed
        .map((record) => _gradePercent(record.grade!))
        .reduce((a, b) => a + b);
    return total ~/ typed.length;
  }

  int _gradePercent(RecitationGrade grade) => switch (grade) {
    RecitationGrade.excellent => 96,
    RecitationGrade.veryGood => 88,
    RecitationGrade.good => 75,
    RecitationGrade.needsRetry => 60,
  };
}

class _MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color textColor;

  const _MetricTile({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationTimelineItem extends StatelessWidget {
  final RecitationRecordEntity record;
  final Color color;

  const _EvaluationTimelineItem({required this.record, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _EvaluationCard(record: record)),
        const SizedBox(width: 16),
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
            Container(width: 4, height: 230, color: const Color(0xFFE4E8EE)),
          ],
        ),
      ],
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final RecitationRecordEntity record;

  const _EvaluationCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_formatWeekday(record.date)} ${record.date.day} ذو القعدة 1446 📅',
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'سورة الملك - الآيات ${record.versesRange}',
            textAlign: TextAlign.right,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _GradeBox(
                  label: 'الحفظ',
                  grade: record.type == RecitationType.memorization
                      ? record.grade
                      : record.behaviorGrade,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradeBox(label: 'التجويد', grade: record.grade),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradeBox(
                  label: 'المراجعة',
                  grade: record.type == RecitationType.review
                      ? record.grade
                      : record.behaviorGrade,
                ),
              ),
            ],
          ),
          if ((record.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '💬 "${record.notes!}"',
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: const Color(0xFF526070),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatWeekday(DateTime date) {
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[date.weekday - 1];
  }
}

class _GradeBox extends StatelessWidget {
  final String label;
  final RecitationGrade? grade;

  const _GradeBox({required this.label, required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(grade);
    return Container(
      height: 94,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          Text(
            _labelFor(grade),
            style: AppTextStyles.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: grade == null ? 13 : null,
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(RecitationGrade? grade) => grade.displayLabel;

  Color _colorFor(RecitationGrade? grade) => switch (grade) {
    RecitationGrade.excellent => const Color(0xFF21B773),
    RecitationGrade.veryGood => const Color(0xFF14AEB8),
    RecitationGrade.good => const Color(0xFFD9A409),
    RecitationGrade.needsRetry => AppColors.error,
    null => AppColors.textSecondary,
  };
}

class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SoftIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E6EC)),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
    );
  }
}

class _EmptyEvaluations extends StatelessWidget {
  const _EmptyEvaluations();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'لا توجد تقييمات في هذه الفترة',
        style: AppTextStyles.bodyLarge,
      ),
    );
  }
}
