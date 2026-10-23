import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../data/award_grant_errors.dart';

/// Shown while an award request's outcome is unknown: the form is locked to
/// the pinned request until it is retried or explicitly abandoned.
class UnresolvedAwardPanel extends StatelessWidget {
  const UnresolvedAwardPanel({
    super.key,
    required this.summary,
    required this.onAbandon,
    this.enabled = true,
    this.blockedReason,
  });

  /// What was sent, e.g. the title and recipient count.
  final String summary;
  final VoidCallback onAbandon;
  final bool enabled;

  /// Why the request cannot be resent; abandoning is then the only way on.
  final String? blockedReason;

  Future<void> _confirmAbandon(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تجاهل الطلب غير المؤكد؟'),
        content: const Text(kAwardGrantAbandonWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رجوع'),
          ),
          TextButton(
            key: const Key('award-abandon-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تجاهل والبدء من جديد'),
          ),
        ],
      ),
    );
    if (confirmed == true) onAbandon();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('award-unresolved-panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kAwardGrantPendingNotice, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 6),
          Text(
            summary,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (blockedReason != null) ...[
            const SizedBox(height: 6),
            Text(
              blockedReason!,
              key: const Key('award-unresolved-blocked'),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('award-abandon'),
              onPressed: enabled ? () => _confirmAbandon(context) : null,
              child: const Text('تجاهل هذا الطلب'),
            ),
          ),
        ],
      ),
    );
  }
}
