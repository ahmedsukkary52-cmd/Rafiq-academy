import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_skeleton.dart';

/// Posts feed cards.
class TeacherPostsListSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherPostsListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => AppSkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppSkeletonBox(bone: bone, width: 64, height: 10),
                    Row(
                      children: [
                        CircleAvatar(radius: 18, backgroundColor: bone),
                        const SizedBox(width: 8),
                        AppSkeletonBox(bone: bone, width: 100, height: 13),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppSkeletonBox(bone: bone, height: 12),
                const SizedBox(height: 8),
                AppSkeletonBox(bone: bone, width: 220, height: 12),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppSkeletonBox(bone: bone, width: 40, height: 12),
                    const SizedBox(width: 20),
                    AppSkeletonBox(bone: bone, width: 40, height: 12),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
