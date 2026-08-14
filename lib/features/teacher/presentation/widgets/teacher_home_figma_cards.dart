import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Figma 1:432 stats + session cards (shared by Home and visual capture tests).
/// Presentation only — no BLoC / UseCase logic here.

String teacherHomeEasternDigits(String input) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final code in input.runes) {
    final ch = String.fromCharCode(code);
    final i = western.indexOf(ch);
    buffer.write(i >= 0 ? eastern[i] : ch);
  }
  return buffer.toString();
}

String teacherHomeSessionTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'صباحاً' : 'مساءً';
  return teacherHomeEasternDigits('$hour12:$minute $period');
}

class TeacherHomeStatsGrid extends StatelessWidget {
  final int studentsCount;
  final int sessionsToday;
  final int pendingTasks;
  final int newMessages;
  final VoidCallback? onSessionsTap;
  final VoidCallback? onStudentsTap;
  final VoidCallback? onPendingTap;
  final VoidCallback? onMessagesTap;

  const TeacherHomeStatsGrid({
    super.key,
    required this.studentsCount,
    required this.sessionsToday,
    required this.pendingTasks,
    required this.newMessages,
    this.onSessionsTap,
    this.onStudentsTap,
    this.onPendingTap,
    this.onMessagesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TeacherHomeStatTile(
                  value: sessionsToday,
                  label: 'حصص اليوم',
                  icon: Icons.calendar_today_outlined,
                  iconBg: AppColors.primaryLight,
                  iconColor: AppColors.primaryDark,
                  onTap: onSessionsTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TeacherHomeStatTile(
                  value: studentsCount,
                  label: 'إجمالي الطلاب',
                  icon: Icons.person_outline_rounded,
                  iconBg: AppColors.successBg,
                  iconColor: AppColors.success,
                  onTap: onStudentsTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TeacherHomeStatTile(
                  value: pendingTasks,
                  label: 'مهام معلقة',
                  icon: Icons.checklist_rtl_rounded,
                  iconBg: AppColors.secondaryBg,
                  iconColor: AppColors.secondary,
                  onTap: onPendingTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TeacherHomeStatTile(
                  value: newMessages,
                  label: 'رسائل جديدة',
                  icon: Icons.chat_bubble_outline_rounded,
                  iconBg: AppColors.messagesBg,
                  iconColor: AppColors.awardWeekly,
                  onTap: onMessagesTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TeacherHomeStatTile extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback? onTap;

  const TeacherHomeStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        elevation: 0,
        shadowColor: AppColors.softShadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    teacherHomeEasternDigits('$value'),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.displayLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      height: 1.05,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    label,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.25,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma Today's Session card — filled and empty share one layout skeleton.
class TeacherHomeSessionCard extends StatelessWidget {
  /// e.g. `٧:٠٠ مساءً`. Null → empty meta time.
  final String? timeText;

  final String title;

  /// e.g. `١٤ طالباً`. Null → empty details line.
  final String? studentsText;

  /// Null → disabled CTA (empty state keeps the designed button footprint).
  final VoidCallback? onStart;

  /// CTA label — `ابدأ الجلسة` normally; `إعادة المحاولة` on error.
  final String ctaLabel;

  const TeacherHomeSessionCard({
    super.key,
    required this.title,
    this.timeText,
    this.studentsText,
    this.onStart,
    this.ctaLabel = 'ابدأ الجلسة',
  });

  factory TeacherHomeSessionCard.filled({
    Key? key,
    required String halaqaName,
    required DateTime startAt,
    required int studentCount,
    required VoidCallback onStart,
  }) {
    return TeacherHomeSessionCard(
      key: key,
      timeText: teacherHomeSessionTime(startAt),
      title: halaqaName,
      studentsText: '${teacherHomeEasternDigits('$studentCount')} طالباً',
      onStart: onStart,
    );
  }

  factory TeacherHomeSessionCard.empty({
    Key? key,
    String message = 'لا توجد حصص مجدوَلة اليوم',
  }) {
    return TeacherHomeSessionCard(
      key: key,
      timeText: null,
      title: message,
      studentsText: null,
      onStart: null,
    );
  }

  factory TeacherHomeSessionCard.error({
    Key? key,
    required String message,
    required VoidCallback onRetry,
  }) {
    return TeacherHomeSessionCard(
      key: key,
      timeText: null,
      title: message,
      studentsText: null,
      onStart: onRetry,
      ctaLabel: 'إعادة المحاولة',
    );
  }

  @override
  Widget build(BuildContext context) {
    final metaMuted = timeText == null;
    final detailsMuted = studentsText == null;
    final ctaEnabled = onStart != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Meta area ──────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: AppColors.onPrimaryMuted.withValues(
                    alpha: metaMuted ? 0.55 : 1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  metaMuted
                      ? 'اليوم — ${teacherHomeEasternDigits('0:00')} مساءً'
                      : 'اليوم — $timeText',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryMuted.withValues(
                      alpha: metaMuted ? 0.55 : 1,
                    ),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Title ──────────────────────────────────────────────────
            Text(
              title,
              textAlign: TextAlign.right,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.onPrimary.withValues(
                  alpha: metaMuted ? 0.9 : 1,
                ),
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            // ── Details area ───────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: AppColors.onPrimaryMuted.withValues(
                    alpha: detailsMuted ? 0.55 : 1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  detailsMuted ? '٠ طالباً' : studentsText!,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimaryMuted.withValues(
                      alpha: detailsMuted ? 0.55 : 1,
                    ),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── CTA area (always present — enabled or muted) ───────────
            Align(
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: ctaEnabled ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !ctaEnabled,
                  child: _StartSessionButton(
                    label: ctaLabel,
                    onTap: onStart ?? () {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartSessionButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _StartSessionButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  label == 'إعادة المحاولة'
                      ? Icons.refresh_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Admin announcement (Figma) ────────────────────────────────────────────────

class TeacherHomeAnnouncementBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const TeacherHomeAnnouncementBanner({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return const SizedBox.shrink();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: AppColors.announcementGradient,
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إعلان إداري',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recent activities ─────────────────────────────────────────────────────────

class TeacherHomeActivityVm {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? timeLabel;
  final VoidCallback? onTap;

  const TeacherHomeActivityVm({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.timeLabel,
    this.onTap,
  });
}

class TeacherHomeRecentActivities extends StatelessWidget {
  final List<TeacherHomeActivityVm> items;
  final VoidCallback? onSeeAll;

  const TeacherHomeRecentActivities({
    super.key,
    required this.items,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'النشاطات الأخيرة',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'الكل',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    child: Text(
                      'لا توجد نشاطات حديثة',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        _ActivityTile(item: items[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final TeacherHomeActivityVm item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (item.timeLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.timeLabel!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home Analytics entry — white elevated summary (Phase: Home Analytics card).
///
/// Presentation only. Parent resolves [halaqaId], fetches via
/// [GetHalaqaAnalyticsUseCase], and passes honest loading / error / metrics.
/// Never invents 0% when metrics are missing.
class TeacherHomeAnalyticsSummaryCard extends StatelessWidget {
  final bool loading;
  final String? errorMessage;
  final double? attendancePercent;
  final double? performancePercent;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const TeacherHomeAnalyticsSummaryCard({
    super.key,
    this.loading = false,
    this.errorMessage,
    this.attendancePercent,
    this.performancePercent,
    this.onTap,
    this.onRetry,
  });

  bool get _hasMetrics =>
      attendancePercent != null && performancePercent != null;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: InkWell(
          onTap: loading || errorMessage != null || !_hasMetrics ? null : onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: loading
                  ? const _AnalyticsSummarySkeleton()
                  : errorMessage != null
                  ? _AnalyticsSummaryError(
                      message: errorMessage!,
                      onRetry: onRetry,
                    )
                  : !_hasMetrics
                  ? const _AnalyticsSummaryEmpty()
                  : _AnalyticsSummaryLoaded(
                      attendancePercent: attendancePercent!,
                      performancePercent: performancePercent!,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsSummaryLoaded extends StatelessWidget {
  final double attendancePercent;
  final double performancePercent;

  const _AnalyticsSummaryLoaded({
    required this.attendancePercent,
    required this.performancePercent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _AnalyticsAccentMark(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'التحليلات',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textHint.withValues(alpha: 0.9),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ملخص آخر ٣٠ يوماً — افتح لوحة التحليلات',
                textAlign: TextAlign.right,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _AnalyticsMetricChip(
                      label: 'نسبة الحضور',
                      value:
                          '${teacherHomeEasternDigits('${attendancePercent.round()}')}%',
                      accent: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AnalyticsMetricChip(
                      label: 'متوسط الأداء',
                      value:
                          '${teacherHomeEasternDigits('${performancePercent.round()}')}%',
                      accent: AppColors.gradeVeryGood,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Decorative grade-color accent only — does not encode percentages.
class _AnalyticsAccentMark extends StatelessWidget {
  const _AnalyticsAccentMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: CustomPaint(painter: _AnalyticsAccentArcPainter()),
    );
  }
}

class _AnalyticsAccentArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const stroke = 7.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const colors = [
      AppColors.gradeExcellent,
      AppColors.gradeVeryGood,
      AppColors.gradeGood,
      AppColors.gradeNeedsWork,
    ];
    // Equal decorative segments — not data-driven.
    const sweep = 1.55; // ~89° each, with gaps
    var start = -1.2;
    for (final color in colors) {
      canvas.drawArc(
        rect,
        start,
        sweep * 0.72,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      start += sweep * 0.85;
    }
    canvas.drawCircle(
      center,
      radius - 11,
      Paint()..color = AppColors.primaryLight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnalyticsMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _AnalyticsMetricChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: accent,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.right,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSummarySkeleton extends StatelessWidget {
  const _AnalyticsSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bone(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bone(120, 14),
              const SizedBox(height: 8),
              bone(180, 10),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: bone(double.infinity, 48)),
                  const SizedBox(width: 10),
                  Expanded(child: bone(double.infinity, 48)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsSummaryError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _AnalyticsSummaryError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التحليلات',
          textAlign: TextAlign.right,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalyticsSummaryEmpty extends StatelessWidget {
  const _AnalyticsSummaryEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التحليلات',
          textAlign: TextAlign.right,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'لا توجد بيانات تحليلات كافية للعرض حالياً',
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Resolves which halaqa the Home Analytics card should open.
///
/// Order: featured session → first teacher halaqa → null (hide card).
String? resolveTeacherHomeAnalyticsHalaqaId({
  required String? featuredSessionHalaqaId,
  required List<String> teacherHalaqaIds,
}) {
  final featured = featuredSessionHalaqaId?.trim() ?? '';
  if (featured.isNotEmpty) return featured;
  for (final id in teacherHalaqaIds) {
    final t = id.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}
