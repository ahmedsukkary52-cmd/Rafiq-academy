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

  Widget _actionCell(Color bone) {
    return Column(
      children: [
        CircleAvatar(radius: 22, backgroundColor: bone),
        const SizedBox(height: 8),
        parentSkeletonBar(bone: bone, width: 44, height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              parentSkeletonCard(
                bone: bone,
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _actionCell(bone)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _actionCell(bone)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: parentSkeletonBar(bone: bone, width: 140, height: 14),
              ),
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
              parentSkeletonBar(bone: bone, width: 150, height: 14),
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: parentSkeletonCard(
                  bone: bone,
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 16),
              parentSkeletonCard(
                bone: bone,
                child: Column(
                  children: [
                    parentSkeletonBar(bone: bone, width: 180, height: 14),
                    const SizedBox(height: 12),
                    parentSkeletonBar(
                      bone: bone,
                      height: 72,
                      radius: AppSizes.radiusM,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            padding: EdgeInsets.zero,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 6, color: bone),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              parentSkeletonBar(
                                bone: bone,
                                width: 44,
                                height: 28,
                              ),
                              const Spacer(),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    parentSkeletonBar(
                                      bone: bone,
                                      width: 140,
                                      height: 14,
                                    ),
                                    const SizedBox(height: 8),
                                    parentSkeletonBar(
                                      bone: bone,
                                      width: 90,
                                      height: 11,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              CircleAvatar(radius: 22, backgroundColor: bone),
                            ],
                          ),
                          const SizedBox(height: 12),
                          parentSkeletonBar(
                            bone: bone,
                            height: 8,
                            radius: AppSizes.radiusFull,
                          ),
                          const SizedBox(height: 12),
                          parentSkeletonBar(
                            bone: bone,
                            height: 36,
                            radius: AppSizes.radiusM,
                          ),
                          const SizedBox(height: 10),
                          parentSkeletonBar(
                            bone: bone,
                            height: 40,
                            radius: AppSizes.radiusM,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ParentListCardsSkeleton extends StatelessWidget {
  const ParentListCardsSkeleton({
    super.key,
    this.itemCount = 4,
    this.shrinkWrap = false,
    this.physics,
  });

  final int itemCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          shrinkWrap: shrinkWrap,
          physics: physics,
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

/// Account stats strip (أبناء / حضور / آية) while the household loads.
class ParentAccountStatsSkeleton extends StatelessWidget {
  const ParentAccountStatsSkeleton({super.key, this.height = 72});

  final double height;

  Widget _cell(Color bone) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          parentSkeletonBar(bone: bone, width: 42, height: 16),
          const SizedBox(height: 6),
          parentSkeletonBar(bone: bone, width: 28, height: 9),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0)
                  Container(width: 0.8, height: 36, color: AppColors.border),
                _cell(bone),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Subscriptions page: gradient header bone + summary card + payment cards.
class ParentPaymentsSkeleton extends StatelessWidget {
  const ParentPaymentsSkeleton({super.key, this.headerHeight = 230});

  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return ListView(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: SizedBox(height: headerHeight),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top + 8,
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Row(
                        children: [
                          parentSkeletonBar(
                            bone: bone,
                            width: 40,
                            height: 40,
                            radius: AppSizes.radiusM,
                          ),
                          const Spacer(),
                          parentSkeletonBar(bone: bone, width: 140, height: 18),
                          const Spacer(),
                          parentSkeletonBar(
                            bone: bone,
                            width: 40,
                            height: 40,
                            radius: AppSizes.radiusM,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.onPrimaryOverlay,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusXL,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            parentSkeletonBar(
                              bone: bone,
                              width: 100,
                              height: 11,
                            ),
                            const SizedBox(height: 8),
                            parentSkeletonBar(
                              bone: bone,
                              width: 180,
                              height: 26,
                            ),
                            const SizedBox(height: 12),
                            parentSkeletonBar(
                              bone: bone,
                              height: 8,
                              radius: AppSizes.radiusFull,
                            ),
                            const SizedBox(height: 10),
                            parentSkeletonBar(
                              bone: bone,
                              width: 140,
                              height: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusXL),
                  topRight: Radius.circular(AppSizes.radiusXL),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          parentSkeletonBar(
                            bone: bone,
                            width: 64,
                            height: 32,
                            radius: AppSizes.radiusFull,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < 3; i++) ...[
                      parentSkeletonCard(
                        bone: bone,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                parentSkeletonBar(
                                  bone: bone,
                                  width: 44,
                                  height: 44,
                                  radius: AppSizes.radiusM,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      parentSkeletonBar(bone: bone, height: 14),
                                      const SizedBox(height: 6),
                                      parentSkeletonBar(
                                        bone: bone,
                                        width: 120,
                                        height: 11,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                parentSkeletonBar(
                                  bone: bone,
                                  width: 64,
                                  height: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            parentSkeletonBar(
                              bone: bone,
                              height: 42,
                              radius: AppSizes.radiusM,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Attendance month grid: weekday row + 5×7 day circles.
class ParentCalendarSkeleton extends StatelessWidget {
  const ParentCalendarSkeleton({super.key, this.weeks = 5});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: parentSkeletonBar(
                          bone: bone,
                          width: 12,
                          height: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: weeks * 7,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (_, __) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: bone,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Child profile page: hero bar + 3 stats + 2×2 actions + progress donut.
class ParentChildProfileSkeleton extends StatelessWidget {
  const ParentChildProfileSkeleton({super.key, this.heroHeight = 260});

  final double heroHeight;

  Widget _actionBone(Color bone) {
    return Expanded(
      child: parentSkeletonBar(
        bone: bone,
        height: 48,
        radius: AppSizes.radiusL,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParentPulse(
      builder: (context, bone) {
        return ListView(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: SizedBox(height: heroHeight),
                  ),
                ),
                Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          children: [
                            CircleAvatar(radius: 46, backgroundColor: bone),
                            const SizedBox(height: 12),
                            parentSkeletonBar(
                              bone: bone,
                              width: 150,
                              height: 18,
                            ),
                            const SizedBox(height: 8),
                            parentSkeletonBar(
                              bone: bone,
                              width: 110,
                              height: 12,
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: parentSkeletonCard(
                        bone: bone,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0)
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: AppColors.border,
                                ),
                              Expanded(
                                child: Column(
                                  children: [
                                    parentSkeletonBar(
                                      bone: bone,
                                      width: 46,
                                      height: 16,
                                    ),
                                    const SizedBox(height: 6),
                                    parentSkeletonBar(
                                      bone: bone,
                                      width: 30,
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
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _actionBone(bone),
                      const SizedBox(width: 10),
                      _actionBone(bone),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _actionBone(bone),
                      const SizedBox(width: 10),
                      _actionBone(bone),
                    ],
                  ),
                  const SizedBox(height: 20),
                  parentSkeletonCard(
                    bone: bone,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      children: [
                        Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: bone, width: 14),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            for (var i = 0; i < 2; i++) ...[
                              if (i > 0)
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: AppColors.border,
                                ),
                              Expanded(
                                child: Column(
                                  children: [
                                    parentSkeletonBar(
                                      bone: bone,
                                      width: 52,
                                      height: 16,
                                    ),
                                    const SizedBox(height: 6),
                                    parentSkeletonBar(
                                      bone: bone,
                                      width: 64,
                                      height: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
