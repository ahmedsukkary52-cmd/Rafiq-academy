import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../../domain/entities/admin_payment_entity.dart';
import '../admin_format.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_loading_skeletons.dart';
import '../widgets/admin_subpage_scaffold.dart';

/// Read-only review of existing `payments` documents (no new payment system).
class AdminPaymentsReviewPage extends StatefulWidget {
  const AdminPaymentsReviewPage({super.key});

  @override
  State<AdminPaymentsReviewPage> createState() =>
      _AdminPaymentsReviewPageState();
}

class _AdminPaymentsReviewPageState extends State<AdminPaymentsReviewPage> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadPaymentsEvent());
    });
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const LoadPaymentsEvent());
    await bloc.stream.firstWhere(
      (s) => s.paymentsStatus != SectionStatus.loading,
    );
  }

  List<AdminPaymentEntity> _filtered(List<AdminPaymentEntity> all) {
    return switch (_filter) {
      'paid' => all.where((p) => p.isPaid).toList(),
      'due' => all.where((p) => p.isDue).toList(),
      'overdue' => all.where((p) => p.isOverdue).toList(),
      _ => all,
    };
  }

  String _statusLabel(AdminPaymentEntity p) {
    if (p.isPaid) return 'مدفوع';
    if (p.isOverdue) return 'متأخر';
    return 'مستحق';
  }

  Color _statusColor(AdminPaymentEntity p) {
    if (p.isPaid) return AppColors.success;
    if (p.isOverdue) return AppColors.error;
    return AppColors.warning;
  }

  String _shortId(String id) {
    if (id.isEmpty) return '—';
    if (id.length <= 10) return id;
    return '${id.substring(0, 6)}…';
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'مراجعة المدفوعات',
      subtitle: 'قراءة من مجموعة payments الحالية',
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (p, c) =>
            p.paymentsStatus != c.paymentsStatus || p.payments != c.payments,
        builder: (context, state) {
          if (state.paymentsStatus == SectionStatus.loading &&
              state.payments.isEmpty) {
            return const AdminTeachersListSkeleton();
          }
          if (state.paymentsStatus == SectionStatus.error &&
              state.payments.isEmpty) {
            return AppErrorWidget(
              message: state.paymentsError ?? 'تعذر التحميل',
              onRetry: _refresh,
            );
          }

          final items = _filtered(state.payments);
          if (state.payments.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  AdminPlaceholderCard(
                    icon: Icons.payments_outlined,
                    title: 'لا مدفوعات',
                    message: 'لا توجد سجلات في مجموعة المدفوعات حالياً.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const [
                      ('all', 'الكل'),
                      ('paid', 'مدفوع'),
                      ('due', 'مستحق'),
                      ('overdue', 'متأخر'),
                    ])
                      AdminFilterChip(
                        label: entry.$2,
                        selected: _filter == entry.$1,
                        onTap: () => setState(() => _filter = entry.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${formatAdminCount(items.length)} سجل',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  const AdminPlaceholderCard(
                    icon: Icons.filter_alt_outlined,
                    title: 'لا نتائج',
                    message: 'لا توجد مدفوعات ضمن هذا التصفية.',
                  )
                else
                  ...items.map((p) {
                    final color = _statusColor(p);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${formatAdminCount(p.amount.round())} ر.س',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    _statusLabel(p),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'طالب: ${_shortId(p.studentId)} · ولي أمر: ${_shortId(p.parentId)}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.isPaid
                                  ? 'تاريخ الدفع: ${_dateLabel(p.paidAt)}'
                                  : 'الاستحقاق: ${_dateLabel(p.dueDate)}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            if (p.method != null && p.method!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'الطريقة: ${p.method}',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Academy-wide supervisors directory (read-only).
class AdminSupervisorsPage extends StatefulWidget {
  const AdminSupervisorsPage({super.key});

  @override
  State<AdminSupervisorsPage> createState() => _AdminSupervisorsPageState();
}

class _AdminSupervisorsPageState extends State<AdminSupervisorsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadAdminDirectoryEvent());
    });
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const LoadAdminDirectoryEvent());
    await bloc.stream.firstWhere(
      (s) => s.directoryStatus != SectionStatus.loading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'المشرفون',
      subtitle: 'دليل مشرفي الأكاديمية',
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (p, c) =>
            p.directoryStatus != c.directoryStatus ||
            p.supervisorsDirectory != c.supervisorsDirectory,
        builder: (context, state) {
          if (state.directoryStatus == SectionStatus.loading &&
              state.supervisorsDirectory.isEmpty) {
            return const AdminTeachersListSkeleton();
          }
          if (state.directoryStatus == SectionStatus.error &&
              state.supervisorsDirectory.isEmpty) {
            return AppErrorWidget(
              message: state.directoryError ?? 'تعذر التحميل',
              onRetry: _refresh,
            );
          }

          final list = state.supervisorsDirectory;
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  AdminPlaceholderCard(
                    icon: Icons.supervisor_account_outlined,
                    title: 'لا مشرفين',
                    message: 'لم يُعثر على حسابات مشرفين مسجّلة.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _StaffTile(
                  staff: list[index],
                  icon: Icons.supervisor_account,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Academy-wide halaqat directory (read-only).
class AdminHalaqatPage extends StatefulWidget {
  const AdminHalaqatPage({super.key});

  @override
  State<AdminHalaqatPage> createState() => _AdminHalaqatPageState();
}

class _AdminHalaqatPageState extends State<AdminHalaqatPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadAdminDirectoryEvent());
    });
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const LoadAdminDirectoryEvent());
    await bloc.stream.firstWhere(
      (s) => s.directoryStatus != SectionStatus.loading,
    );
  }

  String _shortId(String id) {
    if (id.isEmpty) return '—';
    if (id.length <= 10) return id;
    return '${id.substring(0, 6)}…';
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'الحلقات',
      subtitle: 'دليل حلقات الأكاديمية',
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (p, c) =>
            p.directoryStatus != c.directoryStatus ||
            p.halaqatDirectory != c.halaqatDirectory,
        builder: (context, state) {
          if (state.directoryStatus == SectionStatus.loading &&
              state.halaqatDirectory.isEmpty) {
            return const AdminTeachersListSkeleton();
          }
          if (state.directoryStatus == SectionStatus.error &&
              state.halaqatDirectory.isEmpty) {
            return AppErrorWidget(
              message: state.directoryError ?? 'تعذر التحميل',
              onRetry: _refresh,
            );
          }

          final list = state.halaqatDirectory;
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  AdminPlaceholderCard(
                    icon: Icons.groups_outlined,
                    title: 'لا حلقات',
                    message: 'لم يُعثر على حلقات مسجّلة في الأكاديمية.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final h = list[index];
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              h.name.isEmpty ? 'حلقة بدون اسم' : h.name,
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${formatAdminCount(h.studentCount)} طالب',
                            style: AppTextStyles.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'معلم: ${_shortId(h.teacherId)} · مشرف: ${_shortId(h.supervisorId)}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final AdminStaffSummaryEntity staff;
  final IconData icon;

  const _StaffTile({required this.staff, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name.isEmpty ? 'بدون اسم' : staff.name,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  staff.uid.length <= 12
                      ? staff.uid
                      : '${staff.uid.substring(0, 8)}…',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
