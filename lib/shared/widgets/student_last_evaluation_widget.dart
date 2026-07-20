import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../features/student/domain/entities/recitation_record_entity.dart';

// ══════════════════════════════════════════════════════════════════════════════
// StudentLastEvaluationWidget - آخر تقييم
// ══════════════════════════════════════════════════════════════════════════════

class StudentLastEvaluationWidget extends StatelessWidget {
  final RecitationRecordEntity record;
  final VoidCallback onDetailsTap;

  const StudentLastEvaluationWidget({
    super.key,
    required this.record,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onDetailsTap,
                child: Text(
                  'التفاصيل',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Row(
                children: [
                  Text('آخر تقييم', style: AppTextStyles.titleMedium),
                  SizedBox(width: 6),
                  Icon(
                    Icons.star_outline_rounded,
                    color: AppColors.secondary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // تاريخ التقييم
          Text(_formatDate(record.date), style: AppTextStyles.labelSmall),

          const SizedBox(height: 8),

          // الدرجات الثلاث
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GradeChip(label: record.behaviorGrade.displayLabel),
              const SizedBox(width: 8),
              GradeChip(label: record.grade.displayLabel),
              const SizedBox(width: 8),
              // بادج درجة الحفظ (الأعلى)
              _OverallGradeBadge(grade: record.grade),
            ],
          ),

          const SizedBox(height: 10),

          // ملاحظة المعلم
          if (record.notes?.isNotEmpty == true)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    record.notes!,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ],
            ),

          const SizedBox(height: 8),

          // النجوم
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(4, (i) {
              final filled = i < _starsForGrade(record.grade);
              return Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: filled ? AppColors.secondary : AppColors.textHint,
                size: 20,
              );
            }),
          ),
        ],
      ),
    );
  }

  int _starsForGrade(RecitationGrade? grade) => switch (grade) {
    RecitationGrade.excellent => 4,
    RecitationGrade.veryGood => 3,
    RecitationGrade.good => 2,
    RecitationGrade.needsRetry => 1,
    null => 0,
  };

  String _formatDate(DateTime date) {
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}

class _OverallGradeBadge extends StatelessWidget {
  final RecitationGrade? grade;

  const _OverallGradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = grade == null
        ? AppColors.textSecondary
        : grade == RecitationGrade.excellent
        ? AppColors.gradeExcellent
        : AppColors.gradeVeryGood;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Text(
        grade.displayLabel,
        style: const TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// StudentHadithWidget - حديث اليوم
// ══════════════════════════════════════════════════════════════════════════════

class StudentHadithWidget extends StatelessWidget {
  const StudentHadithWidget({super.key});

  // قائمة أحاديث تشجيعية مؤقتة (يمكن استبدالها بـ API لاحقاً)
  static const _hadiths = [
    ('خيركم من تعلم القرآن وعلّمه', 'رواه البخاري'),
    ('من قرأ حرفاً من كتاب الله فله به حسنة', 'رواه الترمذي'),
    ('اقرؤوا القرآن فإنه يأتي يوم القيامة شفيعاً لأصحابه', 'رواه مسلم'),
    ('الذي يقرأ القرآن وهو ماهر به مع السفرة الكرام البررة', 'رواه البخاري'),
  ];

  @override
  Widget build(BuildContext context) {
    // نختار حديث بناءً على اليوم عشان يتغير يومياً بشكل ثابت
    final index = DateTime.now().day % _hadiths.length;
    final (text, source) = _hadiths[index];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'حديث اليوم',
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.6,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            source,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
