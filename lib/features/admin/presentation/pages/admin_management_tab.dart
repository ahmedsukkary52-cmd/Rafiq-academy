import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../widgets/admin_figma_widgets.dart';

class AdminManagementTab extends StatelessWidget {
  const AdminManagementTab({super.key});

  static final _sections = [
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
          label: 'مركز الشكاوى',
          route: AppRoutes.adminComplaints,
          wired: true,
        ),
        _HubTile(
          icon: Icons.flag_outlined,
          label: 'مراجعة الشكاوى',
          route: AppRoutes.adminComplaintsReview,
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
        _HubTile(
          icon: Icons.notifications_none_rounded,
          label: 'صندوق الإشعارات',
          route: AppRoutes.adminNotifications,
          wired: true,
        ),
        _HubTile(
          icon: Icons.analytics_outlined,
          label: 'تحليلات التواصل',
          route: AppRoutes.adminCommunicationAnalytics,
          wired: true,
        ),
        _HubTile(
          icon: Icons.settings_outlined,
          label: 'إعدادات التواصل',
          route: AppRoutes.adminCommunicationSettings,
          wired: true,
        ),
      ],
    ),
    _HubSection(
      title: 'العمليات',
      tiles: [
        _HubTile(
          icon: Icons.person_add_alt_1_outlined,
          label: 'طلبات التسجيل',
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
          icon: Icons.note_alt_outlined,
          label: 'مجموعة الإدارة',
          route: AppRoutes.adminInternalNotes,
          wired: true,
        ),
      ],
    ),
    _HubSection(
      title: 'الحلقات',
      tiles: [
        _HubTile(
          icon: Icons.groups_outlined,
          label: 'دليل الحلقات',
          route: AppRoutes.adminHalaqat,
          wired: true,
        ),
        _HubTile(
          icon: Icons.add_circle_outline,
          label: 'إنشاء حلقة',
          route: AppRoutes.adminCreateHalaqa,
          wired: true,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
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
                          childAspectRatio: 1.45,
                          children: section.tiles
                              .map(
                                (t) => AdminHubTile(
                                  icon: t.icon,
                                  label: t.label,
                                  wired: t.wired,
                                  onTap: t.route == null
                                      ? null
                                      : () => context.push(t.route!),
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
  final bool wired;

  const _HubTile({
    required this.icon,
    required this.label,
    this.route,
    this.wired = false,
  });
}
