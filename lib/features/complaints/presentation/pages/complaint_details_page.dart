import 'package:flutter/material.dart';

import '../../../../core/error/user_facing_error.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/complaints_repository.dart';
import '../../domain/complaint.dart';
import '../complaint_widgets.dart';

/// Complaint thread: original message, every reply / status change, and a
/// composer. Admin can also change the status; the complainant can only
/// reply (a reply reopens a resolved complaint on the server).
class ComplaintDetailsPage extends StatefulWidget {
  const ComplaintDetailsPage({
    super.key,
    required this.complaintId,
    required this.viewer,
    required this.repository,
  });

  final String complaintId;
  final ComplaintViewer viewer;
  final ComplaintsRepository repository;

  @override
  State<ComplaintDetailsPage> createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage> {
  final _reply = TextEditingController();
  late final Stream<Complaint?> _complaint;
  late final Stream<List<ComplaintHistoryEntry>> _history;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _complaint = widget.repository.watchComplaint(widget.complaintId);
    _history = widget.repository.watchHistory(widget.complaintId);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send({ComplaintStatus? status}) async {
    final text = _reply.text.trim();
    if (text.isEmpty && status == null) {
      AppSnackBar.showError(context, 'اكتب رداً أولاً');
      return;
    }
    if (text.length > ComplaintFormValidation.messageMax) {
      AppSnackBar.showError(context, 'الرد أطول من المسموح');
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.repository.respond(
        complaintId: widget.complaintId,
        message: text,
        status: status,
      );
      if (!mounted) return;
      _reply.clear();
      AppSnackBar.showSuccess(
        context,
        status == null ? 'تم إرسال الرد' : 'تم تحديث حالة الشكوى',
      );
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFacingErrorText('$e'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppSubpageScaffold(
        title: 'تفاصيل الشكوى',
        body: StreamBuilder<Complaint?>(
          stream: _complaint,
          builder: (context, snap) {
            if (snap.hasError) {
              return AppErrorWidget(message: '${snap.error}');
            }
            if (!snap.hasData) {
              return snap.connectionState == ConnectionState.active
                  ? const AppErrorWidget(message: 'الشكوى غير موجودة')
                  : const AppLoadingWidget();
            }
            final c = snap.data!;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _Header(complaint: c, showSender: widget.viewer.isAdmin),
                      const SizedBox(height: 12),
                      _Bubble(
                        author: c.senderName.isEmpty
                            ? complaintSenderRoleLabel(c.senderRole)
                            : c.senderName,
                        text: c.message,
                        at: c.createdAt,
                        fromAdmin: false,
                      ),
                      if (c.legacyResponse != null)
                        _Bubble(
                          author: 'الإدارة',
                          text: c.legacyResponse!,
                          at: c.updatedAt,
                          fromAdmin: true,
                        ),
                      StreamBuilder<List<ComplaintHistoryEntry>>(
                        stream: _history,
                        builder: (context, h) {
                          if (h.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                userFacingErrorText('${h.error}'),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            );
                          }
                          final entries = h.data ?? const [];
                          return Column(
                            children: [
                              for (final e in entries) ...[
                                if (e.changedStatus)
                                  _StatusChange(entry: e),
                                if (e.message.isNotEmpty)
                                  _Bubble(
                                    author: e.isAdmin
                                        ? 'الإدارة'
                                        : (e.authorName.isEmpty
                                              ? complaintSenderRoleLabel(
                                                  e.authorRole,
                                                )
                                              : e.authorName),
                                    text: e.message,
                                    at: e.createdAt,
                                    fromAdmin: e.isAdmin,
                                  ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _Composer(
                  controller: _reply,
                  sending: _sending,
                  isAdmin: widget.viewer.isAdmin,
                  status: c.status,
                  onSend: () => _send(),
                  onStatus: (s) => _send(status: s),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.complaint, required this.showSender});

  final Complaint complaint;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ComplaintStatusChip(c.status),
              const Spacer(),
              Text(
                complaintDateLabel(c.createdAt),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            c.subject,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (showSender) ...[
            const SizedBox(height: 6),
            Text(
              'المرسل: ${c.senderName.isEmpty ? '—' : c.senderName} (${complaintSenderRoleLabel(c.senderRole)})',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (c.contextLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              c.contextLine,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.author,
    required this.text,
    required this.at,
    required this.fromAdmin,
  });

  final String author;
  final String text;
  final DateTime? at;
  final bool fromAdmin;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromAdmin
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fromAdmin ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fromAdmin ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(text, style: AppTextStyles.bodyMedium),
              if (at != null) ...[
                const SizedBox(height: 4),
                Text(
                  complaintDateLabel(at!),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChange extends StatelessWidget {
  const _StatusChange({required this.entry});

  final ComplaintHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Text(
          'تغيّرت الحالة من «${entry.statusFrom.label}» إلى «${entry.statusTo.label}»',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.isAdmin,
    required this.status,
    required this.onSend,
    required this.onStatus,
  });

  final TextEditingController controller;
  final bool sending;
  final bool isAdmin;
  final ComplaintStatus status;
  final VoidCallback onSend;
  final ValueChanged<ComplaintStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ComplaintStatus.values)
                    if (s != status)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: OutlinedButton(
                          key: Key('complaint-status-${s.wire}'),
                          onPressed: sending ? null : () => onStatus(s),
                          child: Text(
                            s == ComplaintStatus.open
                                ? 'إعادة فتح'
                                : 'تحويل إلى: ${s.label}',
                          ),
                        ),
                      ),
                ],
              ),
            ),
          if (isAdmin) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('complaint-reply-field'),
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: ComplaintFormValidation.messageMax,
                  decoration: const InputDecoration(
                    hintText: 'اكتب رداً…',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('complaint-reply-send'),
                onPressed: sending ? null : onSend,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
