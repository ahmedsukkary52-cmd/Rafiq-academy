import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentNotificationsPage extends StatelessWidget {
  const ParentNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<NotificationsBloc>(),
      child: ParentSubpageScaffold(
        title: 'الإشعارات',
        actions: [
          BlocSelector<NotificationsBloc, NotificationsState, bool>(
            selector: (state) => state.unreadCount > 0,
            builder: (context, hasUnread) {
              return TextButton(
                onPressed: hasUnread
                    ? () => context.read<NotificationsBloc>().add(
                        const MarkAllNotificationsAsReadEvent(),
                      )
                    : null,
                child: Text(
                  'قراءة الكل',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: hasUnread ? AppColors.primary : AppColors.textHint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ],
        body: BlocBuilder<NotificationsBloc, NotificationsState>(
          buildWhen: (p, c) =>
              p.status != c.status ||
              p.notifications != c.notifications ||
              p.error != c.error,
          builder: (context, state) {
            if (state.status == SectionStatus.initial ||
                state.status == SectionStatus.loading) {
              return const ParentListCardsSkeleton();
            }
            if (state.status == SectionStatus.error) {
              return AppErrorWidget(
                message: state.error ?? 'تعذر تحميل الإشعارات',
                onRetry: () {
                  final auth = context.read<AuthBloc>().state;
                  if (auth is! AuthAuthenticated) return;
                  context.read<NotificationsBloc>().add(
                    StartWatchingNotificationsEvent(
                      uid: auth.user.uid,
                      role: auth.user.role,
                    ),
                  );
                },
              );
            }
            if (state.notifications.isEmpty) {
              return const ParentEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'لا توجد إشعارات',
              );
            }

            final grouped = _groupByDate(state.notifications);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: grouped.length,
              itemBuilder: (context, i) {
                final entry = grouped[i];
                if (entry is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                    child: Text(
                      entry,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                final notif = entry as NotificationEntity;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationCard(
                    notification: notif,
                    onTap: () {
                      if (!notif.isRead) {
                        context.read<NotificationsBloc>().add(
                          MarkNotificationAsReadEvent(notif.id),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static List<Object> _groupByDate(List<NotificationEntity> notifications) {
    final result = <Object>[];
    String? lastLabel;
    for (final notif in notifications) {
      final label = _dateLabel(notif.createdAt);
      if (label != lastLabel) {
        result.add(label);
        lastLabel = label;
      }
      result.add(notif);
    }
    return result;
  }

  static String _dateLabel(DateTime dt) {
    final today = AttendancePolicy.dayStart(DateTime.now());
    final day = AttendancePolicy.dayStart(dt);
    if (day == today) return 'اليوم';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس';
    return parentEasternDigits('${dt.day}/${dt.month}/${dt.year}');
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(notification.type);
    final body = parentCleanNotificationBody(notification.body);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: style.accent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: style.bg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            style.icon,
                            color: style.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                parentRelativeTime(notification.createdAt),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 8, height: 8),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static _NotifStyle _styleFor(String type) => switch (type) {
    'achievement' => const _NotifStyle(
      icon: Icons.star_rounded,
      bg: Color(0xFFFFF3E0),
      accent: AppColors.secondary,
    ),
    'payment' => const _NotifStyle(
      icon: Icons.payments_outlined,
      bg: Color(0xFFFFF8E1),
      accent: AppColors.secondary,
    ),
    'attendance' => const _NotifStyle(
      icon: Icons.person_off_outlined,
      bg: Color(0xFFFFE8EE),
      accent: AppColors.error,
    ),
    'assignment' => const _NotifStyle(
      icon: Icons.edit_outlined,
      bg: AppColors.primaryLight,
      accent: AppColors.primaryDark,
    ),
    'session_reminder' => const _NotifStyle(
      icon: Icons.schedule_rounded,
      bg: Color(0xFFE8F5E9),
      accent: AppColors.success,
    ),
    'message' => const _NotifStyle(
      icon: Icons.chat_bubble_outline,
      bg: Color(0xFFF3E5F5),
      accent: AppColors.awardWeekly,
    ),
    _ => const _NotifStyle(
      icon: Icons.notifications_outlined,
      bg: Color(0xFFF0EAFF),
      accent: AppColors.awardWeekly,
    ),
  };
}

class _NotifStyle {
  final IconData icon;
  final Color bg;
  final Color accent;

  const _NotifStyle({
    required this.icon,
    required this.bg,
    required this.accent,
  });
}
