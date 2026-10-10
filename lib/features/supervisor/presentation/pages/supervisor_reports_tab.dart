import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../analytics/domain/entities/analytics_entities.dart';
import '../../../analytics/domain/usecases/analytics_usecases.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/entities/supervisor_report_entity.dart';
import '../../domain/repositories/parent_repository.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';
import '../supervisor_home_nav.dart';
import '../widgets/supervisor_loading_skeletons.dart';

enum _ReportPeriod { weekly, monthly, term }

class _AggregatedAnalytics {
  final double attendancePercent;
  final double averagePerformancePercent;
  final int totalStudents;
  final Map<String, int> performanceDistribution;
  final Map<String, double> weeklyAttendance;

  const _AggregatedAnalytics({
    required this.attendancePercent,
    required this.averagePerformancePercent,
    required this.totalStudents,
    required this.performanceDistribution,
    required this.weeklyAttendance,
  });

  static const empty = _AggregatedAnalytics(
    attendancePercent: 0,
    averagePerformancePercent: 0,
    totalStudents: 0,
    performanceDistribution: {},
    weeklyAttendance: {},
  );
}

class SupervisorReportsTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const SupervisorReportsTab({super.key, this.onSwitchTab});

  @override
  State<SupervisorReportsTab> createState() => _SupervisorReportsTabState();
}

