import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Shared pulse shimmer for Supervisor loading states.
class SupervisorPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color bone) builder;

  const SupervisorPulse({super.key, required this.builder});

  @override
  State<SupervisorPulse> createState() => _SupervisorPulseState();
}

class _SupervisorPulseState extends State<SupervisorPulse>
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
      begin: 0.38,
      end: 0.92,
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

Widget supervisorSkeletonBar({
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

Widget supervisorSkeletonCard({
  required Color bone,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
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

class SupervisorListCardsSkeleton extends StatelessWidget {
  final int itemCount;

  const SupervisorListCardsSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return SupervisorPulse(
      builder: (context, bone) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: itemCount,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: supervisorSkeletonCard(
              bone: bone,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  supervisorSkeletonBar(bone: bone, width: 160, height: 14),
                  const SizedBox(height: 10),
                  supervisorSkeletonBar(bone: bone, height: 11),
                  const SizedBox(height: 8),
                  supervisorSkeletonBar(bone: bone, width: 100, height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SupervisorPaymentsListSkeleton extends StatelessWidget {
  const SupervisorPaymentsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SupervisorPulse(
      builder: (context, bone) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: supervisorSkeletonCard(
                      bone: bone,
                      child: Column(
                        children: [
                          supervisorSkeletonBar(
                            bone: bone,
                            width: 36,
                            height: 18,
                          ),
                          const SizedBox(height: 8),
                          supervisorSkeletonBar(
                            bone: bone,
                            width: 56,
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: supervisorSkeletonCard(
                  bone: bone,
                  child: Row(
                    children: [
                      supervisorSkeletonBar(
                        bone: bone,
                        width: 44,
                        height: 44,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            supervisorSkeletonBar(
                              bone: bone,
                              width: 140,
                              height: 13,
                            ),
                            const SizedBox(height: 8),
                            supervisorSkeletonBar(
                              bone: bone,
                              width: 100,
                              height: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SupervisorCenteredListSkeleton extends StatelessWidget {
  const SupervisorCenteredListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: SupervisorListCardsSkeleton(itemCount: 5),
    );
  }
}

class SupervisorStatsGridSkeleton extends StatelessWidget {
  const SupervisorStatsGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SupervisorPulse(
      builder: (context, bone) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
          children: List.generate(6, (_) {
            return supervisorSkeletonCard(
              bone: bone,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  supervisorSkeletonBar(
                    bone: bone,
                    width: 40,
                    height: 40,
                    radius: 12,
                  ),
                  const SizedBox(height: 8),
                  supervisorSkeletonBar(bone: bone, width: 48, height: 20),
                  const SizedBox(height: 6),
                  supervisorSkeletonBar(bone: bone, width: 80, height: 10),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class SupervisorFormSkeleton extends StatelessWidget {
  const SupervisorFormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SupervisorPulse(
      builder: (context, bone) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (var i = 0; i < 4; i++) ...[
              supervisorSkeletonBar(bone: bone, width: 100, height: 12),
              const SizedBox(height: 8),
              supervisorSkeletonBar(
                bone: bone,
                height: 52,
                radius: AppSizes.radiusM,
              ),
              const SizedBox(height: 16),
            ],
            supervisorSkeletonBar(
              bone: bone,
              height: 48,
              radius: AppSizes.radiusFull,
            ),
          ],
        );
      },
    );
  }
}
