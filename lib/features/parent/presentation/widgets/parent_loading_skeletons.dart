import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

class ParentPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color bone) builder;

  const ParentPulse({super.key, required this.builder});

  @override
  State<ParentPulse> createState() => _ParentPulseState();
}

class _ParentPulseState extends State<ParentPulse>
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

Widget parentSkeletonBar({
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

Widget parentSkeletonCard({
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

class ParentDashboardSkeleton extends StatelessWidget {
  const ParentDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < 6; i++)
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 52) / 3,
                    child: parentSkeletonCard(
                      bone: bone,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          parentSkeletonBar(
                            bone: bone,
                            width: 28,
                            height: 28,
                            radius: AppSizes.radiusM,
                          ),
                          const SizedBox(height: 8),
                          parentSkeletonBar(bone: bone, width: 48, height: 10),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            parentSkeletonBar(bone: bone, width: 140, height: 14),
            const SizedBox(height: 12),
            for (var i = 0; i < 2; i++) ...[
              parentSkeletonCard(
                bone: bone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    parentSkeletonBar(bone: bone, width: 160, height: 14),
                    const SizedBox(height: 8),
                    parentSkeletonBar(bone: bone, height: 11),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: parentSkeletonCard(
                bone: bone,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ParentChildrenListSkeleton extends StatelessWidget {
  const ParentChildrenListSkeleton({super.key, this.itemCount = 2});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => parentSkeletonCard(
            bone: bone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    parentSkeletonBar(bone: bone, width: 44, height: 22),
                    const Spacer(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          parentSkeletonBar(bone: bone, width: 140, height: 14),
                          const SizedBox(height: 8),
                          parentSkeletonBar(bone: bone, width: 90, height: 11),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(radius: 22, backgroundColor: bone),
                  ],
                ),
                const SizedBox(height: 14),
                parentSkeletonBar(
                  bone: bone,
                  height: 8,
                  radius: AppSizes.radiusFull,
                ),
                const SizedBox(height: 12),
                parentSkeletonBar(bone: bone, height: 40, radius: AppSizes.radiusM),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ParentListCardsSkeleton extends StatelessWidget {
  const ParentListCardsSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => parentSkeletonCard(
            bone: bone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                parentSkeletonBar(bone: bone, width: 160, height: 14),
                const SizedBox(height: 8),
                parentSkeletonBar(bone: bone, height: 11),
                const SizedBox(height: 8),
                parentSkeletonBar(bone: bone, width: 100, height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ParentProfileHeaderSkeleton extends StatelessWidget {
  const ParentProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            children: [
              CircleAvatar(radius: 40, backgroundColor: bone),
              const SizedBox(height: 12),
              parentSkeletonBar(bone: bone, width: 160, height: 16),
              const SizedBox(height: 8),
              parentSkeletonBar(bone: bone, width: 120, height: 12),
            ],
          ),
        );
      },
    );
  }
}
