import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../features/student/domain/entities/assignment_entity.dart';

/// كارت «حفظ اليوم» / درس اليوم.
///
/// يقرأ المهمة الحالية من [assignment] (Firestore `assignments` عبر الـ Bloc).
class StudentDailyTaskWidget extends StatelessWidget {
  final AssignmentEntity? assignment;
  final VoidCallback onReadTap;
  final VoidCallback onListenTap;
  final VoidCallback? onCardTap;

  const StudentDailyTaskWidget({
    super.key,
    required this.assignment,
    required this.onReadTap,
    required this.onListenTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSubmitted = assignment?.isSubmitted == true;
    final range = assignment?.displayTitle.isNotEmpty == true
        ? assignment!.displayTitle
        : (assignment?.newMemorizationRange ?? 'لا يوجد تكليف حالياً');
    final suraName = assignment != null ? _extractSura(range) : 'الورد اليومي';
    final versesRange = assignment != null
        ? _extractVerses(
            assignment!.newMemorizationRange.isNotEmpty
                ? assignment!.newMemorizationRange
                : range,
          )
        : '';

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSubmitted
                ? const [AppColors.primaryDark, Color(0xFF178F82)]
                : const [AppColors.primary, Color(0xFF1FA99A)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                if (isSubmitted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: const Text(
                      'تم الإنهاء ✅',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  isSubmitted ? 'حفظ اليوم — مكتمل' : 'حفظ اليوم',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              suraName,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (versesRange.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'الآيات $versesRange',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TaskButton(
                    label: isSubmitted ? 'التفاصيل' : 'اقرأ',
                    icon: isSubmitted
                        ? Icons.check_circle_outline
                        : Icons.chrome_reader_mode_outlined,
                    onTap: onReadTap,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TaskButton(
                    label: 'استمع',
                    icon: Icons.headphones_rounded,
                    onTap: onListenTap,
                    isPrimary: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _extractSura(String range) {
    if (range.contains('-')) return range.split('-').first.trim();
    return range;
  }

  String _extractVerses(String range) {
    if (range.contains('الآيات')) {
      return range.split('الآيات').last.trim();
    }
    return '';
  }
}

class _TaskButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _TaskButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? AppColors.primary : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? AppColors.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
