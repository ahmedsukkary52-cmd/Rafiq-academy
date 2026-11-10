import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:injectable/injectable.dart';

import '../../../../shared/domain/fcm_token_contract.dart';
import '../../domain/services/fcm_messaging_port.dart';

/// Thin `firebase_messaging` adapter (C11 / WA-13).
///
/// Holds every platform-channel call so the registrar stays pure application
/// logic. Sending is never done here — pushes come from Cloud Functions only.
@LazySingleton(as: FcmMessagingPort)
class FirebaseMessagingAdapter implements FcmMessagingPort {
  final FirebaseMessaging messaging;

  const FirebaseMessagingAdapter({required this.messaging});

  @override
  Future<bool> requestPermission() async {
    final settings = await messaging.requestPermission();
    final status = settings.authorizationStatus;
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> currentToken() => messaging.getToken();

  @override
  Stream<String> tokenRefreshes() => messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => messaging.deleteToken();

  @override
  String platformKey() => FcmTokenContract.platformKey(
    isWeb: kIsWeb,
    operatingSystem: kIsWeb ? '' : Platform.operatingSystem,
  );
}
