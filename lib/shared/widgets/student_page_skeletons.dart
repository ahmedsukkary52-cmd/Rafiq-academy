import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_skeleton.dart';

/// Full-page list skeleton for evaluations / achievements / schedule rows.
class StudentListPageSkeleton extends StatelessWidget {
  final int itemCount;

  const StudentListPageSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AppSkeletonBox(bone: bone, width: 44, height: 44, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppSkeletonBox(bone: bone, width: 140, height: 14),
                      const SizedBox(height: 8),
                      AppSkeletonBox(bone: bone, width: 200, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Home dashboard body skeleton (header cards + list blocks).
class StudentHomeBodySkeleton extends StatelessWidget {
  const StudentHomeBodySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      builder: (context, bone) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              AppSkeletonBox(bone: bone, height: 88, radius: AppSizes.radiusXL),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AppSkeletonBox(
                        bone: bone,
                        height: 64,
                        radius: AppSizes.radiusL,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              AppSkeletonBox(
                bone: bone,
                height: 120,
                radius: AppSizes.radiusXL,
              ),
              const SizedBox(height: 16),
              AppSkeletonBox(
                bone: bone,
                height: 160,
                radius: AppSizes.radiusXL,
              ),
            ],
          ),
        );
      },
    );
  }
}
