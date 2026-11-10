import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_skeleton.dart';

/// Awards dashboard: stats strip + history cards.
class TeacherAwardsDashboardSkeleton extends StatelessWidget {
  const TeacherAwardsDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      builder: (context, bone) {
        return ListView(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: AppSkeletonCard(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          AppSkeletonBox(bone: bone, width: 36, height: 22),
                          const SizedBox(height: 8),
                          AppSkeletonBox(bone: bone, width: 56, height: 11),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              AppSkeletonCard(
                child: Row(
                  children: [
                    CircleAvatar(radius: 22, backgroundColor: bone),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppSkeletonBox(bone: bone, width: 150, height: 14),
                          const SizedBox(height: 8),
                          AppSkeletonBox(bone: bone, width: 100, height: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Compact awards history list (inside loaded dashboard).
class TeacherAwardsHistorySkeleton extends StatelessWidget {
  const TeacherAwardsHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      builder: (context, bone) {
        return Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                AppSkeletonCard(
                  child: Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundColor: bone),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AppSkeletonBox(bone: bone, width: 140, height: 13),
                            const SizedBox(height: 8),
                            AppSkeletonBox(bone: bone, width: 90, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
