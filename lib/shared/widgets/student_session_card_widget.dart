import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../features/student/domain/entities/halaqa_entity.dart';

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
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onJoinTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'انضم للجلسة',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (nextSchedule != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'اليوم — ${nextSchedule.startTime}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.access_time_rounded,
                          color: Colors.white60,
                          size: 14,
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    halaqa.name,
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${halaqa.studentIds.length} طالباً',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.people_outline_rounded,
                        color: Colors.white60,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
