import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../chat/presentation/chat_route_extra.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import 'admin_chat_inbox_page.dart' show adminInboxPageSize;
import 'admin_dashboard_tab.dart' show isOpenComplaintStatus;
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

/// Figma: مركز التواصل — executive overview wired to real chat + admin stats.
class AdminCommunicationHubPage extends StatefulWidget {
  const AdminCommunicationHubPage({super.key});

  @override
  State<AdminCommunicationHubPage> createState() =>
      _AdminCommunicationHubPageState();
}

class _AdminCommunicationHubPageState extends State<AdminCommunicationHubPage> {
  @override
  void initState() {
    super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const RefreshAdminDashboardEvent());
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        sl<ChatConversationsBloc>().add(
          StartWatchingAllConversationsEvent(
            auth.user.uid,
            pageSize: adminInboxPageSize,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final adminUid = auth is AuthAuthenticated ? auth.user.uid : '';

    return AdminSubpageScaffold(
      title: 'مركز التواصل',
      subtitle: 'نظرة تنفيذية شاملة',
      actions: [
        AdminIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => context.push(AppRoutes.adminNotifications),
        ),
        const SizedBox(width: 8),
      ],
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          context.read<AdminBloc>().add(const RefreshAdminDashboardEvent());
          if (adminUid.isNotEmpty) {
            sl<ChatConversationsBloc>().add(
              StartWatchingAllConversationsEvent(
                adminUid,
                pageSize: adminInboxPageSize,
              ),
            );
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
              bloc: sl<ChatConversationsBloc>(),
              builder: (context, chatState) {
                return BlocBuilder<AdminBloc, AdminState>(
                  builder: (context, adminState) {
                    // Paged list: when more exist, show "N+" rather than a
                    // fabricated total.
                    final listed = chatState.conversations.length;
                    final convCount = chatState.hasMoreConversations
                        ? '+${adminFormatCount(listed)}'
                        : adminFormatCount(listed);
                    final unread = chatState.totalUnreadCount;
                    final openCount = adminState.complaints
                        .where((c) => isOpenComplaintStatus(c.status))
                        .length;
                    // The preview query is capped; never present it as exact.
                    final openComplaints = openCount >= 20
                        ? '+20'
                        : adminFormatCount(openCount);
                    final teachers = adminState.stats?.totalTeachers ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminGradientHeroCard(
                          eyebrow: 'نشاط التواصل',
                          headline: '$convCount محادثة',
                          metrics: [
                            AdminHeroMetric(
                              value: adminFormatCount(unread),
                              label: 'غير مقروءة',
                            ),
                            AdminHeroMetric(
                              value: openComplaints,
                              label: 'شكاوى مفتوحة',
                            ),
                            AdminHeroMetric(
                              value: adminFormatCount(teachers),
                              label: 'إجمالي المعلمين',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                          children: [
                            AdminStatTile(
                              value: convCount,
                              label: 'إجمالي المحادثات',
                              icon: Icons.chat_bubble_outline,
                              iconBg: AppColors.primaryLight,
                              iconColor: AppColors.primary,
                              onTap: () =>
                                  context.push('${AppRoutes.admin}/chat'),
                            ),
                            AdminStatTile(
                              value: 'إعلانات',
                              label: 'إعلانات الحلقات',
                              icon: Icons.campaign_outlined,
                              iconBg: const Color(0xFFFFF3E0),
                              iconColor: AppColors.warning,
                              onTap: () =>
                                  context.push(AppRoutes.adminAnnouncements),
                            ),
                            AdminStatTile(
                              key: const Key('hub-teachers'),
                              value: adminFormatCount(teachers),
                              label: 'إجمالي المعلمين',
                              icon: Icons.groups_outlined,
                              iconBg: AppColors.successBg,
                              iconColor: AppColors.success,
                              onTap: () =>
                                  context.push(AppRoutes.adminTeachers),
                            ),
                            AdminStatTile(
                              key: const Key('hub-complaints'),
                              value: openComplaints,
                              label: 'شكاوى مفتوحة',
                              icon: Icons.flag_outlined,
                              iconBg: const Color(0xFFFFEBEE),
                              iconColor: AppColors.error,
                              onTap: () =>
                                  context.push(AppRoutes.adminComplaints),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        AdminSectionHeader(
                          title: 'أحدث الرسائل',
                          actionLabel: 'عرض الكل',
                          onAction: () =>
                              context.push('${AppRoutes.admin}/chat'),
                        ),
                        const SizedBox(height: 10),
                        if (chatState.conversationsStatus ==
                            SectionStatus.loading)
                          const AdminCommunicationSectionSkeleton()
                        else if (chatState.conversations.isEmpty)
                          const AdminPlaceholderCard(
                            icon: Icons.forum_outlined,
                            title: 'لا محادثات بعد',
                            message:
                                'عند وجود محادثات في الأكاديمية ستظهر هنا للمراقبة.',
                          )
                        else
                          ...chatState.conversations.take(3).map((c) {
                            final title = c.displayTitleForObserver(adminUid);
                            final isMine = c.includesParticipant(adminUid);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                onTap: () => context.push(
                                  '${AppRoutes.admin}/chat/${c.id}',
                                  extra: {
                                    ChatRouteExtra.nameKey: title,
                                    ChatRouteExtra.imageKey: isMine
                                        ? c
                                              .otherParticipant(adminUid)
                                              .profileImageUrl
                                        : null,
                                    ChatRouteExtra.readOnlyKey: (!isMine)
                                        .toString(),
                                  },
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primaryLight,
                                      child: Text(
                                        title.isNotEmpty
                                            ? title.characters.first
                                            : '?',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  title,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTextStyles
                                                      .titleMedium
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              if (!isMine) ...[
                                                const SizedBox(width: 6),
                                                const AppStatusChip(
                                                  label: 'مراقبة — قراءة فقط',
                                                  tone: AppStatusTone.info,
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            c.lastMessage ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      adminTimeAgo(c.lastMessageAt),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
