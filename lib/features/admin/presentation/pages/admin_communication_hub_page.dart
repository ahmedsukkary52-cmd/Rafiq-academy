import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../../chat/presentation/chat_route_extra.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
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
          StartWatchingAllConversationsEvent(auth.user.uid),
        );
      }
    });
  }

  List<double> _weekdayCounts(List<ConversationEntity> conversations) {
    final counts = List<double>.filled(7, 0);
    for (final c in conversations) {
      final at = c.lastMessageAt;
      if (at == null) continue;
      counts[at.weekday % 7] += 1;
    }
    return counts;
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
          icon: Icons.search_rounded,
          onTap: () => context.push('${AppRoutes.admin}/chat'),
        ),
        const SizedBox(width: 8),
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
              StartWatchingAllConversationsEvent(adminUid),
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
                    final convCount = chatState.conversations.length;
                    final unread = chatState.totalUnreadCount;
                    final openComplaints = adminState.complaints
                        .where((c) => c.status != 'resolved')
                        .length;
                    final teachers = adminState.stats?.totalTeachers ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminGradientHeroCard(
                          eyebrow: 'نشاط التواصل اليوم',
                          headline:
                              '${adminFormatCount(convCount)} محادثة نشطة',
                          metrics: [
                            AdminHeroMetric(
                              value: adminFormatCount(unread),
                              label: 'غير مقروءة',
                            ),
                            AdminHeroMetric(
                              value: adminFormatCount(openComplaints),
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
                              value: adminFormatCount(convCount),
                              label: 'إجمالي المحادثات',
                              icon: Icons.chat_bubble_outline,
                              iconBg: AppColors.primaryLight,
                              iconColor: AppColors.primary,
                              onTap: () =>
                                  context.push('${AppRoutes.admin}/chat'),
                            ),
                            AdminStatTile(
                              value: adminFormatCount(unread),
                              label: 'محادثات غير مقروءة',
                              icon: Icons.mail_outline,
                              iconBg: const Color(0xFFFFF3E0),
                              iconColor: AppColors.warning,
                              onTap: () =>
                                  context.push('${AppRoutes.admin}/chat'),
                            ),
                            AdminStatTile(
                              value: adminFormatCount(teachers),
                              label: 'إجمالي المعلمين',
                              icon: Icons.groups_outlined,
                              iconBg: AppColors.successBg,
                              iconColor: AppColors.success,
                            ),
                            AdminStatTile(
                              value: adminFormatCount(openComplaints),
                              label: 'شكاوى معلقة',
                              icon: Icons.flag_outlined,
                              iconBg: const Color(0xFFFFEBEE),
                              iconColor: AppColors.error,
                              onTap: () =>
                                  context.push(AppRoutes.adminComplaintsReview),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        AppCard(
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_outlined,
                                  color: AppColors.info,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      adminFormatCount(unread),
                                      style: AppTextStyles.titleLarge.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'رسائل غير مقروءة',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AdminSectionHeader(
                          title: 'تحليلات التواصل — آخر 7 أيام',
                          actionLabel: 'التفاصيل',
                          onAction: () => context.push(
                            '${AppRoutes.admin}/communication-analytics',
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          child: AdminSimpleBarChart(
                            values: _weekdayCounts(chatState.conversations),
                            labels: const ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'],
                          ),
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
                                          Text(
                                            title,
                                            style: AppTextStyles.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
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
