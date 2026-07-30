import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/usecases/notification_usecase.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

/// @singleton: عداد الإشعارات (الجرس) مفروض يفضل متابع طول ما المستخدم
/// فاتح التطبيق، بغض النظر عن أي نافذة هو فيها.
@singleton
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final WatchNotificationsUseCase watchNotifications;
  final MarkNotificationAsReadUseCase markNotificationAsRead;
  final MarkAllNotificationsAsReadUseCase markAllNotificationsAsRead;

  /// بنسجّل الـ uid هنا من أول event، عشان نقدر نبعت "تعليم الكل
  /// كمقروء" لاحقاً من غير ما نحتاج الـ event يحمل الـ uid معاه كل مرة.
  String? _currentUid;

  NotificationsBloc({
    required this.watchNotifications,
    required this.markNotificationAsRead,
    required this.markAllNotificationsAsRead,
  }) : super(NotificationsState.initial()) {
    on<StartWatchingNotificationsEvent>(
      _onStartWatching,
      transformer: restartable(),
    );
    on<StopWatchingNotificationsEvent>(_onStopWatching);
    on<MarkNotificationAsReadEvent>(_onMarkAsRead);
    on<MarkAllNotificationsAsReadEvent>(_onMarkAllAsRead);
  }

  Future<void> _onStopWatching(
    StopWatchingNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    _currentUid = null;
    emit(NotificationsState.initial());
  }

  Future<void> _onStartWatching(
    StartWatchingNotificationsEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    // The bloc is a singleton, so a different identity must not inherit the
    // previous account's list while the new stream is still loading.
    final identityChanged = _currentUid != null && _currentUid != event.uid;
    _currentUid = event.uid;

    emit(
      identityChanged
          ? NotificationsState.initial().copyWith(status: SectionStatus.loading)
          : state.copyWith(status: SectionStatus.loading, error: null),
    );

    await emit.forEach(
      watchNotifications(
        WatchNotificationsParams(uid: event.uid, role: event.role),
      ),
      onData: (either) {
        // Logout (or a newer watch) may have cleared identity while this
        // subscription was still delivering — ignore stale snapshots.
        if (_currentUid != event.uid) return state;

        return either.fold(
          (failure) => state.copyWith(
            status: SectionStatus.error,
            error: failure.message,
          ),
          (notifications) => state.copyWith(
            status: SectionStatus.loaded,
            notifications: notifications,
          ),
        );
      },
    );
  }

  Future<void> _onMarkAsRead(
    MarkNotificationAsReadEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;

    // Optimistic: مفيش داعي ننتظر السيرفر عشان نشيل الـ badge، بس
    // ميهمناش لو فشلت العملية - مش حرجة زي تسجيل الحضور، فمفيش rollback.
    await markNotificationAsRead(
      MarkNotificationReadParams(
        notificationId: event.notificationId,
        uid: uid,
      ),
    );
  }

  Future<void> _onMarkAllAsRead(
    MarkAllNotificationsAsReadEvent event,
    Emitter<NotificationsState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;

    final unreadIds = state.notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    if (unreadIds.isEmpty) return;

    await markAllNotificationsAsRead(
      MarkAllNotificationsReadParams(notificationIds: unreadIds, uid: uid),
    );
  }
}
