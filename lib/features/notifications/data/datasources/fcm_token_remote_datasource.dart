import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../shared/domain/fcm_token_contract.dart';
import '../../domain/entities/fcm_device_registration.dart';

abstract class FcmTokenRemoteDatasource {
  Future<void> upsertDeviceToken({
    required String uid,
    required FcmDeviceRegistration registration,
  });

  Future<void> disableDeviceToken({
    required String uid,
    required String deviceId,
  });
}

/// Writes only to `fcmTokens/{uid}/devices/{deviceId}` (C11 / WA-13).
///
/// Payload is limited to [FcmTokenContract.clientWritableFields]; server-owned
/// fields are never sent, matching the Rules contract.
@LazySingleton(as: FcmTokenRemoteDatasource)
class FcmTokenRemoteDatasourceImpl implements FcmTokenRemoteDatasource {
  final FirebaseFirestore firestore;

  const FcmTokenRemoteDatasourceImpl({required this.firestore});

  DocumentReference<Map<String, dynamic>> _deviceRef({
    required String uid,
    required String deviceId,
  }) =>
      firestore.doc(FcmTokenContract.devicePath(uid: uid, deviceId: deviceId));

  @override
  Future<void> upsertDeviceToken({
    required String uid,
    required FcmDeviceRegistration registration,
  }) async {
    if (!registration.isValid) {
      throw const ServerException('invalid fcm device registration');
    }
    try {
      final ref = _deviceRef(uid: uid, deviceId: registration.deviceId);
      final snapshot = await ref.get();

      await ref.set({
        FcmTokenContract.tokenField: registration.token.trim(),
        FcmTokenContract.platformField: registration.platform,
        FcmTokenContract.disabledField: false,
        if (!snapshot.exists)
          FcmTokenContract.createdAtField: FieldValue.serverTimestamp(),
        FcmTokenContract.updatedAtField: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> disableDeviceToken({
    required String uid,
    required String deviceId,
  }) async {
    try {
      await _deviceRef(uid: uid, deviceId: deviceId).set({
        FcmTokenContract.disabledField: true,
        FcmTokenContract.updatedAtField: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
