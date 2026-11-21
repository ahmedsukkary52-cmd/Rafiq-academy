import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/widgets/student_page_skeletons.dart';
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
      child: _ProgressReportView(studentId: uid),
    );
  }
}

class _ProgressReportView extends StatelessWidget {
  final String studentId;

  const _ProgressReportView({required this.studentId});

  void _retry(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final id = auth is AuthAuthenticated ? auth.user.uid : studentId;
    context.read<ProgressReportBloc>().add(LoadProgressReportEvent(id));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<ProgressReportBloc, ProgressReportState>(
          buildWhen: (previous, current) =>
              previous.status != current.status ||
              previous.report != current.report ||
              previous.errorMessage != current.errorMessage,
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _ProgressHero()),
                if (state.status == SectionStatus.loading ||
                    state.status == SectionStatus.initial)
                  const SliverFillRemaining(child: StudentHomeBodySkeleton())
                else if (state.status == SectionStatus.error)
                  SliverFillRemaining(
                    child: AppErrorWidget(
                      message: state.errorMessage ?? 'تعذر تحميل تقرير التقدم',
                      onRetry: () => _retry(context),
                    ),
                  )
                else if (state.report == null)
                  SliverFillRemaining(
                    child: AppErrorWidget(
                      message: 'لا توجد بيانات',
                      onRetry: () => _retry(context),
                    ),
                  )
                else
                  _buildLoadedSliver(context, state.report!),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadedSliver(BuildContext context, ProgressReportEntity report) {
    final hasAttendanceActivity =
        report.attendanceDays > 0 || report.absenceDays > 0;
    final hasWeeklyActivity = report.weeklyVersesPerDay.any((v) => v > 0);
    final notes = report.teacherNotes.trim();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _SummaryRow(report: report),
          const SizedBox(height: 16),
          if (!hasAttendanceActivity)
            AppCard(
              child: Text(
                'لا توجد سجلات حضور في آخر ٣٠ يوماً',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            )
          else
            _AttendanceCard(report: report),
          const SizedBox(height: 16),
          if (!hasWeeklyActivity)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'الحفظ الأسبوعي',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد تسميعات مسجّلة هذا الأسبوع',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            )
          else
            _WeeklyChartCard(values: report.weeklyVersesPerDay),
          const SizedBox(height: 16),
          _TeacherNotesCard(
            notes: notes.isEmpty ? 'لا توجد ملاحظات من المعلم حالياً' : notes,
            isPlaceholder: notes.isEmpty,
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        26,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const AppBackButton(
                color: AppColors.onPrimary,
                circular: true,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.onPrimaryOverlay,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.onPrimaryMuted),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'آخر ٣٠ يوماً',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'تقرير التقدم',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'شوف إنجازاتك و حضورك بكل فرح! 🎉',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoyCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _JoyCardShell({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primaryGradientMid.withValues(alpha: 0.35),
            AppColors.primaryGradientEnd.withValues(alpha: 0.12),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGradientStart.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.5),
        ),
        child: child,
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
        // D11: this value is memorization progress, never «دقة الحفظ».
        if (AppCapabilities.memorizationProgressAvailable) ...[
          Expanded(
            child: _SummaryStatCard(
              emoji: '⭐',
              value: '${report.memorizationAccuracyPercent.toStringAsFixed(0)}٪',
              label: 'نسبة الحفظ',
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _SummaryStatCard(
            emoji: '📖',
            value: '${report.attendedSessions}',
            label: 'حصة محضورة',
          ),
        ),
      ],
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _SummaryStatCard({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return _JoyCardShell(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryGradientStart,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final ProgressReportEntity report;

  const _AttendanceCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = (report.monthlyAttendancePercent / 100).clamp(0.0, 1.0);
    return _JoyCardShell(
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'معدل الحضور الشهري',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 148,
            height: 148,
            child: CustomPaint(
              painter: _RingPainter(p),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${report.monthlyAttendancePercent.toStringAsFixed(0)}٪',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [
                              AppColors.primaryGradientStart,
                              AppColors.primaryGradientMid,
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 80, 30)),
                      ),
                    ),
                    Text(
                      'معدل الحضور',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                gradient: AppColors.primaryGradient,
                label: 'حضور: ${report.attendanceDays} يوم',
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: AppColors.border,
                label: 'غياب: ${report.absenceDays} يوم',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'الحضور يشمل التأخر',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final String label;

  const _LegendDot({
    this.color,
    this.gradient,
    required this.label,
  }) : assert(color != null || gradient != null);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
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
    final progress = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        colors: [
          AppColors.primaryGradientStart,
          AppColors.primaryGradientMid,
          AppColors.primaryGradientEnd,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * percent,
      false,
      progress,
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

    return _JoyCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'الحفظ الأسبوعي',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGradientMid.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'تسميعات/يوم',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryGradientStart,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 168,
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
                        return Text(
                          labels[i],
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        );
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
                        width: 16,
                        borderRadius: BorderRadius.circular(8),
                        gradient: high
                            ? const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.primaryGradientStart,
                                  AppColors.primaryGradientMid,
                                  AppColors.primaryGradientEnd,
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.primaryGradientMid.withValues(
                                    alpha: 0.2,
                                  ),
                                  AppColors.primaryGradientEnd.withValues(
                                    alpha: 0.35,
                                  ),
                                ],
                              ),
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
  final bool isPlaceholder;

  const _TeacherNotesCard({required this.notes, this.isPlaceholder = false});

  @override
  Widget build(BuildContext context) {
    return _JoyCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ملاحظات المعلم',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.primaryLight.withValues(alpha: 0.65),
                  AppColors.surfaceGrey,
                ],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              border: Border.all(
                color: AppColors.primaryGradientMid.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              notes,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.55,
                color: isPlaceholder
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
