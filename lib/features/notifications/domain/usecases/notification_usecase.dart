import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/notification_entity.dart';
import '../repositories/notifications_repository.dart';

@lazySingleton
class WatchNotificationsUseCase
    extends StreamUseCase<List<NotificationEntity>, WatchNotificationsParams> {
  final NotificationsRepository repository;

  WatchNotificationsUseCase(this.repository);

  @override
  Stream<Either<Failure, List<NotificationEntity>>> call(
    WatchNotificationsParams params,
  ) => repository.watchNotifications(uid: params.uid, role: params.role);
}

@lazySingleton
class MarkNotificationAsReadUseCase
    extends UseCase<Unit, MarkNotificationReadParams> {
  final NotificationsRepository repository;

  MarkNotificationAsReadUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(MarkNotificationReadParams params) {
    return repository.markAsRead(
      notificationId: params.notificationId,
      uid: params.uid,
    );
  }
}

@lazySingleton
class MarkAllNotificationsAsReadUseCase
    extends UseCase<Unit, MarkAllNotificationsReadParams> {
  final NotificationsRepository repository;

  MarkAllNotificationsAsReadUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(MarkAllNotificationsReadParams params) {
    return repository.markAllAsRead(
      notificationIds: params.notificationIds,
      uid: params.uid,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Params
// ══════════════════════════════════════════════════════════════════════════════

class WatchNotificationsParams extends Equatable {
  final String uid;
  final String role;

  const WatchNotificationsParams({required this.uid, required this.role});

  @override
  List<Object?> get props => [uid, role];
}

class MarkNotificationReadParams extends Equatable {
  final String notificationId;
  final String uid;

  const MarkNotificationReadParams({
    required this.notificationId,
    required this.uid,
  });

  @override
  List<Object?> get props => [notificationId, uid];
}

class MarkAllNotificationsReadParams extends Equatable {
  final List<String> notificationIds;
  final String uid;

  const MarkAllNotificationsReadParams({
    required this.notificationIds,
    required this.uid,
  });

  @override
  List<Object?> get props => [notificationIds, uid];
}
