import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/notification_entity.dart';
import '../../presentation/bloc/notifications_bloc.dart';
import '../../presentation/bloc/notifications_event.dart';
import '../../presentation/bloc/notifications_state.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<NotificationsBloc>(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F7FA),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(color: Color(0xFFF0F7FA)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    // Title
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'الإشعارات',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('🔔', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    // Mark All as Read
                    BlocBuilder<NotificationsBloc, NotificationsState>(
                      builder: (context, state) {
                        final hasUnread = state.unreadCount > 0;
                        return TextButton(
                          onPressed: hasUnread
                              ? () => context.read<NotificationsBloc>().add(
                                  const MarkAllNotificationsAsReadEvent(),
                                )
                              : null,
                          child: Text(
                            'تعليم الكل كمقروء',
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 12,
                              color: hasUnread
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    if (state.status == SectionStatus.loading) {
                      return const AppLoadingWidget();
                    }
                    if (state.status == SectionStatus.error) {
                      return AppErrorWidget(
                        message: state.error ?? 'حدث خطأ',
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
                      return _EmptyNotifications();
                    }

                    // تجميع الإشعارات بالتاريخ
                    final grouped = _groupByDate(state.notifications);

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      itemCount: grouped.length,
                      itemBuilder: (context, i) {
                        final entry = grouped[i];
                        final isHeader = entry is String;

                        if (isHeader) {
                          return _DateHeader(label: entry);
                        }

                        final notif = entry as NotificationEntity;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NotificationTile(
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
            ],
          ),
        ),
      ),
    );
  }

  /// بترجع list فيها String (header) أو NotificationEntity
  List<Object> _groupByDate(List<NotificationEntity> notifications) {
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

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);

    if (day == today) return 'اليوم';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DateHeader
// ══════════════════════════════════════════════════════════════════════════════

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _NotificationTile
// ══════════════════════════════════════════════════════════════════════════════

class _NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final info = _typeInfo(notification.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الوقت + نقطة الحالة
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(notification.createdAt),
                  style: const TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (!notification.isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // النص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // الأيقونة
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: info.bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(info.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotifTypeInfo _typeInfo(String type) => switch (type) {
    'session_reminder' => const _NotifTypeInfo(
      emoji: '📚',
      bgColor: Color(0xFFE8F5E9),
    ),
    'achievement' => const _NotifTypeInfo(
      emoji: '🏆',
      bgColor: Color(0xFFFFF3E0),
    ),
    'payment' => const _NotifTypeInfo(emoji: '💰', bgColor: Color(0xFFFFEBEE)),
    'assignment' => const _NotifTypeInfo(
      emoji: '📝',
      bgColor: Color(0xFFE3F2FD),
    ),
    'message' => const _NotifTypeInfo(emoji: '💬', bgColor: Color(0xFFF3E5F5)),
    _ => const _NotifTypeInfo(emoji: '🔔', bgColor: Color(0xFFF5F5F5)),
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دق';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return 'أمس';
  }
}

class _NotifTypeInfo {
  final String emoji;
  final Color bgColor;

  const _NotifTypeInfo({required this.emoji, required this.bgColor});
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📭', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 16,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
