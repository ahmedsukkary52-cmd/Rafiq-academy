import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

import '../../../../shared/theme/app_theme.dart';

/// كارت تقدم الحفظ.
///
/// [currentSurahPercent] = نسبة آيات السورة الحالية فقط (مستقلة عن [completedSurahs]).
/// [completedSurahs] = عدد السور المكتملة 100% (عداد منفصل).
/// هدف الأسبوع مؤجل لخطة الحفظ — يُعرض «قريباً» بدون أرقام مفبركة.
class StudentProgressWidget extends StatelessWidget {
  final double currentSurahPercent;
  final String currentSurahName;
  final int totalVerses;
  final int completedSurahs;
  final VoidCallback? onTap;

  const StudentProgressWidget({
    super.key,
    required this.currentSurahPercent,
    this.currentSurahName = '',
    required this.totalVerses,
    required this.completedSurahs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

          // ── هدف الأسبوع — قريباً (خطة الحفظ) ───────────────────
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('هدف الأسبوع', style: AppTextStyles.labelMedium),
                SizedBox(height: 12),
                Icon(
                  Icons.flag_outlined,
                  color: AppColors.textHint,
                  size: 28,
                ),
                SizedBox(height: 8),
                Text(
                  'قريباً',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'بعد تعيين خطة الحفظ',
                  style: AppTextStyles.labelSmall,
                  textAlign: TextAlign.center,
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
        Text(value, style: AppTextStyles.titleMedium),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}
