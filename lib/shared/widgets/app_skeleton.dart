import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared pulse controller for skeleton bones.
class AppSkeletonPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color bone) builder;

  const AppSkeletonPulse({super.key, required this.builder});

  @override
  State<AppSkeletonPulse> createState() => _AppSkeletonPulseState();
}

class _AppSkeletonPulseState extends State<AppSkeletonPulse>
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

/// Rectangular skeleton bone.
class AppSkeletonBox extends StatelessWidget {
  final Color bone;
  final double? width;
  final double height;
  final double radius;

  const AppSkeletonBox({
    super.key,
    required this.bone,
    this.width,
    required this.height,
    this.radius = AppSizes.radiusS,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bone,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Line alias of [AppSkeletonBox] for readability.
class AppSkeletonLine extends StatelessWidget {
  final Color bone;
  final double? width;
  final double height;
  final double radius;

  const AppSkeletonLine({
    super.key,
    required this.bone,
    this.width,
    this.height = 12,
    this.radius = AppSizes.radiusS,
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeletonBox(
      bone: bone,
      width: width,
      height: height,
      radius: radius,
    );
  }
}

/// Circular skeleton bone (avatars).
class AppSkeletonCircle extends StatelessWidget {
  final Color bone;
  final double size;

  const AppSkeletonCircle({super.key, required this.bone, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bone, shape: BoxShape.circle),
    );
  }
}
