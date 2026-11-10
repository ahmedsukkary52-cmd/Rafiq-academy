import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_skeleton.dart';

/// Teacher alias of [AppSkeletonPulse] (stable import path).
class TeacherPulse extends StatelessWidget {
  final Widget Function(BuildContext context, Color bone) builder;

  const TeacherPulse({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(builder: builder);
  }
}

Widget teacherSkeletonBar({
  required Color bone,
  double? width,
  required double height,
  double radius = AppSizes.radiusS,
}) {
  return AppSkeletonBox(
    bone: bone,
    width: width,
    height: height,
    radius: radius,
  );
}

Widget teacherSkeletonCard({
  required Color bone,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(AppSizes.paddingM),
}) {
  return AppSkeletonCard(padding: padding, child: child);
}

/// Classes list cards (~halaqa card height).
class TeacherClassesListSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherClassesListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => teacherSkeletonCard(
            bone: bone,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: teacherSkeletonBar(bone: bone, height: 16)),
                    const SizedBox(width: 8),
                    teacherSkeletonBar(
                      bone: bone,
                      width: 56,
                      height: 22,
                      radius: AppSizes.radiusFull,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                teacherSkeletonBar(bone: bone, width: 160, height: 12),
                const SizedBox(height: 8),
                teacherSkeletonBar(bone: bone, width: 120, height: 12),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: teacherSkeletonBar(
                        bone: bone,
                        height: 36,
                        radius: AppSizes.radiusM,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: teacherSkeletonBar(
                        bone: bone,
                        height: 36,
                        radius: AppSizes.radiusM,
                      ),
                    ),
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

/// Class Details header stat chips (student / attendance / progress).
class TeacherClassHeaderStatsSkeleton extends StatelessWidget {
  const TeacherClassHeaderStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.onPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Column(
                    children: [
                      teacherSkeletonBar(
                        bone: bone.withValues(alpha: 0.55),
                        width: 28,
                        height: 18,
                      ),
                      const SizedBox(height: 8),
                      teacherSkeletonBar(
                        bone: bone.withValues(alpha: 0.45),
                        width: 40,
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Class Details students roster cards.
class TeacherStudentsRosterSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherStudentsRosterSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => teacherSkeletonCard(
            bone: bone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 22, backgroundColor: bone),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          teacherSkeletonBar(
                            bone: bone,
                            width: 140,
                            height: 14,
                          ),
                          const SizedBox(height: 8),
                          teacherSkeletonBar(bone: bone, width: 90, height: 11),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                teacherSkeletonBar(
                  bone: bone,
                  height: 8,
                  radius: AppSizes.radiusFull,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: teacherSkeletonBar(
                          bone: bone,
                          height: 34,
                          radius: AppSizes.radiusM,
                        ),
                      ),
                    ],
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

/// Attendance / evaluation roster rows.
class TeacherRosterRowsSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherRosterRowsSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => teacherSkeletonCard(
            bone: bone,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: bone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      teacherSkeletonBar(bone: bone, width: 130, height: 13),
                      const SizedBox(height: 8),
                      teacherSkeletonBar(bone: bone, width: 80, height: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                teacherSkeletonBar(
                  bone: bone,
                  width: 72,
                  height: 32,
                  radius: AppSizes.radiusM,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tasks / activity cards.
class TeacherTasksListSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherTasksListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return Column(
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              teacherSkeletonCard(
                bone: bone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    teacherSkeletonBar(bone: bone, width: 180, height: 14),
                    const SizedBox(height: 10),
                    teacherSkeletonBar(bone: bone, width: 120, height: 11),
                    const SizedBox(height: 10),
                    teacherSkeletonBar(
                      bone: bone,
                      height: 8,
                      radius: AppSizes.radiusFull,
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
