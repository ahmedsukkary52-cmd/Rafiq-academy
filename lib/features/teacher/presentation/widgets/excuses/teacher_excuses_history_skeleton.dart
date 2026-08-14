import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_theme.dart';

/// Skeleton that preserves the Figma history-card layout while loading.
class TeacherExcusesHistorySkeleton extends StatefulWidget {
  final int itemCount;

  const TeacherExcusesHistorySkeleton({super.key, this.itemCount = 3});

  @override
  State<TeacherExcusesHistorySkeleton> createState() =>
      _TeacherExcusesHistorySkeletonState();
}

class _TeacherExcusesHistorySkeletonState
    extends State<TeacherExcusesHistorySkeleton>
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
      begin: 0.45,
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
        return Column(
          children: [
            for (var i = 0; i < widget.itemCount; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _SkeletonCard(opacity: _pulse.value),
            ],
          ],
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double opacity;

  const _SkeletonCard({required this.opacity});

  @override
  Widget build(BuildContext context) {
    final bone = AppColors.border.withValues(alpha: opacity);

    Widget bar({required double width, required double height}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bone,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  bar(width: 140, height: 12),
                  const SizedBox(height: 8),
                  bar(width: 96, height: 10),
                ],
              ),
              const Spacer(),
              Container(
                width: 64,
                height: 22,
                decoration: BoxDecoration(
                  color: bone,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: bar(width: double.infinity, height: 10),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: bar(width: 180, height: 10),
          ),
        ],
      ),
    );
  }
}
