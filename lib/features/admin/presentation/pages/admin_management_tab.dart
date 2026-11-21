import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/theme/app_theme.dart';
import '../widgets/admin_figma_widgets.dart';
import 'admin_academy_import_page.dart';
import 'admin_home_page.dart';

class AdminManagementTab extends StatelessWidget {
  const AdminManagementTab({super.key});

  static final _sections = [
    _HubSection(
      title: 'العمليات الإدارية',
      tiles: [
        _HubTile(
          icon: Icons.person_add_alt_1_rounded,
          label: AdminHomePage.actionLabels[0],
          route: AppRoutes.adminAccounts,
          wired: true,
        ),
        _HubTile(
          icon: Icons.family_restroom_rounded,
          label: AdminHomePage.actionLabels[1],
          route: AppRoutes.adminParentLinks,
          wired: true,
        ),
        _HubTile(
          icon: Icons.groups_rounded,
          label: AdminHomePage.actionLabels[2],
          route: AppRoutes.adminHalaqat,
          wired: true,
        ),
        _HubTile(
          icon: Icons.swap_horiz_rounded,
          label: AdminHomePage.actionLabels[3],
          route: AppRoutes.adminMembership,
          wired: true,
        ),
        _HubTile(
          icon: Icons.receipt_long_rounded,
          label: AdminHomePage.actionLabels[4],
          route: AppRoutes.adminPayments,
          wired: true,
        ),
        // Access reactivation also appears under Settings with a clearer
        // payments subtitle — keep a single entry there to avoid duplicates.
        const _HubTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'وسائل الدفع',
          route: AppRoutes.adminPaymentDestinations,
          wired: true,
        ),
      ],
    ),
    _HubSection(
      title: 'التواصل',
      tiles: [
        _HubTile(
          icon: Icons.forum_outlined,
          label: 'مركز التواصل',
          route: AppRoutes.adminCommunication,
          wired: true,
        ),
        _HubTile(
          icon: Icons.chat_bubble_outline,
          label: 'الشكاوى',
          route: AppRoutes.adminComplaints,
          wired: true,
        ),
        _HubTile(
          icon: Icons.campaign_outlined,
          label: 'البث الجماعي',
          route: AppRoutes.adminBroadcast,
          wired: true,
        ),
        _HubTile(
          icon: Icons.mail_outline,
          label: 'الرسائل',
          route: AppRoutes.adminChat,
          wired: true,
        ),
        const _HubTile(
          icon: Icons.admin_panel_settings_outlined,
          label: 'مجموعة الإدارة',
          route: AppRoutes.adminInternalNotes,
          wired: true,
        ),
        _HubTile(
          icon: Icons.notifications_none_rounded,
          label: 'صندوق الإشعارات',
          route: AppRoutes.adminNotifications,
          wired: true,
        ),
      ],
    ),
    _HubSection(
      title: 'الأكاديمية',
      tiles: [
        _HubTile(
          icon: Icons.account_tree_outlined,
          label: 'دليل الأكاديمية',
          route: AppRoutes.adminDirectory,
          wired: true,
        ),
        _HubTile(
          icon: Icons.person_add_outlined,
          label: 'إضافة معلم أو ولي',
          route: AppRoutes.adminAddMember,
          wired: true,
        ),
      ],
    ),
    _HubSection(
      title: 'العمليات',
      tiles: [
        _HubTile(
          icon: Icons.person_add_alt_1_outlined,
          label: 'طلبات تعيين الطلاب',
          route: AppRoutes.adminRegistration,
          wired: true,
        ),
        _HubTile(
          icon: Icons.school_outlined,
          label: 'إدارة المعلمين',
          route: AppRoutes.adminTeachers,
          wired: true,
        ),
        _HubTile(
          icon: Icons.supervisor_account_outlined,
          label: 'المشرفون',
          route: AppRoutes.adminSupervisors,
          wired: true,
        ),
        _HubTile(
          icon: Icons.folder_open_outlined,
          label: 'مكتبة المحتوى',
          route: AppRoutes.adminContent,
          wired: true,
        ),
        _HubTile(
          icon: Icons.article_outlined,
          label: 'مركز الإعلانات',
          route: AppRoutes.adminAnnouncements,
          wired: true,
        ),
        _HubTile(
          icon: Icons.assessment_outlined,
          label: 'مركز التقارير',
          route: AppRoutes.adminReports,
          wired: true,
        ),
        _HubTile(
          icon: Icons.emoji_events_outlined,
          label: 'التحفيز والمكافآت',
          route: AppRoutes.adminRewards,
          wired: true,
        ),
        _HubTile(
          icon: Icons.upload_file_rounded,
          label: 'استيراد بيانات',
          page: (_) => const AdminAcademyImportPage(),
          wired: true,
        ),
        // Halaqa create lives inside «الحلقات والمواعيد» — no duplicate tile.
        _HubTile(
          icon: Icons.groups_outlined,
          label: 'دليل الحلقات',
          route: AppRoutes.adminHalaqatDirectory,
          wired: true,
        ),
      ],
    ),
  ];

  @visibleForTesting
  static Iterable<String> get hubRoutes =>
      _sections.expand((s) => s.tiles).map((t) => t.route).whereType<String>();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: AdminPageHeader(
                  title: 'الإدارة',
                  subtitle: 'مركز العمليات والتواصل',
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final section = _sections[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminSectionHeader(title: section.title),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          // Taller tiles so 2-line Arabic labels + «متاح» never overflow.
                          childAspectRatio: 1.2,
                          children: section.tiles
                              .map(
                                (t) => AdminHubTile(
                                  icon: t.icon,
                                  label: t.label,
                                  wired: t.wired,
                                  onTap: t.route != null
                                      ? () => context.push(t.route!)
                                      : t.page != null
                                      ? () => Navigator.of(context).push(
                                          MaterialPageRoute(builder: t.page!),
                                        )
                                      : null,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  );
                }, childCount: _sections.length),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubSection {
  final String title;
  final List<_HubTile> tiles;

  const _HubSection({required this.title, required this.tiles});
}

class _HubTile {
  final IconData icon;
  final String label;
  final String? route;
  final WidgetBuilder? page;
  final bool wired;

  const _HubTile({
    required this.icon,
    required this.label,
    this.route,
    this.page,
    this.wired = false,
  });
}
