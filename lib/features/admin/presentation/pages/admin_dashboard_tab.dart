import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/academy_data_revision.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/presentation/academy_currency_label.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../complaints/presentation/complaints_entry.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../domain/entities/complaint_entity.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../admin_format.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_loading_skeletons.dart';

/// Figma: لوحة المدير — executive dashboard wired to AdminBloc.
class AdminDashboardTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const AdminDashboardTab({super.key, this.onSwitchTab});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  @override
  void initState() {
    super.initState();
    AcademyDataRevision.structure.addListener(_onStructureChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const RefreshAdminDashboardEvent());
    });
  }

  @override
  void dispose() {
    AcademyDataRevision.structure.removeListener(_onStructureChanged);
    super.dispose();
  }

  void _onStructureChanged() {
    if (mounted) {
      context.read<AdminBloc>().add(const RefreshAdminDashboardEvent());
    }
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const RefreshAdminDashboardEvent());
    await bloc.stream.firstWhere(
      (s) =>
          s.statsStatus != SectionStatus.loading &&
          s.financialStatus != SectionStatus.loading &&
          s.complaintsStatus != SectionStatus.loading &&
          s.registrationStatus != SectionStatus.loading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final adminName = auth is AuthAuthenticated ? auth.user.name : '';
    final adminImage = auth is AuthAuthenticated
        ? auth.user.profileImageUrl
        : null;
    final displayName = adminName.trim().isEmpty ? 'المدير' : adminName.trim();

    final unreadCount = context.watch<NotificationsBloc>().state.unreadCount;

    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        final stats = state.stats;
        final finance = state.financialSummary;
        final pendingRequests = state.registrationRequests;
        final openComplaints = state.complaints
            .where((c) => isOpenComplaintStatus(c.status))
            .toList();
        final loading =
            state.statsStatus == SectionStatus.loading ||
            state.financialStatus == SectionStatus.loading ||
            state.registrationStatus == SectionStatus.loading;
        final fmt = formatAdminCount;
        final health = adminDashboardHealth(state, loading: loading);

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                        child: SizedBox(height: 340),
                      ),
                    ),
                    Column(
                      children: [
                        AdminRoleHomeHeader(
                          displayName: displayName,
                          imageUrl: adminImage,
                          unreadNotifications: unreadCount,
                          onSearchTap: widget.onSwitchTab == null
                              ? null
                              : () => widget.onSwitchTab!(1),
                          onNotificationsTap: () =>
                              context.push(AppRoutes.adminNotifications),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: loading && stats == null
                              ? const AdminHeroCardSkeleton()
                              : AdminGradientHeroCard(
                                  key: Key('admin-health-${health.level.name}'),
                                  eyebrow: health.detail,
                                  headline: health.headline,
                                  statusIcon: health.icon,
                                  centered: true,
                                  metrics: [
                                    AdminHeroMetric(
                                      value: loading
                                          ? '…'
                                          : fmt(stats?.totalHalaqat),
                                      label: 'حلقة نشطة',
                                    ),
                                    AdminHeroMetric(
                                      value: loading
                                          ? '…'
                                          : fmt(stats?.totalTeachers),
                                      label: 'معلم',
                                    ),
                                    AdminHeroMetric(
                                      value: loading
                                          ? '…'
                                          : fmt(finance?.totalRevenue.round()),
                                      label: '$academyCurrencyLabel محصّل',
                                    ),
                                  ],
                                ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 20),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(AppSizes.radiusXL),
                              topRight: Radius.circular(AppSizes.radiusXL),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (state.statsStatus == SectionStatus.error)
                                  AppErrorWidget(
                                    message:
                                        state.statsError ??
                                        'تعذر تحميل الإحصائيات',
                                    onRetry: _refresh,
                                  )
                                else if (state.statsStatus ==
                                    SectionStatus.loading)
                                  const AdminDashboardStatsGridSkeleton()
                                else
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.25,
                                    children: [
                                      AdminStatTile(
                                        value: loading
                                            ? '…'
                                            : fmt(stats?.totalStudents),
                                        label: 'إجمالي الطلاب',
                                        icon: Icons.school_outlined,
                                        iconBg: AppColors.successBg,
                                        iconColor: AppColors.success,
                                        onTap: widget.onSwitchTab == null
                                            ? null
                                            : () => widget.onSwitchTab!(1),
                                      ),
                                      AdminStatTile(
                                        key: const Key('admin-stat-supervisors'),
                                        value: loading
                                            ? '…'
                                            : fmt(stats?.totalSupervisors),
                                        label: 'إجمالي المشرفين',
                                        icon: Icons.supervisor_account_outlined,
                                        iconBg: AppColors.primaryLight,
                                        iconColor: AppColors.primary,
                                        onTap: () => context.push(
                                          AppRoutes.adminSupervisors,
                                        ),
                                      ),
                                      AdminStatTile(
                                        key: const Key('admin-stat-unpaid'),
                                        value: loading
                                            ? '…'
                                            : fmt(finance?.unpaidCount),
                                        label: 'مدفوعات غير مسددة',
                                        icon: Icons.credit_card_outlined,
                                        iconBg: const Color(0xFFFFF8E1),
                                        iconColor: AppColors.warning,
                                        badge:
                                            finance != null &&
                                                finance.awaitingReviewCount > 0
                                            ? '${finance.awaitingReviewCount} للمراجعة'
                                            : null,
                                        badgeColor: AppColors.info,
                                        onTap: widget.onSwitchTab == null
                                            ? null
                                            : () => widget.onSwitchTab!(3),
                                      ),
                                      AdminStatTile(
                                        value: loading
                                            ? '…'
                                            : fmt(stats?.totalTeachers),
                                        label: 'المعلمون',
                                        icon: Icons.groups_outlined,
                                        iconBg: const Color(0xFFE8F5E9),
                                        iconColor: AppColors.success,
                                        onTap: () => context.push(
                                          AppRoutes.adminTeachers,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 24),
                                AdminSectionHeader(
                                  title: 'طلبات بانتظار الموافقة',
                                  actionLabel: pendingRequests.isNotEmpty
                                      ? 'عرض الكل'
                                      : null,
                                  onAction: pendingRequests.isNotEmpty
                                      ? () => context.push(
                                          AppRoutes.adminRegistration,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                if (state.registrationStatus ==
                                    SectionStatus.loading)
                                  const AdminPendingListSkeleton()
                                else if (state.registrationStatus ==
                                    SectionStatus.error)
                                  AppErrorWidget(
                                    message:
                                        state.registrationError ??
                                        'تعذر تحميل طلبات التسجيل',
                                    onRetry: _refresh,
                                  )
                                else if (pendingRequests.isEmpty)
                                  const _DashboardEmpty(
                                    icon: Icons.how_to_reg_outlined,
                                    text: 'لا توجد طلبات تسجيل بانتظار التعيين',
                                  )
                                else
                                  ...pendingRequests
                                      .take(2)
                                      .map(
                                        (r) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _registrationTile(r, context),
                                        ),
                                      ),
                                const SizedBox(height: 24),
                                AdminSectionHeader(
                                  title: 'شكاوى مفتوحة',
                                  actionLabel: openComplaints.isNotEmpty
                                      ? 'عرض الكل'
                                      : null,
                                  onAction: openComplaints.isNotEmpty
                                      ? () => context.push(
                                          AppRoutes.adminComplaints,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                if (state.complaintsStatus ==
                                    SectionStatus.loading)
                                  const AdminPendingListSkeleton()
                                else if (state.complaintsStatus ==
                                    SectionStatus.error)
                                  AppErrorWidget(
                                    message:
                                        state.complaintsError ??
                                        'تعذر تحميل الشكاوى',
                                    onRetry: _refresh,
                                  )
                                else if (openComplaints.isEmpty)
                                  const _DashboardEmpty(
                                    icon: Icons.mark_chat_read_outlined,
                                    text: 'لا توجد شكاوى مفتوحة حالياً',
                                  )
                                else
                                  ...openComplaints
                                      .take(2)
                                      .map(
                                        (c) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _complaintTile(c, context),
                                        ),
                                      ),
                                const SizedBox(height: 24),
                                const AdminSectionHeader(
                                  title: 'إجراءات سريعة',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AdminQuickActionTile(
                                        icon: Icons.group_add_outlined,
                                        label: 'حلقة جديدة',
                                        onTap: () => context.push(
                                          AppRoutes.adminCreateHalaqa,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: AdminQuickActionTile(
                                        icon: Icons.person_add_alt_1_outlined,
                                        label: 'تسجيل طالب',
                                        onTap: () => context.push(
                                          AppRoutes.adminOnboardStudent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: AdminQuickActionTile(
                                        icon: Icons.campaign_outlined,
                                        label: 'إعلان عام',
                                        onTap: () => context.push(
                                          AppRoutes.adminBroadcast,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _registrationTile(RegistrationRequestEntity r, BuildContext context) {
    final letter = r.name.isNotEmpty ? r.name.characters.first : 'ط';
    return AdminPendingRequestTile(
      title: r.name,
      subtitle: r.email ?? 'طالب جديد',
      badgeLabel: 'جديد',
      badgeColor: AppColors.primary,
      badgeBg: AppColors.primaryLight,
      avatarLetter: letter,
      avatarBg: AppColors.primaryLight,
      onTap: () => context.push(AppRoutes.adminStudentProfile(r.studentId)),
    );
  }

  Widget _complaintTile(ComplaintEntity c, BuildContext context) {
    final letter = c.subject.isNotEmpty ? c.subject.characters.first : 'ش';
    return AdminPendingRequestTile(
      title: c.subject,
      subtitle: c.message,
      badgeLabel: c.status == ComplaintStatuses.inProgress
          ? 'قيد المعالجة'
          : 'جديدة',
      badgeColor: AppColors.warning,
      badgeBg: AppColors.warning.withValues(alpha: 0.12),
      avatarLetter: letter,
      avatarBg: AppColors.error.withValues(alpha: 0.12),
      onTap: () => openComplaintDetails(context, c.id),
    );
  }
}

bool isOpenComplaintStatus(String status) =>
    status == ComplaintStatuses.open || status == ComplaintStatuses.inProgress;

enum AdminHealthLevel { loading, normal, pending, warning, error }

class AdminDashboardHealth {
  const AdminDashboardHealth(this.level, this.headline, this.detail, this.icon);

  final AdminHealthLevel level;
  final String headline;
  final String detail;
  final IconData icon;
}

/// Live academy status, most severe first: load failures, then items that
/// need action (overdue payments, open complaints), then queues waiting on
/// someone (registrations, proofs under review), else normal.
AdminDashboardHealth adminDashboardHealth(
  AdminState state, {
  required bool loading,
}) {
  if (loading) {
    return const AdminDashboardHealth(
      AdminHealthLevel.loading,
      'جاري التحميل…',
      'حالة الأكاديمية الآن',
      Icons.hourglass_top_rounded,
    );
  }
  final failed = [
    state.statsStatus,
    state.financialStatus,
    state.complaintsStatus,
    state.registrationStatus,
  ].where((s) => s == SectionStatus.error).length;
  if (failed > 0) {
    return const AdminDashboardHealth(
      AdminHealthLevel.error,
      'تعذر تحميل بعض البيانات',
      'اسحب للأسفل لإعادة المحاولة',
      Icons.error_outline_rounded,
    );
  }
  final finance = state.financialSummary;
  final overdue = finance?.overdueCount ?? 0;
  final complaints = state.complaints
      .where((c) => isOpenComplaintStatus(c.status))
      .length;
  final warnings = <String>[
    if (overdue > 0) '$overdue ${overdue == 1 ? 'دفعة متأخرة' : 'دفعات متأخرة'}',
    if (complaints > 0)
      '$complaints ${complaints == 1 ? 'شكوى تحتاج' : 'شكاوى تحتاج'} متابعة',
  ];
  if (warnings.isNotEmpty) {
    return AdminDashboardHealth(
      AdminHealthLevel.warning,
      warnings.first,
      warnings.length > 1 ? warnings.skip(1).join(' · ') : 'تنبيهات تحتاج متابعة',
      Icons.warning_amber_rounded,
    );
  }
  final requests = state.registrationRequests.length;
  final proofs = finance?.awaitingReviewCount ?? 0;
  final pending = <String>[
    if (requests > 0)
      '$requests ${requests == 1 ? 'طلب' : 'طلبات'} بانتظار الموافقة',
    if (proofs > 0) '$proofs ${proofs == 1 ? 'إيصال' : 'إيصالات'} قيد مراجعة المشرفين',
  ];
  if (pending.isNotEmpty) {
    return AdminDashboardHealth(
      AdminHealthLevel.pending,
      pending.first,
      pending.length > 1 ? pending.skip(1).join(' · ') : 'بانتظار إجراء',
      Icons.pending_actions_rounded,
    );
  }
  return const AdminDashboardHealth(
    AdminHealthLevel.normal,
    'كل شيء على ما يرام اليوم',
    'حالة الأكاديمية الآن',
    Icons.verified_rounded,
  );
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        child: Column(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 28),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
