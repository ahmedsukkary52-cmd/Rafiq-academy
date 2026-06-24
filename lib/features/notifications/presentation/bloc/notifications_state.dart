import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationsState extends Equatable {
  final SectionStatus status;
  final List<NotificationEntity> notifications;
  final String? error;

  const NotificationsState({
    this.status = SectionStatus.initial,
    this.notifications = const [],
    this.error,
  });

  factory NotificationsState.initial() => const NotificationsState();

  /// مفيد لعرض badge برقم على أيقونة الجرس في أي نافذة
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    SectionStatus? status,
    List<NotificationEntity>? notifications,
    String? error,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, notifications, error];
}