class _SupervisorReportsTabState extends State<SupervisorReportsTab> {
  _ReportPeriod _period = _ReportPeriod.monthly;
  bool _loading = false;
  String? _error;
  _AggregatedAnalytics _analytics = _AggregatedAnalytics.empty;
  int _loadGen = 0;
  String _halaqaKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(context.read<SupervisorBloc>().state);
    });
  }

  Duration _periodDuration(_ReportPeriod p) => switch (p) {
    _ReportPeriod.weekly => const Duration(days: 7),
    _ReportPeriod.monthly => const Duration(days: 30),
    _ReportPeriod.term => const Duration(days: 90),
  };

  void _sync(SupervisorState state) {
    if (state.halaqatStatus == SectionStatus.initial ||
        state.halaqatStatus == SectionStatus.loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
      return;
    }
    if (state.halaqatStatus == SectionStatus.error) {
      setState(() {
        _loading = false;
        _error = state.halaqatError ?? 'تعذر تحميل الحلقات';
        _analytics = _AggregatedAnalytics.empty;
      });
      return;
    }
    final key = '${state.halaqat.map((h) => h.id).join('|')}|$_period';
    if (key == _halaqaKey && !_loading && _error == null) return;
    _halaqaKey = key;
    _load(state.halaqat);
  }

  Future<void> _load(List<HalaqaEntity> halaqat) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    if (halaqat.isEmpty) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _analytics = _AggregatedAnalytics.empty;
        _loading = false;
      });
      return;
    }

    final now = DateTime.now();
    final from = now.subtract(_periodDuration(_period));
    final getStudents = sl<GetHalaqaStudentsUseCase>();
    final getAnalytics = sl<GetHalaqaAnalyticsUseCase>();

    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    final analyticsList = <HalaqaAnalyticsEntity>[];

    await Future.wait(
      halaqat.map((h) async {
        final summaries = await getStudents(HalaqaStudentsParams(h.id));
        summaries.fold((_) {}, (list) => byHalaqa[h.id] = list);

        final analytics = await getAnalytics(
          HalaqaAnalyticsParams(halaqaId: h.id, from: from, to: now),
        );
        analytics.fold((_) {}, analyticsList.add);
      }),
    );

    if (!mounted || gen != _loadGen) return;

    final roster = SupervisorRoster.mergeSummaries(
      halaqat: halaqat,
      byHalaqaId: byHalaqa,
    );

    final mergedDist = <String, int>{};
    final weeklyBuckets = <String, List<double>>{};
    var attendanceWeighted = 0.0;
    var performanceWeighted = 0.0;
    var weightSum = 0;

    for (final a in analyticsList) {
      final w = a.totalStudents > 0 ? a.totalStudents : 1;
      weightSum += w;
      attendanceWeighted += a.attendancePercent * w;
      performanceWeighted += a.averagePerformancePercent * w;
      for (final e in a.performanceDistribution.entries) {
        mergedDist[e.key] = (mergedDist[e.key] ?? 0) + e.value;
      }
      for (final e in a.weeklyAttendance.entries) {
        weeklyBuckets.putIfAbsent(e.key, () => []).add(e.value);
      }
    }

    final weeklyMerged = <String, double>{
      for (final e in weeklyBuckets.entries)
        e.key: e.value.isEmpty
            ? 0
            : e.value.reduce((a, b) => a + b) / e.value.length,
    };

    setState(() {
      _analytics = _AggregatedAnalytics(
        attendancePercent: weightSum > 0 ? attendanceWeighted / weightSum : 0,
        averagePerformancePercent: weightSum > 0
            ? performanceWeighted / weightSum
            : 0,
        totalStudents: roster.length,
        performanceDistribution: mergedDist,
        weeklyAttendance: weeklyMerged,
      );
      _loading = false;
      _error = null;
    });
  }

  Future<void> _showComposeReportSheet(BuildContext context) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    final state = context.read<SupervisorBloc>().state;
    final halaqat = state.halaqat;
    final contentCtrl = TextEditingController();
    var type = 'periodic';
    String? halaqaId;
    String? teacherId;

    const types = <String, String>{
      'periodic': 'تقرير دوري',
      'incident': 'بلاغ',
      'follow_up': 'متابعة',
    };

    final teacherIds = <String>{
      for (final h in halaqat)
        if (h.teacherId.trim().isNotEmpty) h.teacherId.trim(),
    }.toList()..sort();

    var teacherNames = <String, String>{};
    if (teacherIds.isNotEmpty) {
      final namesResult = await sl<SupervisorRepository>().getUserDisplayNames(
        teacherIds,
      );
      namesResult.fold((_) {}, (map) => teacherNames = map);
    }
    if (!context.mounted) {
      contentCtrl.dispose();
      return;
    }

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'كتابة تقرير',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in types.entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: type == entry.key,
                            onSelected: (_) =>
                                setSheetState(() => type = entry.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: halaqaId,
                      decoration: const InputDecoration(
                        labelText: 'الحلقة (اختياري)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— بدون حلقة —'),
                        ),
                        for (final h in halaqat)
                          DropdownMenuItem<String?>(
                            value: h.id,
                            child: Text(
                              h.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setSheetState(() => halaqaId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: teacherId != null && teacherIds.contains(teacherId)
                          ? teacherId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'المعلم (اختياري)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— بدون معلم —'),
                        ),
                        for (final id in teacherIds)
                          DropdownMenuItem<String?>(
                            value: id,
                            child: Text(
                              teacherNames[id] ?? id,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setSheetState(() => teacherId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 5,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'المحتوى',
                        alignLabelWithHint: true,
                        hintText: 'اكتب محتوى التقرير...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        if (contentCtrl.text.trim().isEmpty) {
                          AppSnackBar.showInfo(
                            sheetContext,
                            'أدخل محتوى التقرير',
                          );
                          return;
                        }
                        Navigator.of(sheetContext).pop(true);
                      },
                      child: const Text('إرسال'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (submitted != true || !context.mounted) {
      contentCtrl.dispose();
      return;
    }

    final teacherRaw = (teacherId ?? '').trim();
    context.read<SupervisorBloc>().add(
      SubmitSupervisorReportEvent(
        SupervisorReportEntity(
          id: '',
          supervisorId: auth.user.uid,
          halaqaId: halaqaId,
          teacherId: teacherRaw.isEmpty ? null : teacherRaw,
          type: type,
          content: contentCtrl.text.trim(),
          date: DateTime.now(),
        ),
      ),
    );
    contentCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) =>
          p.halaqatStatus != c.halaqatStatus || p.halaqat != c.halaqat,
      listener: (context, state) => _sync(state),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _halaqaKey = '';
              await _load(context.read<SupervisorBloc>().state.halaqat);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _PeriodTabs(
                        period: _period,
                        onChanged: (p) {
                          setState(() => _period = p);
                          _halaqaKey = '';
                          _load(context.read<SupervisorBloc>().state.halaqat);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const SizedBox(
                          height: 280,
                          child: SupervisorListCardsSkeleton(itemCount: 3),
                        )
                      else if (_error != null)
                        AppErrorWidget(
                          message: _error!,
                          onRetry: () {
                            _halaqaKey = '';
                            _sync(context.read<SupervisorBloc>().state);
                          },
                        )
                      else ...[
                        _PerformanceCard(analytics: _analytics),
                        const SizedBox(height: 14),
                        _WeeklyAttendanceCard(
                          weeklyData: _analytics.weeklyAttendance,
                          rate: _analytics.attendancePercent,
                        ),
                        const SizedBox(height: 14),
                        _ReportsGrid(
                          onTopStudents: () => widget.onSwitchTab?.call(
                            SupervisorHomeNav.studentsIndex,
                          ),
                          onAtRisk: () =>
                              SupervisorDestinations.followUp(context),
                          onAttendance: () =>
                              SupervisorDestinations.attendance(context),
                          onTeachers: () =>
                              SupervisorDestinations.teachers(context),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final a = _analytics;

    return Container(
      color: AppColors.dark,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    'التقارير والتحليلات',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'كتابة تقرير',
                  onPressed: () => _showComposeReportSheet(context),
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _loading
                ? Text(
                    'جاري…',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _HeaderStatPill(
                          value: '%${a.attendancePercent.toInt()}',
                          label: 'معدل الحضور',
                          valueColor: AppColors.gradeVeryGood,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderStatPill(
                          value: '%${a.averagePerformancePercent.toInt()}',
                          label: 'متوسط الأداء',
                          valueColor: AppColors.gradeGood,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderStatPill(
                          value: '${a.totalStudents}',
                          label: 'طالب نشط',
                          valueColor: AppColors.gradeExcellent,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _HeaderStatPill({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  final _ReportPeriod period;
  final ValueChanged<_ReportPeriod> onChanged;

  const _PeriodTabs({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <(_ReportPeriod, String)>[
      (_ReportPeriod.monthly, 'شهري'),
      (_ReportPeriod.weekly, 'أسبوعي'),
      (_ReportPeriod.term, 'فصلي'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(items[i].$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: period == items[i].$1
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: period == items[i].$1
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final _AggregatedAnalytics analytics;

  const _PerformanceCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final dist = analytics.performanceDistribution;
    final total = dist.values.fold<int>(0, (a, b) => a + b);
    const colors = {
      'ممتاز': AppColors.gradeExcellent,
      'جيد جداً': AppColors.gradeVeryGood,
      'جيد': AppColors.gradeGood,
      'يحتاج تحسين': AppColors.gradeNeedsWork,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'توزيع مستويات الأداء',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'لا توجد بيانات كافية بعد',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _DistributionDonutPainter(
                      dist: dist,
                      colors: colors,
                      total: total,
                    ),
                  ),
                  Text(
                    '$total طالب',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: dist.entries.map((e) {
                final pct = total > 0 ? (e.value / total * 100).toInt() : 0;
                final color = colors[e.key] ?? AppColors.textHint;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '%$pct ${e.key}',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DistributionDonutPainter extends CustomPainter {
  final Map<String, int> dist;
  final Map<String, Color> colors;
  final int total;

  _DistributionDonutPainter({
    required this.dist,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeW = 22.0;
    var startAngle = -math.pi / 2;

    for (final entry in dist.entries) {
      if (entry.value == 0) continue;
      final sweep = (entry.value / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = colors[entry.key] ?? AppColors.textHint
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DistributionDonutPainter old) => true;
}

class _WeeklyAttendanceCard extends StatelessWidget {
  final Map<String, double> weeklyData;
  final double rate;

  const _WeeklyAttendanceCard({required this.weeklyData, required this.rate});

  @override
  Widget build(BuildContext context) {
    const dayOrder = ['سب', 'أح', 'إث', 'ثل', 'أر', 'خم', 'جم'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '%${rate.toInt()} معدل',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'الحضور الأسبوعي',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dayOrder.map((day) {
                final value = weeklyData[day] ?? 0;
                final barHeight = (value / 100) * 96;
                final color = value >= 70
                    ? AppColors.primaryDark
                    : value >= 40
                    ? AppColors.gradeGood
                    : AppColors.primary.withValues(alpha: 0.35);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: double.infinity,
                          height: value <= 0 ? 4 : barHeight.clamp(8, 96),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsGrid extends StatelessWidget {
  final VoidCallback? onTopStudents;
  final VoidCallback onAtRisk;
  final VoidCallback onAttendance;
  final VoidCallback onTeachers;

  const _ReportsGrid({
    required this.onTopStudents,
    required this.onAtRisk,
    required this.onAttendance,
    required this.onTeachers,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.star_rounded,
        AppColors.gradeExcellent,
        'المتفوقون',
        'عدد الطلاب',
        onTopStudents,
      ),
      (
        Icons.warning_amber_rounded,
        AppColors.error,
        'في خطر',
        'عدد الطلاب',
        onAtRisk,
      ),
      (
        Icons.event_available_rounded,
        AppColors.primary,
        'الحضور',
        'تقارير الحضور',
        onAttendance,
      ),
      (
        Icons.search_rounded,
        AppColors.gradeGood,
        'المعلمون',
        'أداء المعلمين',
        onTeachers,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: item.$5,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.$2.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, color: item.$2, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    item.$3,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.$4,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
