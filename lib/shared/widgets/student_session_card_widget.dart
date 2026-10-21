import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../features/student/domain/entities/halaqa_entity.dart';
import '../domain/meeting_link_policy.dart';

/// كارت حصة اليوم — Figma dark navy card + full-width join CTA.
class StudentSessionCardWidget extends StatelessWidget {
  final HalaqaEntity halaqa;
  final VoidCallback onJoinTap;
  final VoidCallback? onDetailsTap;

  const StudentSessionCardWidget({
    super.key,
    required this.halaqa,
    required this.onJoinTap,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final nextSchedule = halaqa.schedule.isNotEmpty
        ? halaqa.schedule.first
        : null;

    return GestureDetector(
      onTap: onDetailsTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2C3440),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nextSchedule != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'اليوم — ${nextSchedule.startTime}',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.access_time_rounded,
                    color: Colors.white60,
                    size: 15,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'حصة الحفظ اليومية',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    halaqa.name,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'انضم للحصة',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_back_rounded, size: 18),
                  ],
                ),
              ),
            ),
            if (joinableMeetingUri(halaqa.meetingLink) == null) ...[
              const SizedBox(height: 8),
              Text(
                halaqa.meetingLink.trim().isEmpty
                    ? 'لم يُضبط رابط الاجتماع لهذه الحلقة بعد'
                    : 'رابط الاجتماع المحفوظ غير صالح',
                key: const Key('sessionCardLinkStatus'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
