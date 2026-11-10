import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// كارت تقدم الحفظ — Figma: عنوان + تفاصيل + دونات + صف إحصاءات.
class StudentProgressWidget extends StatelessWidget {
  final double progressPercent;
  final String planName;
  final int totalVerses;
  final int completedSurahs;
  final int totalStars;
  final VoidCallback? onTap;
  final VoidCallback? onDetailsTap;

  /// False while no backend computes memorization progress: the card then
  /// says so instead of showing zeros as if they were measured.
  final bool progressAvailable;

  const StudentProgressWidget({
    super.key,
    required this.progressPercent,
    this.planName = '',
    required this.totalVerses,
    required this.completedSurahs,
    this.totalStars = 0,
    this.onTap,
    this.onDetailsTap,
    this.progressAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final pct = progressPercent.clamp(0, 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onDetailsTap ?? onTap,
              child: Text(
                'التفاصيل',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            const Icon(Icons.star_rounded, color: AppColors.secondary, size: 18),
            const SizedBox(width: 4),
            Text(
              'تقدم الحفظ',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: progressAvailable
                  ? _measured(pct)
                  : _notYetMeasured(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notYetMeasured() {
    return Column(
      children: [
        Text(
          'لم يُفعَّل احتساب تقدم الحفظ بعد؛ سيظهر هنا عند اعتماده من تقييمات المعلم.',
          key: const Key('student-progress-unavailable'),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 14),
        _MiniStat(value: '$totalStars', label: 'نجمة'),
      ],
    );
  }

  Widget _measured(int pct) {
    return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              planName.isNotEmpty ? planName : 'تقدم الحفظ',
                              textAlign: TextAlign.right,
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$totalVerses آية محفوظة',
                              textAlign: TextAlign.right,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: CustomPaint(
                          painter: _DonutPainter((pct / 100).clamp(0.0, 1.0)),
                          child: Center(
                            child: Text(
                              '$pct%\nمكتمل',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryDark,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          value: '$completedSurahs',
                          label: 'سور مكتملة',
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          value: '$totalStars',
                          label: 'نجمة',
                        ),
                      ),
                    ],
                  ),
                ],
    );
  }
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
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textHint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;

  _DonutPainter(this.percent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const strokeW = 9.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.primaryLight
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
