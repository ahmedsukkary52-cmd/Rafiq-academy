import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Shared pulse opacity for Teacher loading skeletons (no shimmer package).
class TeacherPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color bone) builder;

  const TeacherPulse({super.key, required this.builder});

  @override
  State<TeacherPulse> createState() => _TeacherPulseState();
}

class _TeacherPulseState extends State<TeacherPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bone = AppColors.border.withValues(alpha: _pulse.value);
        return widget.builder(context, bone);
      },
    );
  }
}

Widget teacherSkeletonBar({
  required Color bone,
  double? width,
  required double height,
  double radius = AppSizes.radiusS,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: bone,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

Widget teacherSkeletonCard({
  required Color bone,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(AppSizes.paddingM),
}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
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
                          teacherSkeletonBar(bone: bone, width: 140, height: 14),
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

/// Awards dashboard: stats strip + history cards.
class TeacherAwardsDashboardSkeleton extends StatelessWidget {
  const TeacherAwardsDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return ListView(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: teacherSkeletonCard(
                      bone: bone,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          teacherSkeletonBar(bone: bone, width: 36, height: 22),
                          const SizedBox(height: 8),
                          teacherSkeletonBar(bone: bone, width: 56, height: 11),
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
              teacherSkeletonCard(
                bone: bone,
                child: Row(
                  children: [
                    CircleAvatar(radius: 22, backgroundColor: bone),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          teacherSkeletonBar(bone: bone, width: 150, height: 14),
                          const SizedBox(height: 8),
                          teacherSkeletonBar(bone: bone, width: 100, height: 11),
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
    return TeacherPulse(
      builder: (context, bone) {
        return Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                teacherSkeletonCard(
                  bone: bone,
                  child: Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundColor: bone),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            teacherSkeletonBar(
                              bone: bone,
                              width: 140,
                              height: 13,
                            ),
                            const SizedBox(height: 8),
                            teacherSkeletonBar(
                              bone: bone,
                              width: 90,
                              height: 10,
                            ),
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

/// Posts feed cards.
class TeacherPostsListSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherPostsListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => teacherSkeletonCard(
            bone: bone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    teacherSkeletonBar(bone: bone, width: 64, height: 10),
                    Row(
                      children: [
                        CircleAvatar(radius: 18, backgroundColor: bone),
                        const SizedBox(width: 8),
                        teacherSkeletonBar(bone: bone, width: 100, height: 13),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                teacherSkeletonBar(bone: bone, height: 12),
                const SizedBox(height: 8),
                teacherSkeletonBar(bone: bone, width: 220, height: 12),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    teacherSkeletonBar(bone: bone, width: 40, height: 12),
                    const SizedBox(width: 20),
                    teacherSkeletonBar(bone: bone, width: 40, height: 12),
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

/// Notifications list rows.
class TeacherNotificationsListSkeleton extends StatelessWidget {
  final int itemCount;

  const TeacherNotificationsListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
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
                      teacherSkeletonBar(bone: bone, width: 160, height: 13),
                      const SizedBox(height: 8),
                      teacherSkeletonBar(bone: bone, width: 220, height: 11),
                      const SizedBox(height: 8),
                      teacherSkeletonBar(bone: bone, width: 70, height: 10),
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

/// Teacher Student Profile page body.
class TeacherStudentProfileSkeleton extends StatelessWidget {
  const TeacherStudentProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return TeacherPulse(
      builder: (context, bone) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 260,
                color: AppColors.primary.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(radius: 44, backgroundColor: bone),
                    const SizedBox(height: 12),
                    teacherSkeletonBar(bone: bone, width: 160, height: 16),
                    const SizedBox(height: 8),
                    teacherSkeletonBar(bone: bone, width: 120, height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: teacherSkeletonCard(
                      bone: bone,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            Expanded(
                              child: Column(
                                children: [
                                  teacherSkeletonBar(
                                    bone: bone,
                                    width: 40,
                                    height: 20,
                                  ),
                                  const SizedBox(height: 6),
                                  teacherSkeletonBar(
                                    bone: bone,
                                    width: 56,
                                    height: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: teacherSkeletonBar(
                          bone: bone,
                          height: 48,
                          radius: AppSizes.radiusL,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: teacherSkeletonBar(
                          bone: bone,
                          height: 48,
                          radius: AppSizes.radiusL,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    teacherSkeletonCard(
                      bone: bone,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          teacherSkeletonBar(bone: bone, width: 120, height: 14),
                          const SizedBox(height: 14),
                          teacherSkeletonBar(bone: bone, height: 12),
                          const SizedBox(height: 10),
                          teacherSkeletonBar(bone: bone, width: 180, height: 12),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}
