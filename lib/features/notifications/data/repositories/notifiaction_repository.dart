import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart';

@LazySingleton(as: NotificationsRepository)
class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const NotificationsRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Stream<Either<Failure, List<NotificationEntity>>> watchNotifications({
    required String uid,
    required String role,
  }) {
    return remoteDatasource
        .watchNotifications(uid: uid, role: role)
        .map<Either<Failure, List<NotificationEntity>>>((list) => Right(list))
        .handleError((e) => Left(ServerFailure(e.toString())));
  }

  @override
  Future<Either<Failure, Unit>> markAsRead({
    required String notificationId,
    required String uid,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.markAsRead(
        notificationId: notificationId,
        uid: uid,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAllAsRead({
    required List<String> notificationIds,
    required String uid,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.markAllAsRead(
        notificationIds: notificationIds,
        uid: uid,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
