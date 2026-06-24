import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/notification_entity.dart';

abstract class NotificationsRepository {
  /// Stream لإشعارات المستخدم الحالي: الشخصية + إشعارات دوره + الموحّدة
  /// للكل، مرتبة بالأحدث أولاً.
  Stream<Either<Failure, List<NotificationEntity>>> watchNotifications({
    required String uid,
    required String role,
  });

  /// تعليم إشعار واحد كمقروء لهذا المستخدم تحديداً
  Future<Either<Failure, Unit>> markAsRead({
    required String notificationId,
    required String uid,
  });

  /// تعليم كل الإشعارات الظاهرة حالياً كمقروءة دفعة واحدة
  Future<Either<Failure, Unit>> markAllAsRead({
    required List<String> notificationIds,
    required String uid,
  });
}
