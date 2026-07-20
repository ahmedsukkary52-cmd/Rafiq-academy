import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/progress_report_entity.dart';
import '../bloc/progress_report_bloc.dart';

class StudentProgressReportPage extends StatelessWidget {
  const StudentProgressReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';

    return BlocProvider(
      create: (_) =>
          sl<ProgressReportBloc>()..add(LoadProgressReportEvent(uid)),
      child: const _ProgressReportView(),
    );
  }
}

class _ProgressReportView extends StatelessWidget {
  const _ProgressReportView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<ProgressReportBloc, ProgressReportState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 20,
                    left: 16,
                    right: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'تقرير التقدم',
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'آخر ٣٠ يوماً',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.status == SectionStatus.loading ||
                  state.status == SectionStatus.initial)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (state.report == null)
                SliverFillRemaining(
                  child: Center(
                    child: Text(state.errorMessage ?? 'لا توجد بيانات'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _SummaryRow(report: state.report!),
                      const SizedBox(height: 12),
                      _AttendanceCard(report: state.report!),
                      const SizedBox(height: 12),
                      _WeeklyChartCard(
                        values: state.report!.weeklyVersesPerDay,
                      ),
                      const SizedBox(height: 12),
                      _TeacherNotesCard(notes: state.report!.teacherNotes),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final ProgressReportEntity report;

  const _SummaryRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '${report.memorizationAccuracyPercent.toStringAsFixed(0)}٪',
                  style: AppTextStyles.headlineMedium,
                ),
                const Text('دقة الحفظ', style: AppTextStyles.labelSmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('📖', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '${report.attendedSessions}',
                  style: AppTextStyles.headlineMedium,
                ),
                const Text('حصة محضورة', style: AppTextStyles.labelSmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final ProgressReportEntity report;

  const _AttendanceCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = (report.monthlyAttendancePercent / 100).clamp(0.0, 1.0);
    return AppCard(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text('معدل الحضور الشهري', style: AppTextStyles.titleMedium),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _RingPainter(p),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${report.monthlyAttendancePercent.toStringAsFixed(0)}٪',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Text('معدل الحضور', style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                color: AppColors.primary,
                label: 'حضور: ${report.attendanceDays} يوم',
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: AppColors.border,
                label: 'غياب: ${report.absenceDays} يوم',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;

  _RingPainter(this.percent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.surfaceGrey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * percent,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent;
}

class _WeeklyChartCard extends StatelessWidget {
  final List<double> values;

  const _WeeklyChartCard({required this.values});

  @override
  Widget build(BuildContext context) {
    const labels = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
    final maxY = ((values.isEmpty ? 10.0 : values.reduce(math.max)) + 2)
        .toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'آيات/يوم',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              const Text('الحفظ الأسبوعي', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(labels[i], style: AppTextStyles.labelSmall);
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(values.length, (i) {
                  final high = values[i] >= (maxY * 0.6);
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: 14,
                        borderRadius: BorderRadius.circular(6),
                        color: high
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherNotesCard extends StatelessWidget {
  final String notes;

  const _TeacherNotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('ملاحظات المعلم', style: AppTextStyles.titleMedium),
              SizedBox(width: 8),
              Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              notes,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
