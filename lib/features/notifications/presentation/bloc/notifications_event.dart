import 'package:equatable/equatable.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

class StartWatchingNotificationsEvent extends NotificationsEvent {
  final String uid;
  final String role;

  const StartWatchingNotificationsEvent({
    required this.uid,
    required this.role,
  });

  @override
  List<Object?> get props => [uid, role];
}

class MarkNotificationAsReadEvent extends NotificationsEvent {
  final String notificationId;

  const MarkNotificationAsReadEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

/// تعليم كل الإشعارات غير المقروءة الظاهرة حالياً كمقروءة دفعة واحدة
/// (زرار "تعليم الكل كمقروء")
class MarkAllNotificationsAsReadEvent extends NotificationsEvent {
  const MarkAllNotificationsAsReadEvent();
}

/// Clears the singleton inbox and drops the active identity.
///
/// Used on logout so the next account never inherits unread count / list.
/// The next [StartWatchingNotificationsEvent] cancels the previous watch
/// (restartable). Snapshots that arrive after stop are ignored.
class StopWatchingNotificationsEvent extends NotificationsEvent {
  const StopWatchingNotificationsEvent();
}
