import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';

/// Honest empty state when the student profile has no halaqa membership.
class StudentNoHalaqaCard extends StatelessWidget {
  const StudentNoHalaqaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('student-home-no-halaqa'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('حلقتي', style: AppTextStyles.titleMedium),
                    Text(
                      'لم تُسند إليك حلقة بعد',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'سيظهر جدول الحصص ورابط الجلسة هنا بعد أن تربطك الإدارة بحلقة.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
