import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/fcm_device_registration.dart';
import '../../domain/repositories/fcm_token_repository.dart';
import '../datasources/fcm_token_remote_datasource.dart';

@LazySingleton(as: FcmTokenRepository)
class FcmTokenRepositoryImpl implements FcmTokenRepository {
  final FcmTokenRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const FcmTokenRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, Unit>> upsertDeviceToken({
    required String uid,
    required FcmDeviceRegistration registration,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.upsertDeviceToken(
        uid: uid,
        registration: registration,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> disableDeviceToken({
    required String uid,
    required String deviceId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.disableDeviceToken(uid: uid, deviceId: deviceId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
