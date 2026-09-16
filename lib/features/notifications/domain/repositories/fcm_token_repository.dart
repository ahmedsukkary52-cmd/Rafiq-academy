import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/fcm_device_registration.dart';

/// Own-device push registration port (C11 / WA-13).
///
/// Only the signed-in user's own `fcmTokens/{uid}/devices/{deviceId}` document
/// is reachable — Rules deny any cross-user token access.
abstract class FcmTokenRepository {
  /// Idempotent upsert keyed by the stable device id (no duplicate records).
  Future<Either<Failure, Unit>> upsertDeviceToken({
    required String uid,
    required FcmDeviceRegistration registration,
  });

  /// Stops delivery to this device without deleting the owner's history.
  Future<Either<Failure, Unit>> disableDeviceToken({
    required String uid,
    required String deviceId,
  });
}
