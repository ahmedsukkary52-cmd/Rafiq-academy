import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const RefreshAdminDashboardEvent());
    });
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

  String _headline(AdminState state, bool loading) {
    if (loading) return 'جاري التحميل…';
    final pending = state.registrationRequests.length;
    if (pending > 0) {
      return '$pending ${pending == 1 ? 'طلب' : 'طلبات'} بانتظار الموافقة';
    }
    final openComplaints = state.complaints
        .where((c) => c.status != 'resolved')
        .length;
    if (openComplaints > 0) {
      return '$openComplaints ${openComplaints == 1 ? 'شكوى' : 'شكاوى'} تحتاج متابعة';
    }
    return 'كل شيء على ما يرام اليوم';
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
            .where((c) => c.status != 'resolved')
            .toList();
        final loading =
            state.statsStatus == SectionStatus.loading ||
            state.financialStatus == SectionStatus.loading ||
            state.registrationStatus == SectionStatus.loading;
        final fmt = formatAdminCount;

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
                                  eyebrow: 'نظرة تنفيذية اليوم',
                                  headline: _headline(state, loading),
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
                                      label: 'ريال إيراد مدفوع',
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
                                        value: loading
                                            ? '…'
                                            : fmt(stats?.totalHalaqat),
                                        label: 'حلقات نشطة',
                                        icon: Icons.menu_book_outlined,
                                        iconBg: AppColors.primaryLight,
                                        iconColor: AppColors.primary,
                                      ),
                                      AdminStatTile(
                                        value: loading
                                            ? '…'
                                            : fmt(finance?.dueCount),
                                        label: 'مدفوعات معلقة',
                                        icon: Icons.credit_card_outlined,
                                        iconBg: const Color(0xFFFFF8E1),
                                        iconColor: AppColors.warning,
                                        badge:
                                            finance != null &&
                                                finance.dueCount > 0
                                            ? '${finance.dueCount}'
                                            : null,
                                        badgeColor: AppColors.error,
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
                                else if (pendingRequests.isEmpty)
                                  const AppCard(
                                    child: Text(
                                      'لا توجد طلبات تسجيل بانتظار التعيين',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
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
                                          AppRoutes.adminComplaintsReview,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                if (state.complaintsStatus ==
                                    SectionStatus.loading)
                                  const AdminPendingListSkeleton()
                                else if (openComplaints.isEmpty)
                                  const AppCard(
                                    child: Text(
                                      'لا توجد شكاوى مفتوحة حالياً',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
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
                                        label: 'قبول طالب',
                                        onTap: () =>
                                            context.push(AppRoutes.adminAdmit),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: AdminQuickActionTile(
                                        icon: Icons.campaign_outlined,
                                        label: 'إشعار عام',
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
      subtitle: r.phone ?? r.email ?? 'طالب جديد',
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
      badgeLabel: c.status == 'open' ? 'جديدة' : c.status,
      badgeColor: AppColors.warning,
      badgeBg: AppColors.warning.withValues(alpha: 0.12),
      avatarLetter: letter,
      avatarBg: AppColors.error.withValues(alpha: 0.12),
      onTap: () => context.push(AppRoutes.adminComplaints),
    );
  }
}
