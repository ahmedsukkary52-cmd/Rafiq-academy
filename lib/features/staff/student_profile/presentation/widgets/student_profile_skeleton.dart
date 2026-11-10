import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/app_skeleton.dart';

/// Staff Student Profile page body while loading.
class StudentProfileSkeleton extends StatelessWidget {
  const StudentProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
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
                    _bar(bone: bone, width: 160, height: 16),
                    const SizedBox(height: 8),
                    _bar(bone: bone, width: 120, height: 12),
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
                    child: _card(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            Expanded(
                              child: Column(
                                children: [
                                  _bar(bone: bone, width: 40, height: 20),
                                  const SizedBox(height: 6),
                                  _bar(bone: bone, width: 56, height: 10),
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
                        child: _bar(
                          bone: bone,
                          height: 48,
                          radius: AppSizes.radiusL,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _bar(
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
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(bone: bone, width: 120, height: 14),
                          const SizedBox(height: 14),
                          _bar(bone: bone, height: 12),
                          const SizedBox(height: 10),
                          _bar(bone: bone, width: 180, height: 12),
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

Widget _bar({
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

Widget _card({
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
