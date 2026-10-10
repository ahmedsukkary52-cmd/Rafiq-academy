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
import '../widgets/student_loading_skeletons.dart';

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
        body: BlocBuilder<StudentBloc, StudentState>(
          buildWhen: (previous, current) =>
              previous.recitationRecords != current.recitationRecords ||
              previous.recitationStatus != current.recitationStatus ||
              previous.recitationError != current.recitationError,
          builder: (context, state) {
            if ((state.recitationStatus == SectionStatus.loading ||
                    state.recitationStatus == SectionStatus.initial) &&
                state.recitationRecords.isEmpty) {
              return const StudentListPageSkeleton();
            }

            if (state.recitationStatus == SectionStatus.error &&
                state.recitationRecords.isEmpty) {
              return SafeArea(
                child: AppErrorWidget(
                  message: state.recitationError ?? 'تعذر تحميل التقييمات',
                  onRetry: _reload,
                ),
              );
            }

            final records = _filteredRecords(state.recitationRecords);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                _reload();
                await Future<void>.delayed(const Duration(milliseconds: 500));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _EvaluationsHeader(
                      onBack: () => Navigator.maybePop(context),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _PeriodTabs(
                        filters: _filters,
                        selectedIndex: _filterIndex,
                        onChanged: (index) =>
                            setState(() => _filterIndex = index),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _EvaluationMetrics(records: records),
                    ),
                  ),
                  if (records.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyEvaluations(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      sliver: SliverList.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _EvaluationCard(record: records[index]);
                        },
                      ),
                    ),
                ],
              ),
            );
          },
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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          _SoftIconButton(
            icon: Icons.chevron_right_rounded,
            onTap: onBack,
          ),
          const Expanded(
            child: Text(
              '📋 التقييمات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 44),
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
    return Row(
      children: List.generate(filters.length, (index) {
        final selected = index == selectedIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: index == filters.length - 1 ? 0 : 4,
            ),
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  filters[index],
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _EvaluationMetrics extends StatelessWidget {
  final List<RecitationRecordEntity> records;

  const _EvaluationMetrics({required this.records});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricTile(
          value: _averageLabelFor(RecitationType.memorization),
          label: 'الحفظ',
          color: const Color(0xFFCFF4DF),
          textColor: const Color(0xFF20AF68),
        ),
        const SizedBox(width: 8),
        _MetricTile(
          value: _averageLabelFor(RecitationType.review),
          label: 'المراجعة',
          color: const Color(0xFFCFF4F6),
          textColor: const Color(0xFF14AEB8),
        ),
        const SizedBox(width: 8),
        _MetricTile(
          value: _behaviorLabel(),
          label: 'السلوك',
          color: const Color(0xFFFFF2BF),
          textColor: const Color(0xFFD9A409),
        ),
        const SizedBox(width: 8),
        _MetricTile(
          value: '${records.length}',
          label: 'التقييمات',
          color: const Color(0xFFE9E1FF),
          textColor: const Color(0xFF8858FF),
        ),
      ],
    );
  }

  String _averageLabelFor(RecitationType type) {
    final grades = records
        .where((record) => record.type == type && record.grade != null)
        .map((record) => record.grade!)
        .toList();
    return _nearestGradeLabel(grades);
  }

  String _behaviorLabel() {
    final grades = records
        .map((record) => record.behaviorGrade)
        .whereType<RecitationGrade>()
        .toList();
    return _nearestGradeLabel(grades);
  }

  String _nearestGradeLabel(List<RecitationGrade> grades) {
    if (grades.isEmpty) return '—';
    final total = grades.map(_gradeRank).reduce((a, b) => a + b);
    final avg = total / grades.length;
    if (avg >= 3.5) return RecitationGrade.excellent.label;
    if (avg >= 2.5) return RecitationGrade.veryGood.label;
    if (avg >= 1.5) return RecitationGrade.good.label;
    return RecitationGrade.needsRetry.label;
  }

  int _gradeRank(RecitationGrade grade) => switch (grade) {
    RecitationGrade.excellent => 4,
    RecitationGrade.veryGood => 3,
    RecitationGrade.good => 2,
    RecitationGrade.needsRetry => 1,
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
        height: 78,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: value.length > 4 ? 12 : 18,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final RecitationRecordEntity record;

  const _EvaluationCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  record.type == RecitationType.memorization ? 'حفظ' : 'مراجعة',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_formatWeekday(record.date)} ${record.date.day}/${record.date.month}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _titleFor(record),
            textAlign: TextAlign.right,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GradeBox(
                  label: record.type == RecitationType.memorization
                      ? 'الحفظ'
                      : 'المراجعة',
                  grade: record.grade,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GradeBox(label: 'السلوك', grade: record.behaviorGrade),
              ),
            ],
          ),
          if ((record.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '💬 ${record.notes!}',
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: const Color(0xFF526070),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _titleFor(RecitationRecordEntity record) {
    final range = record.versesRange.trim();
    final typeLabel = record.type == RecitationType.memorization
        ? 'حفظ'
        : 'مراجعة';
    if (range.isEmpty) return typeLabel;
    return '$typeLabel — الآيات $range';
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
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: 6),
          Text(
            grade.displayLabel,
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: grade == null ? 12 : null,
            ),
          ),
        ],
      ),
    );
  }

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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 56,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد تقييمات في هذه الفترة',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'التسميعات بانتظار مراجعة المعلم لا تظهر هنا.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
