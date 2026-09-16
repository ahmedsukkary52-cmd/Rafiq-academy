import 'package:equatable/equatable.dart';

import '../../../../shared/domain/fcm_token_contract.dart';

/// One device's push registration for the signed-in user (C11 / WA-13).
class FcmDeviceRegistration extends Equatable {
  final String deviceId;
  final String token;
  final String platform;

  const FcmDeviceRegistration({
    required this.deviceId,
    required this.token,
    required this.platform,
  });

  bool get isValid =>
      FcmTokenContract.isValidDeviceId(deviceId) &&
      FcmTokenContract.isUsableToken(token) &&
      FcmTokenContract.isSupportedPlatform(platform);

  @override
  List<Object?> get props => [deviceId, token, platform];
}
