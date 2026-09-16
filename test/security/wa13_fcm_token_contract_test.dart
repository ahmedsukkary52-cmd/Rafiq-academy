import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_device_id_provider.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_token_registrar.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/fcm_device_registration.dart';
import 'package:rafiq_academy/features/notifications/domain/repositories/fcm_token_repository.dart';
import 'package:rafiq_academy/features/notifications/domain/services/fcm_messaging_port.dart';
import 'package:rafiq_academy/shared/domain/fcm_token_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMessagingPort implements FcmMessagingPort {
  bool permission = true;
  String? token = 'tok-1';
  int permissionCalls = 0;
  final StreamController<String> refreshes =
      StreamController<String>.broadcast();

  @override
  Future<String?> currentToken() async => token;

  @override
  String platformKey() => FcmTokenContract.platformAndroid;

  @override
  Future<bool> requestPermission() async {
    permissionCalls += 1;
    return permission;
  }

  @override
  Stream<String> tokenRefreshes() => refreshes.stream;
}

class _FakeDeviceIdProvider implements FcmDeviceIdProvider {
  _FakeDeviceIdProvider(this.id);

  final String id;
  int calls = 0;

  @override
  Future<String> deviceId() async {
    calls += 1;
    return id;
  }
}

class _RecordingTokenRepository implements FcmTokenRepository {
  final List<({String uid, FcmDeviceRegistration registration})> upserts = [];
  final List<({String uid, String deviceId})> disables = [];

  @override
  Future<Either<Failure, Unit>> upsertDeviceToken({
    required String uid,
    required FcmDeviceRegistration registration,
  }) async {
    upserts.add((uid: uid, registration: registration));
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> disableDeviceToken({
    required String uid,
    required String deviceId,
  }) async {
    disables.add((uid: uid, deviceId: deviceId));
    return const Right(unit);
  }
}

void main() {
  group('WA-13 FCM token contract (C11)', () {
    test('device path is the frozen fcmTokens/{uid}/devices/{deviceId}', () {
      expect(
        FcmTokenContract.devicePath(uid: 'parent1', deviceId: 'dev_a1'),
        'fcmTokens/parent1/devices/dev_a1',
      );
    });

    test('path rejects empty or unsafe segments', () {
      expect(
        () => FcmTokenContract.devicePath(uid: '', deviceId: 'dev_a1'),
        throwsArgumentError,
      );
      expect(
        () => FcmTokenContract.devicePath(uid: 'parent1', deviceId: ' '),
        throwsArgumentError,
      );
      expect(
        () => FcmTokenContract.devicePath(uid: 'parent1', deviceId: 'a/b'),
        throwsArgumentError,
      );
    });

    test('client fields match the locked schema and exclude server fields', () {
      expect(FcmTokenContract.clientWritableFields, const [
        'token',
        'platform',
        'createdAt',
        'updatedAt',
        'disabled',
      ]);
      for (final field in FcmTokenContract.serverOwnedFields) {
        expect(FcmTokenContract.clientWritableFields, isNot(contains(field)));
      }
    });

    test('platform values are android | ios | web', () {
      expect(FcmTokenContract.supportedPlatforms, const [
        'android',
        'ios',
        'web',
      ]);
      expect(FcmTokenContract.isSupportedPlatform('desktop'), isFalse);
      expect(
        FcmTokenContract.platformKey(isWeb: false, operatingSystem: 'iOS'),
        'ios',
      );
      expect(
        FcmTokenContract.platformKey(isWeb: true, operatingSystem: ''),
        'web',
      );
    });

    test('token validation bounds payload size', () {
      expect(FcmTokenContract.isUsableToken(''), isFalse);
      expect(FcmTokenContract.isUsableToken('t'), isTrue);
      expect(
        FcmTokenContract.isUsableToken(
          'x' * (FcmTokenContract.maxTokenLength + 1),
        ),
        isFalse,
      );
    });

    test('registration validity mirrors the Rules contract', () {
      const valid = FcmDeviceRegistration(
        deviceId: 'dev_a1',
        token: 'tok',
        platform: 'android',
      );
      expect(valid.isValid, isTrue);
      expect(
        const FcmDeviceRegistration(
          deviceId: 'dev_a1',
          token: 'tok',
          platform: 'desktop',
        ).isValid,
        isFalse,
      );
    });
  });

  group('WA-13 stable device id', () {
    test('generated id is path-safe and opaque', () {
      final id = SharedPreferencesFcmDeviceIdProvider.generateDeviceId(
        Random(7),
      );
      expect(FcmTokenContract.isValidDeviceId(id), isTrue);
      expect(id.startsWith('dev_'), isTrue);
    });

    test(
      'same id is reused across launches (no per-launch device records)',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});

        final first = await SharedPreferencesFcmDeviceIdProvider().deviceId();
        final second = await SharedPreferencesFcmDeviceIdProvider().deviceId();

        expect(first, second);
      },
    );
  });

  group('WA-13 token lifecycle registrar', () {
    late _FakeMessagingPort messaging;
    late _FakeDeviceIdProvider deviceIds;
    late _RecordingTokenRepository repository;
    late FcmTokenRegistrar registrar;

    setUp(() {
      messaging = _FakeMessagingPort();
      deviceIds = _FakeDeviceIdProvider('dev_stable');
      repository = _RecordingTokenRepository();
      registrar = FcmTokenRegistrar(
        messaging: messaging,
        deviceIdProvider: deviceIds,
        repository: repository,
      );
    });

    tearDown(() => messaging.refreshes.close());

    test(
      'sign-in upserts the current device token for the owner uid',
      () async {
        await registrar.onSignedIn('parent1');

        expect(repository.upserts, hasLength(1));
        expect(repository.upserts.single.uid, 'parent1');
        expect(repository.upserts.single.registration.deviceId, 'dev_stable');
        expect(repository.upserts.single.registration.token, 'tok-1');
      },
    );

    test(
      'repeated sign-in for the same uid does not duplicate records',
      () async {
        await registrar.onSignedIn('parent1');
        await registrar.onSignedIn('parent1');

        expect(repository.upserts, hasLength(1));
        expect(messaging.permissionCalls, 1);
      },
    );

    test('token refresh upserts the same stable device id', () async {
      await registrar.onSignedIn('parent1');
      messaging.refreshes.add('tok-2');
      await Future<void>.delayed(Duration.zero);

      expect(repository.upserts, hasLength(2));
      expect(repository.upserts.last.registration.token, 'tok-2');
      expect(repository.upserts.last.registration.deviceId, 'dev_stable');
    });

    test('denied permission registers nothing', () async {
      messaging.permission = false;
      await registrar.onSignedIn('parent1');

      expect(repository.upserts, isEmpty);
    });

    test('sign-out disables this device and stops refresh writes', () async {
      await registrar.onSignedIn('parent1');
      await registrar.onSignedOut();

      expect(repository.disables, hasLength(1));
      expect(repository.disables.single.uid, 'parent1');
      expect(repository.disables.single.deviceId, 'dev_stable');

      messaging.refreshes.add('tok-3');
      await Future<void>.delayed(Duration.zero);
      expect(repository.upserts, hasLength(1));
      expect(registrar.activeUid, isNull);
    });

    test('account switch re-registers under the new uid only', () async {
      await registrar.onSignedIn('parent1');
      await registrar.onSignedIn('parent2');

      expect(repository.upserts.map((u) => u.uid).toList(), [
        'parent1',
        'parent2',
      ]);
    });
  });
}
