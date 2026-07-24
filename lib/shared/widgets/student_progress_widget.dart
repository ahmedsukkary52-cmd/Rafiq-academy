import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

import '../../../../shared/theme/app_theme.dart';

/// كارت تقدم الحفظ — يعرض فقط بيانات الملف الحقيقية.
///
/// [currentSurahPercent] = نسبة آيات السورة الحالية فقط (مستقلة عن [completedSurahs]).
/// [completedSurahs] = عدد السور المكتملة 100% (عداد منفصل).
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
          _DonutChart(percent: (currentSurahPercent / 100).clamp(0.0, 1.0)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniStat(value: '$completedSurahs', label: 'سور مكتملة'),
              const SizedBox(width: 24),
              _MiniStat(value: '$totalVerses', label: 'آية'),
            ],
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
