import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/complaint_entity.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

class AdminComplaintsReviewPage extends StatefulWidget {
  const AdminComplaintsReviewPage({super.key});

  @override
  State<AdminComplaintsReviewPage> createState() =>
      _AdminComplaintsReviewPageState();
}

class _AdminComplaintsReviewPageState extends State<AdminComplaintsReviewPage> {
  String _filter = 'all';

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

  String _priorityLabel(String priority) => switch (priority) {
    ComplaintPriorities.high => 'عالية',
    ComplaintPriorities.low => 'منخفضة',
    _ => 'عادية',
  };

  (Color, Color) _priorityColors(String priority) => switch (priority) {
    ComplaintPriorities.high => (AppColors.error, const Color(0xFFFFEBEE)),
    ComplaintPriorities.low => (AppColors.info, const Color(0xFFE3F2FD)),
    _ => (AppColors.warning, const Color(0xFFFFF8E1)),
  };

  List<ComplaintEntity> _filtered(List<ComplaintEntity> all) {
    return switch (_filter) {
      'high' =>
        all
            .where((c) => c.isOpen && c.priority == ComplaintPriorities.high)
            .toList(),
      'medium' =>
        all
            .where((c) => c.isOpen && c.priority == ComplaintPriorities.normal)
            .toList(),
      'resolved' =>
        all.where((c) => c.status == ComplaintStatuses.resolved).toList(),
      _ => all.where((c) => c.isOpen).toList(),
    };
  }

  int _priorityCount(List<ComplaintEntity> all, String priority) =>
      all.where((c) => c.isOpen && c.priority == priority).length;

  Future<void> _showAssignSheet(ComplaintEntity complaint) async {
    final state = context.read<AdminBloc>().state;
    final options = <({String id, String name, String role})>[
      for (final t in state.teachers)
        (id: t.uid, name: t.name, role: 'teacher'),
      for (final s in state.supervisorsDirectory)
        (id: s.uid, name: s.name, role: 'supervisor'),
    ];

    if (options.isEmpty) {
      AppSnackBar.showError(context, 'لا يوجد معلمون أو مشرفون للإسناد');
      return;
    }

    var selected = options.first;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إسناد الشكوى',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    complaint.subject,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<
                    ({String id, String name, String role})
                  >(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'المسؤول'),
                    items: options
                        .map(
                          (o) => DropdownMenuItem(
                            value: o,
                            child: Text('${o.name} (${o.role})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setSheetState(() => selected = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'إسناد',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || confirmed != true) return;

    context.read<AdminBloc>().add(
      UpdateComplaintEvent(
        complaintId: complaint.id,
        status: ComplaintStatuses.inProgress,
        assigneeId: selected.id,
        assigneeRole: selected.role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (p, c) => p.updateComplaintStatus != c.updateComplaintStatus,
      listener: (context, state) {
        if (state.updateComplaintStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم إسناد الشكوى');
          context.read<AdminBloc>().add(const ResetUpdateComplaintEvent());
        } else if (state.updateComplaintStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.updateComplaintError ?? 'تعذر الإسناد',
          );
          context.read<AdminBloc>().add(const ResetUpdateComplaintEvent());
        }
      },
      child: AdminSubpageScaffold(
        title: 'مراجعة الشكاوى',
        body: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            final pending = state.complaints.where((c) => c.isOpen).length;
            final resolved = state.complaints
                .where((c) => c.status == ComplaintStatuses.resolved)
                .length;
            final highCount = _priorityCount(
              state.complaints,
              ComplaintPriorities.high,
            );
            final normalCount = _priorityCount(
              state.complaints,
              ComplaintPriorities.normal,
            );
            final filtered = _filtered(state.complaints);
            final assigning =
                state.updateComplaintStatus == SubmissionStatus.submitting;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$pending شكاوى معلقة',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          label: 'عالية',
                          count: highCount,
                          color: AppColors.error,
                          bg: const Color(0xFFFFEBEE),
                          icon: Icons.flag_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KpiCard(
                          label: 'عادية',
                          count: normalCount,
                          color: AppColors.warning,
                          bg: const Color(0xFFFFF8E1),
                          icon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KpiCard(
                          label: 'محلولة',
                          count: resolved,
                          color: AppColors.success,
                          bg: AppColors.successBg,
                          icon: Icons.check_circle_outline,
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
                        label: 'عالية',
                        selected: _filter == 'high',
                        onTap: () => setState(() => _filter = 'high'),
                      ),
                      AdminFilterChip(
                        label: 'عادية',
                        selected: _filter == 'medium',
                        onTap: () => setState(() => _filter = 'medium'),
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
                      : filtered.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: AdminPlaceholderCard(
                              icon: Icons.inbox_outlined,
                              title: 'لا شكاوى',
                              message: 'لا توجد شكاوى مطابقة للفلتر المحدد.',
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final isResolved = !c.isOpen;
                            final priorityLabel = _priorityLabel(c.priority);
                            final (pColor, pBg) = _priorityColors(c.priority);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        AdminStatusBadge(
                                          label: priorityLabel,
                                          color: pColor,
                                          bg: pBg,
                                        ),
                                        const SizedBox(width: 6),
                                        if (isResolved)
                                          const AdminStatusBadge(
                                            label: 'محلولة',
                                            color: AppColors.success,
                                            bg: AppColors.successBg,
                                          ),
                                        const Spacer(),
                                        Text(
                                          'مقدم من: ${c.senderRole}',
                                          style: AppTextStyles.labelSmall,
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
                                    const SizedBox(height: 4),
                                    Text(
                                      c.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => context.push(
                                              AppRoutes.adminComplaints,
                                            ),
                                            child: const Text('مركز الشكاوى'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: isResolved || assigning
                                                ? null
                                                : () => _showAssignSheet(c),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('إسناد ومتابعة'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
