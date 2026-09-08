import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Shared pulse opacity for Student loading skeletons (no shimmer package).
class StudentPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color bone) builder;

  const StudentPulse({super.key, required this.builder});

  @override
  State<StudentPulse> createState() => _StudentPulseState();
}

class _StudentPulseState extends State<StudentPulse>
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
    _pulse = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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

Widget studentSkeletonBar({
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

/// Full-page list skeleton for evaluations / achievements / schedule rows.
class StudentListPageSkeleton extends StatelessWidget {
  final int itemCount;

  const StudentListPageSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return StudentPulse(
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
                studentSkeletonBar(
                  bone: bone,
                  width: 44,
                  height: 44,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      studentSkeletonBar(bone: bone, width: 140, height: 14),
                      const SizedBox(height: 8),
                      studentSkeletonBar(bone: bone, width: 200, height: 11),
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
    return StudentPulse(
      builder: (context, bone) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              studentSkeletonBar(
                bone: bone,
                height: 88,
                radius: AppSizes.radiusXL,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: studentSkeletonBar(
                        bone: bone,
                        height: 64,
                        radius: AppSizes.radiusL,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              studentSkeletonBar(
                bone: bone,
                height: 120,
                radius: AppSizes.radiusXL,
              ),
              const SizedBox(height: 16),
              studentSkeletonBar(
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
