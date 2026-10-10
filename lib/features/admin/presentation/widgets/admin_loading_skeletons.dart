import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Shared pulse shimmer for Admin loading states (no shimmer package).
class AdminPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color bone) builder;

  const AdminPulse({super.key, required this.builder});

  @override
  State<AdminPulse> createState() => _AdminPulseState();
}

class _AdminPulseState extends State<AdminPulse>
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

Widget adminSkeletonBar({
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

Widget adminSkeletonCard({
  required Color bone,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  double radius = AppSizes.radiusL,
}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

/// Gradient hero card placeholder — matches [AdminGradientHeroCard].
class AdminHeroCardSkeleton extends StatelessWidget {
  const AdminHeroCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bone,
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              adminSkeletonBar(bone: bone, width: 110, height: 12, radius: 6),
              const SizedBox(height: 10),
              adminSkeletonBar(bone: bone, width: 180, height: 22, radius: 8),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          adminSkeletonBar(
                            bone: bone,
                            width: 36,
                            height: 18,
                            radius: 6,
                          ),
                          const SizedBox(height: 6),
                          adminSkeletonBar(
                            bone: bone,
                            width: 52,
                            height: 10,
                            radius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 2×2 stat grid — matches dashboard [AdminStatTile].
class AdminDashboardStatsGridSkeleton extends StatelessWidget {
  const AdminDashboardStatsGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: List.generate(4, (_) {
            return adminSkeletonCard(
              bone: bone,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  adminSkeletonBar(
                    bone: bone,
                    width: 36,
                    height: 36,
                    radius: 10,
                  ),
                  const Spacer(),
                  adminSkeletonBar(
                    bone: bone,
                    width: 64,
                    height: 18,
                    radius: 6,
                  ),
                  const SizedBox(height: 8),
                  adminSkeletonBar(
                    bone: bone,
                    width: 88,
                    height: 11,
                    radius: 4,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

/// Pending request / complaint list rows — matches [AdminPendingRequestTile].
class AdminPendingListSkeleton extends StatelessWidget {
  final int itemCount;

  const AdminPendingListSkeleton({super.key, this.itemCount = 2});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return Column(
          children: List.generate(itemCount, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 10),
              child: adminSkeletonCard(
                bone: bone,
                child: Row(
                  children: [
                    adminSkeletonBar(
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
                          adminSkeletonBar(bone: bone, width: 140, height: 14),
                          const SizedBox(height: 8),
                          adminSkeletonBar(bone: bone, width: 100, height: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    adminSkeletonBar(
                      bone: bone,
                      width: 44,
                      height: 22,
                      radius: AppSizes.radiusFull,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Finance tab body skeleton.
class AdminFinanceTabSkeleton extends StatelessWidget {
  const AdminFinanceTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        AdminHeroCardSkeleton(),
        SizedBox(height: 16),
        AdminDashboardStatsGridSkeleton(),
      ],
    );
  }
}

/// Finance detail info rows skeleton.
class AdminFinanceDetailSkeleton extends StatelessWidget {
  const AdminFinanceDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return adminSkeletonCard(
          bone: bone,
          child: Column(
            children: List.generate(3, (i) {
              return Column(
                children: [
                  if (i > 0) const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: adminSkeletonBar(
                          bone: bone,
                          width: 120,
                          height: 12,
                        ),
                      ),
                      adminSkeletonBar(bone: bone, width: 80, height: 12),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

/// Expandable halaqa roster — students tab.
class AdminStudentsRosterSkeleton extends StatelessWidget {
  final int itemCount;

  const AdminStudentsRosterSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: itemCount,
          itemBuilder: (_, __) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: adminSkeletonCard(
                bone: bone,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    adminSkeletonBar(
                      bone: bone,
                      width: 40,
                      height: 40,
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          adminSkeletonBar(bone: bone, width: 150, height: 14),
                          const SizedBox(height: 8),
                          adminSkeletonBar(bone: bone, width: 90, height: 10),
                        ],
                      ),
                    ),
                    adminSkeletonBar(bone: bone, width: 18, height: 18),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Teacher management cards.
class AdminTeachersListSkeleton extends StatelessWidget {
  final int itemCount;

  const AdminTeachersListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: itemCount,
          itemBuilder: (_, __) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: adminSkeletonCard(
                bone: bone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        adminSkeletonBar(
                          bone: bone,
                          width: 40,
                          height: 40,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              adminSkeletonBar(
                                bone: bone,
                                width: 130,
                                height: 14,
                              ),
                              const SizedBox(height: 6),
                              adminSkeletonBar(
                                bone: bone,
                                width: 70,
                                height: 10,
                              ),
                            ],
                          ),
                        ),
                        adminSkeletonBar(
                          bone: bone,
                          width: 48,
                          height: 22,
                          radius: AppSizes.radiusFull,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: adminSkeletonBar(
                            bone: bone,
                            height: 36,
                            radius: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: adminSkeletonBar(
                            bone: bone,
                            height: 36,
                            radius: 10,
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
      },
    );
  }
}

/// Teacher activity log bottom sheet.
class AdminActivityLogSkeleton extends StatelessWidget {
  const AdminActivityLogSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              adminSkeletonBar(bone: bone, width: 160, height: 16),
              const SizedBox(height: 16),
              ...List.generate(
                4,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: adminSkeletonCard(
                    bone: bone,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        adminSkeletonBar(bone: bone, width: 180, height: 12),
                        const SizedBox(height: 8),
                        adminSkeletonBar(bone: bone, width: 120, height: 10),
                      ],
                    ),
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

/// Registration requests full page.
class AdminRegistrationRequestsSkeleton extends StatelessWidget {
  const AdminRegistrationRequestsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        AdminHeroCardSkeleton(),
        SizedBox(height: 16),
        AdminPendingListSkeleton(itemCount: 3),
      ],
    );
  }
}

/// Chat inbox / conversation list rows.
class AdminChatInboxSkeleton extends StatelessWidget {
  final int itemCount;

  const AdminChatInboxSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 78,
            endIndent: 16,
            color: AppColors.border,
          ),
          itemBuilder: (_, __) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  adminSkeletonBar(
                    bone: bone,
                    width: 44,
                    height: 44,
                    radius: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        adminSkeletonBar(bone: bone, width: 140, height: 13),
                        const SizedBox(height: 8),
                        adminSkeletonBar(bone: bone, width: 200, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Communication hub chart + message preview section.
class AdminCommunicationSectionSkeleton extends StatelessWidget {
  const AdminCommunicationSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            adminSkeletonCard(
              bone: bone,
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: adminSkeletonBar(
                          bone: bone,
                          height: 40 + (i % 3) * 18.0,
                          radius: 8,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: adminSkeletonCard(
                  bone: bone,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            adminSkeletonBar(
                              bone: bone,
                              width: 120,
                              height: 13,
                            ),
                            const SizedBox(height: 8),
                            adminSkeletonBar(
                              bone: bone,
                              width: 180,
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

/// Bar chart only — communication analytics page.
class AdminBarChartSkeleton extends StatelessWidget {
  const AdminBarChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminCommunicationSectionSkeleton();
  }
}

/// Form fields — admit / settings pages.
class AdminFormSkeleton extends StatelessWidget {
  final int fieldCount;

  const AdminFormSkeleton({super.key, this.fieldCount = 4});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            adminSkeletonBar(bone: bone, width: double.infinity, height: 48),
            const SizedBox(height: 20),
            ...List.generate(fieldCount, (_) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    adminSkeletonBar(bone: bone, width: 80, height: 11),
                    const SizedBox(height: 8),
                    adminSkeletonBar(
                      bone: bone,
                      width: double.infinity,
                      height: 52,
                      radius: AppSizes.radiusM,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            adminSkeletonBar(
              bone: bone,
              width: double.infinity,
              height: 48,
              radius: AppSizes.radiusFull,
            ),
          ],
        );
      },
    );
  }
}

/// Communication settings toggles skeleton.
class AdminSettingsTogglesSkeleton extends StatelessWidget {
  const AdminSettingsTogglesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      builder: (context, bone) {
        return adminSkeletonCard(
          bone: bone,
          child: Column(
            children: List.generate(4, (i) {
              return Column(
                children: [
                  if (i > 0) const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: adminSkeletonBar(
                          bone: bone,
                          width: 180,
                          height: 12,
                        ),
                      ),
                      adminSkeletonBar(
                        bone: bone,
                        width: 44,
                        height: 24,
                        radius: 12,
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

/// Full-page centered flow (internal chat bootstrap).
class AdminFlowBootstrapSkeleton extends StatelessWidget {
  const AdminFlowBootstrapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: AdminChatInboxSkeleton(itemCount: 3),
    );
  }
}

/// Complaints list page skeleton.
class AdminComplaintsListSkeleton extends StatelessWidget {
  const AdminComplaintsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: AdminPendingListSkeleton(itemCount: 5),
    );
  }
}
