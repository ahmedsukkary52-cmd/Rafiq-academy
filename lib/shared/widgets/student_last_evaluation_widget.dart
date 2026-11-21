import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../domain/recitation_record_entity.dart';

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'آخر تقييم',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onDetailsTap,
                  child: Text(
                    'التفاصيل',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(record.date),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                _OverallGradeBadge(grade: record.grade),
                GradeChip(label: record.grade.displayLabel),
                GradeChip(label: record.behaviorGrade.displayLabel),
              ],
            ),
            if (record.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryDark,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.notes!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: List.generate(4, (i) {
                final filled = i < _starsForGrade(record.grade);
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.secondary : AppColors.textHint,
                    size: 22,
                  ),
                );
              }),
            ),
          ],
        ),
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
        style: AppTextStyles.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class StudentHadithWidget extends StatelessWidget {
  const StudentHadithWidget({super.key});

  static const _hadiths = [
    ('«خيركم من تعلّم القرآن وعلّمه»', 'صحيح البخاري'),
    ('«من قرأ حرفاً من كتاب الله فله به حسنة»', 'رواه الترمذي'),
    ('«اقرؤوا القرآن فإنه يأتي يوم القيامة شفيعاً لأصحابه»', 'رواه مسلم'),
    ('«الذي يقرأ القرآن وهو ماهر به مع السفرة الكرام البررة»', 'رواه البخاري'),
    ('«الماهر بالقرآن مع السفرة الكرام البررة»', 'متفق عليه'),
    ('«إن هذا القرآن مأدبة الله فتعلّموا مأدبته»', 'رواه الحاكم'),
    ('«يقال لصاحب القرآن: اقرأ وارتقِ ورتّل»', 'رواه أبو داود'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = DateTime.now().day % _hadiths.length;
    final (text, source) = _hadiths[index];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.secondary,
              AppColors.secondaryDeep,
              Color(0xFFE07A00),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryDeep.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'حديث اليوم',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.65,
                fontSize: 16,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            Text(
              source,
              textAlign: TextAlign.right,
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
