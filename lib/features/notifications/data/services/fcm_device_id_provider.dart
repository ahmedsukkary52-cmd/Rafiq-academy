import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/domain/fcm_token_contract.dart';

/// Stable per-install device id (C11 / WA-13).
///
/// Generated once and persisted, so app launches and token refreshes update
/// the same `fcmTokens/{uid}/devices/{deviceId}` document instead of piling up
/// duplicate device records.
abstract class FcmDeviceIdProvider {
  Future<String> deviceId();
}

@LazySingleton(as: FcmDeviceIdProvider)
class SharedPreferencesFcmDeviceIdProvider implements FcmDeviceIdProvider {
  static const String prefsKey = 'wa13.fcm.device_id';

  SharedPreferencesFcmDeviceIdProvider();

  String? _cached;

  @override
  Future<String> deviceId() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey)?.trim() ?? '';
    if (FcmTokenContract.isValidDeviceId(stored)) {
      _cached = stored;
      return stored;
    }

    final generated = generateDeviceId();
    await prefs.setString(prefsKey, generated);
    _cached = generated;
    return generated;
  }

  /// Opaque, path-safe id — carries no hardware or account identity.
  static String generateDeviceId([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'dev_$hex';
  }
}
