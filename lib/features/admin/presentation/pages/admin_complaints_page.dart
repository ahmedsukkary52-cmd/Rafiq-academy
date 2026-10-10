import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/admin_complaint_response_form.dart';
import '../../domain/entities/complaint_entity.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

class AdminComplaintsPage extends StatefulWidget {
  const AdminComplaintsPage({super.key});

  @override
  State<AdminComplaintsPage> createState() => _AdminComplaintsPageState();
}

class _AdminComplaintsPageState extends State<AdminComplaintsPage> {
  String _filter = 'all';
  ComplaintEntity? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AdminBloc>();
      bloc.add(const LoadComplaintsEvent());
      bloc.add(const LoadAdminDirectoryEvent());
      if (bloc.state.teachersStatus != SectionStatus.loaded) {
        bloc.add(const LoadAllTeachersEvent());
      }
    });
  }

  String _assigneeName(AdminState state, String? assigneeId) {
    if (assigneeId == null || assigneeId.isEmpty) return '';
    for (final t in state.teachers) {
      if (t.uid == assigneeId) return t.name;
    }
    for (final s in state.supervisorsDirectory) {
      if (s.uid == assigneeId) return s.name;
    }
    return assigneeId;
  }

  List<ComplaintEntity> _filtered(List<ComplaintEntity> all) {
    return switch (_filter) {
      'open' => all.where((c) => c.isOpen).toList(),
      'resolved' =>
        all.where((c) => c.status == ComplaintStatuses.resolved).toList(),
      _ => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (p, c) =>
          p.respondComplaintStatus != c.respondComplaintStatus ||
          p.updateComplaintStatus != c.updateComplaintStatus,
      listener: (context, state) {
        if (state.respondComplaintStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم إرسال الرد');
          context.read<AdminBloc>().add(const ResetRespondComplaintEvent());
          setState(() => _selected = null);
        } else if (state.respondComplaintStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.respondComplaintError ?? 'تعذر إرسال الرد',
          );
          context.read<AdminBloc>().add(const ResetRespondComplaintEvent());
        } else if (state.updateComplaintStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم تحديث الشكوى');
          context.read<AdminBloc>().add(const ResetUpdateComplaintEvent());
        } else if (state.updateComplaintStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.updateComplaintError ?? 'تعذر التحديث',
          );
          context.read<AdminBloc>().add(const ResetUpdateComplaintEvent());
        }
      },
      child: AdminSubpageScaffold(
        title: 'مركز الدعم والشكاوى',
        subtitle: null,
        body: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            final openCount = state.complaints.where((c) => c.isOpen).length;
            final resolvedCount = state.complaints
                .where((c) => c.status == ComplaintStatuses.resolved)
                .length;
            final filtered = _filtered(state.complaints);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$openCount تذكرة مفتوحة',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SupportKpiCard(
                          label: 'مفتوحة',
                          count: openCount,
                          icon: Icons.inbox_outlined,
                          color: AppColors.warning,
                          bg: const Color(0xFFFFF3E0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SupportKpiCard(
                          label: 'قيد المعالجة',
                          count: state.complaints
                              .where(
                                (c) =>
                                    c.status != 'resolved' &&
                                    (c.response?.isNotEmpty ?? false),
                              )
                              .length,
                          icon: Icons.schedule_rounded,
                          color: AppColors.info,
                          bg: const Color(0xFFE3F2FD),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SupportKpiCard(
                          label: 'محلولة',
                          count: resolvedCount,
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          bg: AppColors.successBg,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      AdminFilterChip(
                        label: 'الكل',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      AdminFilterChip(
                        label: 'مفتوحة',
                        selected: _filter == 'open',
                        onTap: () => setState(() => _filter = 'open'),
                      ),
                      AdminFilterChip(
                        label: 'محلولة',
                        selected: _filter == 'resolved',
                        onTap: () => setState(() => _filter = 'resolved'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: state.complaintsStatus == SectionStatus.loading
                      ? const AdminComplaintsListSkeleton()
                      : state.complaintsStatus == SectionStatus.error
                      ? AppErrorWidget(
                          message: state.complaintsError ?? 'تعذر التحميل',
                          onRetry: () => context.read<AdminBloc>().add(
                            const LoadComplaintsEvent(),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ComplaintCard(
                                complaint: c,
                                selected: _selected?.id == c.id,
                                assigneeName: _assigneeName(
                                  state,
                                  c.assigneeId,
                                ),
                                onTap: () => setState(() => _selected = c),
                              ),
                            );
                          },
                        ),
                ),
                if (_selected != null)
                  _RespondPanel(
                    complaint: _selected!,
                    submitting:
                        state.respondComplaintStatus ==
                            SubmissionStatus.submitting ||
                        state.updateComplaintStatus ==
                            SubmissionStatus.submitting,
                    assigneeOptions: [
                      ...state.teachers.map(
                        (t) => (id: t.uid, name: t.name, role: 'teacher'),
                      ),
                      ...state.supervisorsDirectory.map(
                        (s) => (id: s.uid, name: s.name, role: 'supervisor'),
                      ),
                    ],
                    onRespond: (text) {
                      context.read<AdminBloc>().add(
                        RespondToComplaintEvent(
                          complaintId: _selected!.id,
                          response: text,
                        ),
                      );
                    },
                    onArchive: () {
                      context.read<AdminBloc>().add(
                        UpdateComplaintEvent(
                          complaintId: _selected!.id,
                          status: ComplaintStatuses.archived,
                        ),
                      );
                      setState(() => _selected = null);
                    },
                    onPriorityChanged: (priority) {
                      context.read<AdminBloc>().add(
                        UpdateComplaintEvent(
                          complaintId: _selected!.id,
                          priority: priority,
                          status: ComplaintStatuses.inProgress,
                        ),
                      );
                    },
                    onAssigneeChanged: (id, role) {
                      context.read<AdminBloc>().add(
                        UpdateComplaintEvent(
                          complaintId: _selected!.id,
                          assigneeId: id,
                          assigneeRole: role,
                          status: ComplaintStatuses.inProgress,
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SupportKpiCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final Color bg;

  const _SupportKpiCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final ComplaintEntity complaint;
  final bool selected;
  final String assigneeName;
  final VoidCallback onTap;

  const _ComplaintCard({
    required this.complaint,
    required this.selected,
    required this.assigneeName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${complaint.createdAt.day}/${complaint.createdAt.month}/${complaint.createdAt.year}';
    final isResolved = complaint.status == ComplaintStatuses.resolved;
    final priorityLabel = switch (complaint.priority) {
      ComplaintPriorities.high => 'عالية',
      ComplaintPriorities.low => 'منخفضة',
      _ => 'عادية',
    };

    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.primaryLight : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priorityLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isResolved ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isResolved ? 'محلولة' : 'مفتوحة',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isResolved ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complaint.subject,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            complaint.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (assigneeName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'المسؤول: $assigneeName',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (complaint.response != null) ...[
            const SizedBox(height: 8),
            Text(
              'الرد: ${complaint.response}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RespondPanel extends StatefulWidget {
  final ComplaintEntity complaint;
  final bool submitting;
  final List<({String id, String name, String role})> assigneeOptions;
  final ValueChanged<String> onRespond;
  final VoidCallback onArchive;
  final ValueChanged<String> onPriorityChanged;
  final void Function(String id, String role) onAssigneeChanged;

  const _RespondPanel({
    required this.complaint,
    required this.submitting,
    required this.assigneeOptions,
    required this.onRespond,
    required this.onArchive,
    required this.onPriorityChanged,
    required this.onAssigneeChanged,
  });

  @override
  State<_RespondPanel> createState() => _RespondPanelState();
}

class _RespondPanelState extends State<_RespondPanel> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final err = AdminComplaintResponseFormValidation.error(
      response: _ctrl.text,
    );
    setState(() => _error = err);
    if (err != null) return;
    widget.onRespond(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.complaint.status == ComplaintStatuses.resolved ||
        widget.complaint.status == ComplaintStatuses.archived) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'تذكرة — ${widget.complaint.subject}',
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: widget.complaint.priority,
            decoration: const InputDecoration(labelText: 'الأولوية'),
            items: const [
              DropdownMenuItem(
                value: ComplaintPriorities.low,
                child: Text('منخفضة'),
              ),
              DropdownMenuItem(
                value: ComplaintPriorities.normal,
                child: Text('عادية'),
              ),
              DropdownMenuItem(
                value: ComplaintPriorities.high,
                child: Text('عالية'),
              ),
            ],
            onChanged: widget.submitting
                ? null
                : (v) {
                    if (v != null) widget.onPriorityChanged(v);
                  },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: widget.complaint.assigneeId?.isNotEmpty == true
                ? widget.complaint.assigneeId
                : null,
            decoration: const InputDecoration(labelText: 'المسؤول'),
            items: widget.assigneeOptions
                .map((o) => DropdownMenuItem(value: o.id, child: Text(o.name)))
                .toList(),
            onChanged: widget.submitting
                ? null
                : (v) {
                    if (v == null) return;
                    final opt = widget.assigneeOptions.firstWhere(
                      (o) => o.id == v,
                    );
                    widget.onAssigneeChanged(opt.id, opt.role);
                  },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            enabled: !widget.submitting,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'اكتب ردك هنا…',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.submitting ? null : widget.onArchive,
                  child: const Text('أرشفة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'إرسال الرد',
                  isLoading: widget.submitting,
                  height: 48,
                  onPressed: _send,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
