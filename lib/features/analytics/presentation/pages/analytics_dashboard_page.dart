import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/analytics_entities.dart';
import '../bloc/analytics_bloc.dart';
import '../bloc/analytics_event.dart';
import '../bloc/analytics_state.dart';

/// Quarantined (H6 / A-H8): teacher analytics route removed from [AppRouter].
/// Page kept for possible future product; not reachable from live nav.
class AnalyticsDashboardPage extends StatefulWidget {
  final String halaqaId;

  const AnalyticsDashboardPage({super.key, required this.halaqaId});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  late final AnalyticsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<AnalyticsBloc>();
    final now = DateTime.now();
    final oneMonth = now.subtract(const Duration(days: 30));
    _bloc.add(
      LoadHalaqaAnalyticsDashboardEvent(
        halaqaId: widget.halaqaId,
        from: oneMonth,
        to: now,
      ),
    );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
          buildWhen: (previous, current) =>
              previous.analytics != current.analytics ||
              previous.analyticsStatus != current.analyticsStatus ||
              previous.atRiskStudents != current.atRiskStudents ||
              previous.atRiskStatus != current.atRiskStatus ||
              previous.topStudents != current.topStudents ||
              previous.topStudentsStatus != current.topStudentsStatus,
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                // ── Header الداكن ───────────────────────────────
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 170,
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  title: const Text('لوحة التحليلات'),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _AnalyticsHeader(analytics: state.analytics),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── توزيع مستويات الأداء ─────────────────
                      if (state.analyticsStatus == SectionStatus.loaded &&
                          state.analytics != null)
                        _PerformanceDistributionCard(
                          analytics: state.analytics!,
                        ),

                      const SizedBox(height: 16),

                      // ── الحضور الأسبوعي ──────────────────────
                      if (state.analyticsStatus == SectionStatus.loaded &&
                          state.analytics != null)
                        _WeeklyAttendanceCard(
                          weeklyData: state.analytics!.weeklyAttendance,
                        ),

                      const SizedBox(height: 16),

                      // ── طلاب يحتاجون متابعة ──────────────────
                      if (state.atRiskStatus == SectionStatus.loaded &&
                          state.atRiskStudents.isNotEmpty)
                        _AtRiskCard(students: state.atRiskStudents),

                      const SizedBox(height: 16),

                      // ── المتفوقون ─────────────────────────────
                      if (state.topStudentsStatus == SectionStatus.loaded)
                        _TopStudentsCard(students: state.topStudents),

                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AnalyticsHeader
// ══════════════════════════════════════════════════════════════════════════════

class _AnalyticsHeader extends StatelessWidget {
  final HalaqaAnalyticsEntity? analytics;

  const _AnalyticsHeader({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingM,
          48,
          AppSizes.paddingM,
          AppSizes.paddingM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _HeaderStat(
              value: '${analytics?.averagePerformancePercent.toInt() ?? 0}%',
              label: 'متوسط الأداء',
            ),
            _HeaderStat(
              value: '${analytics?.attendancePercent.toInt() ?? 0}%',
              label: 'نسبة الحضور',
            ),
            _HeaderStat(
              value: '${analytics?.totalStudents ?? 0}',
              label: 'إجمالي الطلاب',
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PerformanceDistributionCard - Donut Chart
// ══════════════════════════════════════════════════════════════════════════════

class _PerformanceDistributionCard extends StatelessWidget {
  final HalaqaAnalyticsEntity analytics;

  const _PerformanceDistributionCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final dist = analytics.performanceDistribution;
    final total = dist.values.fold<int>(0, (a, b) => a + b);

    final colors = {
      'ممتاز': AppColors.gradeExcellent,
      'جيد جداً': AppColors.gradeVeryGood,
      'جيد': AppColors.gradeGood,
      'يحتاج تحسين': AppColors.gradeNeedsWork,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('توزيع مستويات الأداء', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),

          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'لا توجد بيانات كافية بعد',
                style: AppTextStyles.bodyMedium,
              ),
            )
          else ...[
            SizedBox(
              height: 140,
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
                    '$total\nطالب',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: dist.entries.map((e) {
                final percent = total > 0 ? (e.value / total * 100).toInt() : 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$percent% ${e.key}', style: AppTextStyles.labelSmall),
                    const SizedBox(width: 4),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[e.key] ?? AppColors.textHint,
                        shape: BoxShape.circle,
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

    double startAngle = -math.pi / 2;

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

// ══════════════════════════════════════════════════════════════════════════════
// _WeeklyAttendanceCard - Bar Chart
// ══════════════════════════════════════════════════════════════════════════════

class _WeeklyAttendanceCard extends StatelessWidget {
  final Map<String, double> weeklyData;

  const _WeeklyAttendanceCard({required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    const dayOrder = ['سب', 'جم', 'خم', 'أر', 'ثل', 'إث', 'أح'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('الحضور الأسبوعي', style: AppTextStyles.titleLarge),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dayOrder.map((day) {
                final value = weeklyData[day] ?? 0;
                final barHeight = (value / 100) * 90;
                final isHigh = value >= 70;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 20,
                      height: value <= 0 ? 0 : barHeight.clamp(4, 90),
                      decoration: BoxDecoration(
                        color: isHigh ? AppColors.primary : AppColors.secondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(day, style: AppTextStyles.labelSmall),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AtRiskCard
// ══════════════════════════════════════════════════════════════════════════════

class _AtRiskCard extends StatelessWidget {
  final List<AtRiskStudentEntity> students;

  const _AtRiskCard({required this.students});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'طلاب يحتاجون متابعة عاجلة',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...students.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(s.studentName, style: AppTextStyles.titleMedium),
                      Text(
                        s.detail,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  UserAvatar(name: s.studentName, size: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TopStudentsCard
// ══════════════════════════════════════════════════════════════════════════════

class _TopStudentsCard extends StatelessWidget {
  final List<TopStudentEntity> students;

  const _TopStudentsCard({required this.students});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('المتفوقون', style: AppTextStyles.titleLarge),
              SizedBox(width: 6),
              Icon(Icons.star_rounded, color: AppColors.secondary, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          if (students.isEmpty)
            const Text(
              'لا توجد بيانات كافية بعد',
              style: AppTextStyles.bodyMedium,
            )
          else
            ...students.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '${s.performancePercent.toInt()}%',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(s.studentName, style: AppTextStyles.titleMedium),
                    const SizedBox(width: 10),
                    UserAvatar(name: s.studentName, size: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
