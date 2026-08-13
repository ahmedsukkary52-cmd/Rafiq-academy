import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/time_format.dart';
import '../../widgets/shared_widgets.dart';
import 'halaqa_activity_ui_models.dart';

/// Conversation-like bubble for activity threads (teacher + student).
class ActivityThreadBubble extends StatelessWidget {
  final ActivityThreadMessageUi message;

  const ActivityThreadBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final accent = _avatarColor(message.authorId);
    return AppCard(
      color: message.isTeacher
          ? AppColors.primary.withValues(alpha: 0.04)
          : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                formatTimeHm12Ar(message.createdAt),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.authorName,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (message.isTeacher)
                    Text(
                      'المعلم',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              UserAvatar(
                name: message.authorName,
                size: AppSizes.avatarS,
                backgroundColor: accent,
              ),
            ],
          ),
          if (message.text != null && message.text!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message.text!,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
            ),
          ],
          if (message.hasImage) ...[
            const SizedBox(height: 10),
            _AttachmentTile(
              icon: Icons.image_outlined,
              label: message.imageLabel ?? 'صورة مرفقة',
              color: AppColors.success,
            ),
          ],
          if (message.hasAudio) ...[
            const SizedBox(height: 10),
            _AttachmentTile(
              icon: Icons.play_circle_outline_rounded,
              label: message.audioLabel ?? 'مقطع صوتي',
              color: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  Color _avatarColor(String id) {
    const palette = [
      AppColors.primary,
      AppColors.gradeExcellent,
      AppColors.gradeGood,
      AppColors.secondary,
      AppColors.gradeVeryGood,
    ];
    final hash = id.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }
}

class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
