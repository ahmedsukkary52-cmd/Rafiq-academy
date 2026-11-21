import 'package:flutter/material.dart';

import '../domain/halaqa_entity.dart';
import '../domain/halaqa_meeting_link.dart';
import '../theme/app_theme.dart';
import 'halaqa_meeting_link_builder.dart';
import 'shared_widgets.dart';

/// كارت حلقتي — تصميم بهيج بهوية التيل مع تفاصيل الجلسة.
class StudentSessionCardWidget extends StatelessWidget {
  final HalaqaEntity halaqa;
  final VoidCallback onJoinTap;
  final VoidCallback? onDetailsTap;
  final GetHalaqaMeetingLinkUseCase getMeetingLink;

  const StudentSessionCardWidget({
    super.key,
    required this.halaqa,
    required this.onJoinTap,
    required this.getMeetingLink,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final nextSchedule = halaqa.schedule.isNotEmpty
        ? halaqa.schedule.first
        : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: onDetailsTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF1A3A42),
                Color(0xFF16363D),
                Color(0xFF0F2A30),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حلقتي',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          halaqa.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (nextSchedule != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            nextSchedule.startTime,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (nextSchedule != null) ...[
                const SizedBox(height: 12),
                Text(
                  nextSchedule.day.isNotEmpty
                      ? '${nextSchedule.day} — ${nextSchedule.startTime}'
                      : 'موعد الجلسة — ${nextSchedule.startTime}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onJoinTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'انضم للحصة',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const AppForwardIcon(size: 18),
                    ],
                  ),
                ),
              ),
              if (onDetailsTap != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDetailsTap,
                  child: Text(
                    'عرض الجدول والتفاصيل',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              HalaqaMeetingLinkBuilder(
                halaqaId: halaqa.id,
                getMeetingLink: getMeetingLink,
                builder: (context, view, reload) {
                  final status = _linkStatusText(view);
                  if (status == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          status,
                          key: const Key('sessionCardLinkStatus'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        if (view is MeetingLinkFailed)
                          TextButton(
                            key: const Key('sessionCardLinkRetry'),
                            onPressed: reload,
                            child: Text(
                              'إعادة المحاولة',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hint under the Join button; null while loading or when joinable.
String? _linkStatusText(MeetingLinkView view) => switch (view) {
  MeetingLinkLoading() => null,
  MeetingLinkLoaded(:final availability) => switch (availability) {
    MeetingLinkAvailability.joinable => null,
    MeetingLinkAvailability.missing => 'لم يُضبط رابط الاجتماع لهذه الحلقة بعد',
    MeetingLinkAvailability.invalid => 'رابط الاجتماع المحفوظ غير صالح',
  },
  MeetingLinkDenied() => 'لا تملك صلاحية الوصول إلى رابط الاجتماع',
  MeetingLinkFailed() => 'تعذر التحقق من رابط الاجتماع الآن',
};
