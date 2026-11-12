import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/time_format.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../domain/complaint.dart';

/// Who is looking at the complaints screens.
class ComplaintViewer {
  const ComplaintViewer({required this.uid, required this.role});

  final String uid;
  final String role;

  bool get isAdmin => role == 'admin';

  /// Students do not file complaints (product decision).
  bool get canSubmit =>
      role == 'parent' || role == 'teacher' || role == 'supervisor';
}

AppStatusTone complaintStatusTone(ComplaintStatus s) => switch (s) {
  ComplaintStatus.open => AppStatusTone.warning,
  ComplaintStatus.inProgress => AppStatusTone.info,
  ComplaintStatus.resolved => AppStatusTone.success,
  ComplaintStatus.archived => AppStatusTone.neutral,
};

class ComplaintStatusChip extends StatelessWidget {
  const ComplaintStatusChip(this.status, {super.key});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) =>
      AppStatusChip(label: status.label, tone: complaintStatusTone(status));
}

String complaintDateLabel(DateTime d) =>
    '${formatDateDmy(d)} · ${formatTimeHm12Ar(d)}';

class ComplaintCard extends StatelessWidget {
  const ComplaintCard({
    super.key,
    required this.complaint,
    required this.showSender,
    required this.onTap,
  });

  final Complaint complaint;
  final bool showSender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    final sender = c.senderName.isEmpty
        ? complaintSenderRoleLabel(c.senderRole)
        : '${c.senderName} · ${complaintSenderRoleLabel(c.senderRole)}';
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ComplaintStatusChip(c.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  complaintDateLabel(c.createdAt),
                  textAlign: TextAlign.left,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            c.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (showSender || c.contextLine.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (showSender)
                  _Meta(icon: Icons.person_outline_rounded, text: sender),
                if (c.contextLine.isNotEmpty)
                  _Meta(icon: Icons.groups_2_outlined, text: c.contextLine),
                if (c.historyCount > 0)
                  _Meta(
                    icon: Icons.forum_outlined,
                    text: '${c.historyCount} تحديث',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
