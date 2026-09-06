import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../../student/domain/usecases/get_recitation_records_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/parent_performance.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';
import '../parent_child_access.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentReportsPage extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ParentReportsPage({super.key, this.studentId, this.studentName});

  @override
  State<ParentReportsPage> createState() => _ParentReportsPageState();
}

class _ParentReportsPageState extends State<ParentReportsPage> {
  static const _axes = ['حفظ', 'مراجعة', 'حضور', 'سلوك'];
  int _axisIndex = 0;
  List<RecitationRecordEntity> _records = const [];
  bool _recordsLoading = false;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id =
          widget.studentId ?? context.read<ParentBloc>().state.selectedChildId;
      if (id != null) {
        context.read<ParentBloc>().add(SelectChildEvent(id));
        _loadRecords(id);
      }
    });
  }

  Future<void> _loadRecords(String studentId) async {
    final parentState = context.read<ParentBloc>().state;
    if (parentState.childrenIds.isNotEmpty &&
        !ParentChildAccess.owns(state: parentState, studentId: studentId)) {
      setState(() {
        _recordsLoading = false;
        _records = const [];
        _accessError = ParentChildAccess.deniedMessage;
      });
      return;
    }

    setState(() {
      _recordsLoading = true;
      _accessError = null;
    });
    final result = await sl<GetRecitationRecordsUseCase>()(
      StudentUidParams(studentId),
    );
    if (!mounted) return;
    setState(() {
      _recordsLoading = false;
      _records = result.getOrElse((_) => const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<ParentBloc>().state.childrenIds;

    return ParentSubpageScaffold(
      title: 'التقارير',
      body: BlocConsumer<ParentBloc, ParentState>(
        listenWhen: (p, c) => p.selectedChildId != c.selectedChildId,
        listener: (context, state) {
          final id = state.selectedChildId;
          if (id != null) _loadRecords(id);
        },
        buildWhen: (p, c) =>
            p.reportStatus != c.reportStatus ||
            p.weeklyReport != c.weeklyReport ||
            p.reportError != c.reportError ||
            p.selectedChildId != c.selectedChildId ||
            p.childrenIds != c.childrenIds ||
            p.childrenSnapshots != c.childrenSnapshots,
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (children.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final id in children) ...[
                        ParentFilterChip(
                          label: state.childDisplayName(id),
                          selected: state.selectedChildId == id,
                          onTap: () => context.read<ParentBloc>().add(
                            SelectChildEvent(id),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _axes.length; i++) ...[
                      ParentFilterChip(
                        label: _axes[i],
                        selected: _axisIndex == i,
                        onTap: () => setState(() => _axisIndex = i),
                      ),
                      if (i < _axes.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_accessError != null)
                ParentEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: _accessError!,
                )
              else if (state.reportStatus == SectionStatus.initial ||
                  state.reportStatus == SectionStatus.loading ||
                  _recordsLoading)
                const ParentListCardsSkeleton(
                  itemCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                )
              else if (state.reportStatus == SectionStatus.error)
                AppErrorWidget(
                  message: state.reportError ?? 'تعذر تحميل التقرير',
                  onRetry: () {
                    final id = state.selectedChildId;
                    if (id != null) {
                      context.read<ParentBloc>().add(SelectChildEvent(id));
                    }
                  },
                )
              else if (state.weeklyReport == null && _records.isEmpty)
                const ParentEmptyState(
                  icon: Icons.assessment_outlined,
                  title: 'لا توجد بيانات تقرير بعد',
                )
              else
                _ReportBody(
                  axis: _axes[_axisIndex],
                  report: state.weeklyReport,
                  records: _records,
                  childName: state.selectedChildId == null
                      ? ''
                      : state.childDisplayName(state.selectedChildId!),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final String axis;
  final WeeklyReportEntity? report;
  final List<RecitationRecordEntity> records;
  final String childName;

  const _ReportBody({
    required this.axis,
    required this.report,
    required this.records,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    final notes = report?.teacherNotes.trim() ?? '';
    final period = report == null
        ? ''
        : parentPaymentPeriodLabel(report!.weekStart);
    // Weekly report stores the count of Supervisor-reviewed docs here.
    final reviewedCount = report?.totalVersesMemorized ?? 0;
    final attendance = report == null || report!.totalSessions == 0
        ? null
        : report!.attendancePercent;
    final lastGrade = _lastGradeLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                period.isEmpty ? 'تقرير $axis' : 'تقرير $period',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (childName.isNotEmpty)
                Text(
                  childName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MiniStat(
                    value: reviewedCount > 0
                        ? parentEasternDigits('$reviewedCount')
                        : '—',
                    label: 'تقييمات معتمدة',
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    value: parentPercentLabel(attendance),
                    label: 'الحضور',
                    color: const Color(0xFFE8F5E9),
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    value: lastGrade ?? '—',
                    label: 'التقييم',
                    color: AppColors.secondaryBg,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _axisBody(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ملاحظة المعلمة',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notes.isEmpty
                    ? 'لا توجد ملاحظة من المعلم في التقييمات المعتمدة لهذه الفترة.'
                    : notes,
                style: AppTextStyles.bodyLarge.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _lastGradeLabel() {
    final filtered = _filteredRecords();
    if (filtered.isEmpty) return null;
    if (axis == 'سلوك') return filtered.first.behaviorGrade?.label;
    return filtered.first.grade?.label;
  }

  List<RecitationRecordEntity> _filteredRecords() {
    return records.where((record) {
      if (record.isPendingReview) return false;
      if (axis == 'حفظ') return record.type == RecitationType.memorization;
      if (axis == 'مراجعة') return record.type == RecitationType.review;
      if (axis == 'سلوك') return record.behaviorGrade != null;
      return false;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  String _axisBody() {
    if (axis == 'حضور') {
      final r = report;
      if (r == null || r.totalSessions == 0) {
        return 'لا يوجد حضور مسجّل لهذه الفترة.';
      }
      return '${parentEasternDigits('${r.attendedSessions}')} / ${parentEasternDigits('${r.totalSessions}')} جلسة — ${parentPercentLabel(r.attendancePercent)}';
    }

    final filtered = _filteredRecords();
    if (filtered.isEmpty) {
      return 'لا توجد تقييمات معتمدة في محور $axis.';
    }

    if (axis == 'سلوك') {
      final labels = filtered
          .map((r) => r.behaviorGrade?.label)
          .whereType<String>()
          .toList();
      return 'عدد التقييمات: ${parentEasternDigits('${labels.length}')}\nآخر تقييم: ${labels.first}';
    }

    final percent = ParentPerformance.averagePercent(filtered);
    final last = filtered.first.grade?.label ?? '—';
    return [
      'عدد التقييمات المعتمدة: ${parentEasternDigits('${filtered.length}')}',
      if (percent != null) 'متوسط الأداء: ${parentPercentLabel(percent)}',
      'آخر تقييم: $last',
    ].join('\n');
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleLarge.copyWith(
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
