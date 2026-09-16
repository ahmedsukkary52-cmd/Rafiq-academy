import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../domain/entities/fcm_device_registration.dart';
import '../../domain/repositories/fcm_token_repository.dart';
import '../../domain/services/fcm_messaging_port.dart';
import 'fcm_device_id_provider.dart';

/// Single FCM token lifecycle owner for the whole app (C11 / WA-13).
///
/// Wired once from the root auth listener — screens must not register tokens
/// themselves. Registration is idempotent: the same stable device id is
/// upserted on sign-in and on every token refresh.
@lazySingleton
class FcmTokenRegistrar {
  final FcmMessagingPort messaging;
  final FcmDeviceIdProvider deviceIdProvider;
  final FcmTokenRepository repository;

  FcmTokenRegistrar({
    required this.messaging,
    required this.deviceIdProvider,
    required this.repository,
  });

  String? _activeUid;
  StreamSubscription<String>? _refreshSubscription;

  String? get activeUid => _activeUid;

  Future<void> onSignedIn(String uid) async {
    final next = uid.trim();
    if (next.isEmpty) return;
    if (_activeUid == next) return;

    await _stopRefreshWatch();
    _activeUid = next;

    if (!await messaging.requestPermission()) return;

    final token = await messaging.currentToken();
    if (token != null) {
      await _register(uid: next, token: token);
    }

    _refreshSubscription = messaging.tokenRefreshes().listen((refreshed) {
      final current = _activeUid;
      if (current == null) return;
      unawaited(_register(uid: current, token: refreshed));
    });
  }

  /// Stops delivery to this device for the account that signed out.
  Future<void> onSignedOut() async {
    final previous = _activeUid;
    _activeUid = null;
    await _stopRefreshWatch();
    if (previous == null) return;

    final deviceId = await deviceIdProvider.deviceId();
    await repository.disableDeviceToken(uid: previous, deviceId: deviceId);
  }

  Future<void> _register({required String uid, required String token}) async {
    final deviceId = await deviceIdProvider.deviceId();
    final registration = FcmDeviceRegistration(
      deviceId: deviceId,
      token: token,
      platform: messaging.platformKey(),
    );
    if (!registration.isValid) return;

    // Failure is already modelled as Left by the repository; a token write
    // must never surface as an unhandled error in the UI.
    await repository.upsertDeviceToken(uid: uid, registration: registration);
  }

  Future<void> _stopRefreshWatch() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
  }
}
