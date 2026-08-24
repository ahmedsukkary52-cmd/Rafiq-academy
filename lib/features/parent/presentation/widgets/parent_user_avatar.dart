import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

/// Image-or-initial avatar for Parent UI (upload/edit is deferred).
class ParentUserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  const ParentUserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.backgroundColor = AppColors.secondaryBg,
    this.foregroundColor = AppColors.secondary,
  });

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '؟';
    return String.fromCharCodes(trimmed.runes.take(1));
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              _initial,
              style: AppTextStyles.titleLarge.copyWith(
                color: foregroundColor,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );
  }
}
