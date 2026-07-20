import 'package:flutter/material.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';
import 'dart:math' as math;
import '../../../../shared/theme/app_theme.dart';

/// كارت تقدم الحفظ.
///
/// [currentSurahPercent] = نسبة آيات السورة الحالية فقط (مستقلة عن [completedSurahs]).
/// [completedSurahs] = عدد السور المكتملة 100% (عداد منفصل).
class StudentProgressWidget extends StatelessWidget {
  final double currentSurahPercent;
  final String currentSurahName;
  final int totalVerses;
  final int completedSurahs;
  final int weeklyTarget;
  final int weeklyCompleted;
  final VoidCallback? onTap;

  const StudentProgressWidget({
    super.key,
    required this.currentSurahPercent,
    this.currentSurahName = '',
    required this.totalVerses,
    required this.completedSurahs,
    required this.weeklyTarget,
    required this.weeklyCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weeklyPercent = weeklyTarget > 0
        ? (weeklyCompleted / weeklyTarget).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (weeklyTarget - weeklyCompleted).clamp(0, weeklyTarget);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          // ── تقدم السورة الحالية (Donut) ──────────────────────────
          Expanded(
            child: Column(
              children: [
                Text(
                  currentSurahName.isNotEmpty ? currentSurahName : 'تقدم الحفظ',
                  style: AppTextStyles.labelMedium,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _DonutChart(
                  percent: (currentSurahPercent / 100).clamp(0.0, 1.0),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniStat(value: '$completedSurahs', label: 'سور مكتملة'),
                    const SizedBox(width: 16),
                    _MiniStat(value: '$totalVerses', label: 'آية'),
                  ],
                ),
              ],
            ),
          ),

          Container(width: 1, height: 100, color: AppColors.border),

          // ── هدف الأسبوع ────────────────────────────────────────
          // TODO: هدف الأسبوع ينتظر نظام خطة الحفظ — القيم حالياً placeholder.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('هدف الأسبوع', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(' / $weeklyTarget', style: AppTextStyles.bodyMedium),
                    Text(
                      '$weeklyCompleted',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  child: LinearProgressIndicator(
                    value: weeklyPercent,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceGrey,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remaining > 0
                      ? 'آية، يتبقى $remaining آيات'
                      : 'أكملت هدف الأسبوع 🎉',
                  style: AppTextStyles.labelSmall,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(weeklyPercent * 100).toInt()}%',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final double percent; // 0.0 → 1.0

  const _DonutChart({required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _DonutPainter(percent),
        child: Center(
          child: Text(
            '${(percent * 100).toInt()}%',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;

  _DonutPainter(this.percent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeW = 10.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.surfaceGrey
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * percent,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.percent != percent;
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
        ),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}
