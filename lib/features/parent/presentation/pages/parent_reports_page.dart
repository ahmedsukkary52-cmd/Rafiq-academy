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
    setState(() => _recordsLoading = true);
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
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              if (children.length > 1)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final id in children)
                      ChoiceChip(
                        label: Text(state.childDisplayName(id)),
                        selected: state.selectedChildId == id,
                        onSelected: (_) => context.read<ParentBloc>().add(
                          SelectChildEvent(id),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _axes.length; i++)
                    ChoiceChip(
                      label: Text(_axes[i]),
                      selected: _axisIndex == i,
                      onSelected: (_) => setState(() => _axisIndex = i),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.reportStatus == SectionStatus.initial ||
                  state.reportStatus == SectionStatus.loading ||
                  _recordsLoading)
                const SizedBox(height: 220, child: ParentListCardsSkeleton())
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

  const _ReportBody({
    required this.axis,
    required this.report,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final notes = report?.teacherNotes.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'محور: $axis',
                style: AppTextStyles.titleLarge,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              Text(
                _axisBody(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ملاحظة المعلمة', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Text(
                notes.isEmpty
                    ? 'لا توجد ملاحظة من المعلم في التقييمات المعتمدة لهذه الفترة.'
                    : notes,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _axisBody() {
    if (axis == 'حضور') {
      final r = report;
      if (r == null || r.totalSessions == 0) {
        return 'لا يوجد حضور مسجّل لهذه الفترة.';
      }
      return '${r.attendedSessions} / ${r.totalSessions} — ${r.attendancePercent.round()}%';
    }

    final filtered = records.where((record) {
      if (axis == 'حفظ') return record.type == RecitationType.memorization;
      if (axis == 'مراجعة') return record.type == RecitationType.review;
      return record.behaviorGrade != null;
    }).toList();

    if (filtered.isEmpty) {
      return 'لا توجد تقييمات معتمدة في محور $axis.';
    }

    if (axis == 'سلوك') {
      final labels = filtered
          .map((r) => r.behaviorGrade?.label)
          .whereType<String>()
          .toList();
      return 'عدد التقييمات: ${labels.length}\nآخر تقييم: ${labels.first}';
    }

    final percent = ParentPerformance.averagePercent(filtered);
    final last = filtered.first.grade?.label ?? '—';
    return [
      'عدد التقييمات المعتمدة: ${filtered.length}',
      if (percent != null) 'متوسط الأداء: ${percent.round()}%',
      'آخر تقييم: $last',
    ].join('\n');
  }
}
