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

/// Skeleton for home «درس اليوم» card.
class StudentDailyTaskSkeleton extends StatelessWidget {
  const StudentDailyTaskSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentPulse(
      builder: (context, bone) {
        return Container(
          height: 178,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              studentSkeletonBar(bone: bone, width: 90, height: 12),
              const SizedBox(height: 14),
              studentSkeletonBar(bone: bone, width: 160, height: 22, radius: 8),
              const SizedBox(height: 10),
              studentSkeletonBar(bone: bone, width: 120, height: 12),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: studentSkeletonBar(
                      bone: bone,
                      height: 42,
                      radius: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: studentSkeletonBar(
                      bone: bone,
                      height: 42,
                      radius: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
