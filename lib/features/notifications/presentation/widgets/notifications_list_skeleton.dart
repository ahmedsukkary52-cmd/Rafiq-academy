import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_skeleton.dart';

/// Notifications list rows.
class TeacherNotificationsListSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherNotificationsListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: bone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppSkeletonBox(bone: bone, width: 160, height: 13),
                      const SizedBox(height: 8),
                      AppSkeletonBox(bone: bone, width: 220, height: 11),
                      const SizedBox(height: 8),
                      AppSkeletonBox(bone: bone, width: 70, height: 10),
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
