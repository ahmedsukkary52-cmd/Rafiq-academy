import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/assignment_entity.dart';
import 'student_loading_skeletons.dart';

/// كارت «درس اليوم» — مطابق لـ Figma Home.
class StudentDailyTaskWidget extends StatelessWidget {
  final AssignmentEntity? assignment;
  final SectionStatus status;
  final String? errorMessage;
  final VoidCallback onReadTap;
  final VoidCallback onListenTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onRetry;

  const StudentDailyTaskWidget({
    super.key,
    required this.assignment,
    this.status = SectionStatus.loaded,
    this.errorMessage,
    required this.onReadTap,
    required this.onListenTap,
    this.onCardTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == SectionStatus.loading || status == SectionStatus.initial) {
      return const StudentDailyTaskSkeleton();
    }

    if (status == SectionStatus.error) {
      return _EmptyShell(
        child: Column(
          children: [
            Text(
              errorMessage ?? 'تعذر تحميل درس اليوم',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (assignment == null) {
      return _EmptyShell(
        child: Text(
          'لا يوجد درس اليوم حالياً\nسيظهر هنا عند إرساله من المعلم',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final isSubmitted = assignment!.isSubmitted;
    final range = assignment!.displayTitle.isNotEmpty
        ? assignment!.displayTitle
        : assignment!.newMemorizationRange;
    final suraName = _extractSura(range.isNotEmpty ? range : 'درس اليوم');
    final versesRange = _extractVerses(
      assignment!.newMemorizationRange.isNotEmpty
          ? assignment!.newMemorizationRange
          : range,
    );

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1ECAD6), Color(0xFF0E8F9A)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: -8,
              bottom: -18,
              child: Icon(
                Icons.menu_book_rounded,
                size: 120,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isSubmitted ? 'درس اليوم — مكتمل' : 'درس اليوم',
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    suraName,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  if (versesRange.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الآيات $versesRange',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineAction(
                          label: isSubmitted ? 'التفاصيل' : 'اقرأ',
                          icon: Icons.chrome_reader_mode_outlined,
                          onTap: onReadTap,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SolidAction(
                          label: 'استمع',
                          icon: Icons.headphones_rounded,
                          onTap: onListenTap,
                        ),
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

class _EmptyShell extends StatelessWidget {
  final Widget child;
  const _EmptyShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolidAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SolidAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
