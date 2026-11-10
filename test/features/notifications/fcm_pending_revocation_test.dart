import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/domain/services/sign_out_preparation.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_device_id_provider.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_pending_revocation_store.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_token_registrar.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/fcm_device_registration.dart';
import 'package:rafiq_academy/features/notifications/domain/repositories/fcm_token_repository.dart';
import 'package:rafiq_academy/features/notifications/domain/services/fcm_messaging_port.dart';
import 'package:rafiq_academy/shared/domain/fcm_token_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _timeout = Duration(milliseconds: 40);

/// Network outcomes are scripted per call; `online` toggles both FCM token
/// deletion and server acknowledgement of the disable write.
class _Network {
  bool online = true;
  bool disableHangs = false;
  bool tokenThrows = false;

  /// When set, FCM token deletion / the permission prompt wait for it.
  Completer<void>? deleteGate;
  Completer<bool>? permissionGate;
}

class _Messaging implements FcmMessagingPort {
  _Messaging(this.net, this.log);

  final _Network net;
  final List<String> log;
  static int generation = 1;
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<String?> currentToken() async {
    log.add('currentToken');
    if (net.tokenThrows) throw Exception('SERVICE_NOT_AVAILABLE');
    return 'tok-$generation';
  }

  @override
  Future<void> deleteToken() async {
    log.add('deleteToken');
    final gate = net.deleteGate;
    if (gate != null) await gate.future;
    if (!net.online) throw Exception('offline');
    generation++;
  }

  @override
  String platformKey() => FcmTokenContract.platformAndroid;

  @override
  Future<bool> requestPermission() async =>
      await net.permissionGate?.future ?? true;

  @override
  Stream<String> tokenRefreshes() => refreshes.stream;
}

class _DeviceIds implements FcmDeviceIdProvider {
  @override
  Future<String> deviceId() async => 'dev_stable';
}

class _Tokens implements FcmTokenRepository {
  _Tokens(this.net, this.log);

  final _Network net;
  final List<String> log;

  @override
  Future<Either<Failure, Unit>> disableDeviceToken({
    required String uid,
    required String deviceId,
  }) {
    log.add('disable:$uid');
    if (net.disableHangs) return Completer<Either<Failure, Unit>>().future;
    return Future.value(
      net.online ? const Right(unit) : const Left(NetworkFailure()),
    );
  }

  @override
  Future<Either<Failure, Unit>> upsertDeviceToken({
    required String uid,
    required FcmDeviceRegistration registration,
  }) async {
    log.add('upsert:$uid:${registration.token}');
    return const Right(unit);
  }
}

class _BrokenStore implements FcmPendingRevocationStore {
  @override
  Future<Set<String>> read() => throw Exception('disk');

  @override
  Future<void> write(Set<String> uids) => throw Exception('disk');
}

void main() {
  late _Network net;
  late List<String> log;
  final messagings = <_Messaging>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _Messaging.generation = 1;
    net = _Network();
    log = [];
  });

  tearDown(() async {
    for (final m in messagings) {
      await m.refreshes.close();
    }
    messagings.clear();
  });

  /// A fresh process: new registrar and store over the same persisted prefs.
  FcmTokenRegistrar launch({
    FcmPendingRevocationStore? store,
    Duration tokenDeletionTimeout = _timeout,
    List<Duration> retryDelays = const [],
  }) {
    final messaging = _Messaging(net, log);
    messagings.add(messaging);
    return FcmTokenRegistrar(
      messaging: messaging,
      deviceIdProvider: _DeviceIds(),
      repository: _Tokens(net, log),
      pendingRevocations:
          store ?? const SharedPreferencesFcmPendingRevocationStore(),
      revocationTimeout: _timeout,
      tokenDeletionTimeout: tokenDeletionTimeout,
      storeTimeout: _timeout,
      queueWaitTimeout: _timeout,
      pendingRetryDelays: retryDelays,
    );
  }

  Future<Set<String>> persisted() =>
      const SharedPreferencesFcmPendingRevocationStore().read();

  /// Signs [uid] in, then logs out fully offline.
  Future<void> offlineLogout(String uid) async {
    final app = launch();
    await app.onSignedIn(uid);
    net.online = false;
    expect(await app.revokeBeforeSignOut(), DeviceRevocation.unconfirmed);
    log.clear();
  }

  group('durable record', () {
    test('stores only the previous uid, never the token', () async {
      await offlineLogout('parentA');

      final prefs = await SharedPreferences.getInstance();
      expect(await persisted(), {'parentA'});
      for (final key in prefs.getKeys()) {
        expect('${prefs.get(key)}', isNot(contains('tok-')), reason: key);
      }
    });

    test('is written before the network call, so a kill mid-logout still '
        'leaves it', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      net.disableHangs = true;
      final revoking = app.revokeBeforeSignOut();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(await persisted(), {'parentA'});
      net.online = false;
      expect(await revoking, DeviceRevocation.unconfirmed);
    });

    test('a confirmed server disable clears it', () async {
      final app = launch();
      await app.onSignedIn('parentA');

      expect(await app.revokeBeforeSignOut(), DeviceRevocation.confirmed);
      expect(await persisted(), isEmpty);
    });

    test('a confirmed FCM token deletion clears it', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      net.disableHangs = true;

      expect(await app.revokeBeforeSignOut(), DeviceRevocation.confirmed);
      expect(log.where((e) => e == 'deleteToken'), hasLength(1));
      expect(await persisted(), isEmpty);
    });
  });

  group('restart recovery', () {
    test('offline signed-out start keeps the record; the next online start '
        'deletes the token and clears it', () async {
      await offlineLogout('parentA');

      await launch().onSignedOut();
      expect(log, ['deleteToken']);
      expect(await persisted(), {'parentA'});

      net.online = true;
      log.clear();
      await launch().onSignedOut();
      expect(log, ['deleteToken']);
      expect(await persisted(), isEmpty);
    });

    test('a different account after restart gets a fresh token before it '
        'registers, and nothing is written for the previous account', () async {
      await offlineLogout('parentA');
      net.online = true;

      final app = launch();
      await app.onSignedIn('parentB');

      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test('offline: the next account is not registered while the previous '
        'account\'s record (kept, not attributed to it) may still hold the '
        'token; the next start recovers and registers it', () async {
      await offlineLogout('parentA');

      final offlineStart = launch();
      await offlineStart.onSignedIn('parentB');
      expect(log, ['deleteToken']);
      expect(log.any((e) => e.startsWith('disable:')), isFalse);
      expect(await persisted(), {'parentA'});

      net.online = true;
      log.clear();
      await launch().onSignedIn('parentB');
      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test('the same account signing back in drops its own record without '
        'rotating the token', () async {
      await offlineLogout('parentA');
      net.online = true;

      await launch().onSignedIn('parentA');
      expect(log, ['currentToken', 'upsert:parentA:tok-1']);
      expect(await persisted(), isEmpty);
    });

    test('records are per account: B returning does not settle A', () async {
      await offlineLogout('parentA');
      await offlineLogout('parentB');
      expect(await persisted(), {'parentA', 'parentB'});

      final app = launch();
      await app.onSignedIn('parentB');
      expect(log.first, 'deleteToken');
      expect(await persisted(), {'parentA'});
    });
  });

  group('session edges', () {
    test('a failed sign-out (account still signed in) drops the record and '
        're-registers', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      net.online = false;
      await app.revokeBeforeSignOut();
      net.online = true;
      log.clear();

      await app.onSignedIn('parentA');
      expect(log, ['currentToken', 'upsert:parentA:tok-1']);
      expect(await persisted(), isEmpty);
    });

    test('a session ended by the server is recorded and recovered by token '
        'deletion', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      net.online = false;
      log.clear();

      await app.onSignedOut();
      expect(log, ['disable:parentA', 'deleteToken']);
      expect(await persisted(), {'parentA'});
    });

    test(
      'an unusable store never blocks logout and never claims success',
      () async {
        final app = launch(store: _BrokenStore());
        await app.onSignedIn('parentA');
        net.online = false;

        final result = await app.revokeBeforeSignOut().timeout(
          const Duration(seconds: 2),
        );
        expect(result, DeviceRevocation.unconfirmed);

        log.clear();
        await app.onSignedIn('parentB');
        expect(log.first, 'deleteToken', reason: 'in-memory record still acts');
      },
    );
  });

  group('serialized operations (A-1)', () {
    Future<void> drain() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a token deletion in flight finishes before the next account fetches '
        'and registers its token', () async {
      await offlineLogout('parentA');
      net.online = true;
      final app = launch(tokenDeletionTimeout: const Duration(seconds: 5));

      net.deleteGate = Completer<void>();
      final signedOut = app.onSignedOut();
      await drain();
      expect(log, ['deleteToken']);

      final signedIn = app.onSignedIn('parentB');
      await drain();
      expect(log, ['deleteToken'], reason: 'sign-in waits for the deletion');

      net.deleteGate!.complete();
      await signedOut;
      await signedIn;

      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(_Messaging.generation, 2, reason: 'no deletion after register');
      expect(app.activeUid, 'parentB');
      expect(await persisted(), isEmpty);
    });

    test('logout stays bounded while sign-in is stuck at the permission '
        'prompt, and the stuck sign-in never registers afterwards', () async {
      final app = launch();
      net.permissionGate = Completer<bool>();
      final signingIn = app.onSignedIn('parentA');
      await drain();

      final result = await app.revokeBeforeSignOut().timeout(
        const Duration(seconds: 2),
      );
      expect(result, DeviceRevocation.confirmed);
      expect(app.activeUid, isNull);

      net.permissionGate!.complete(true);
      await signingIn;
      await drain();
      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);
      expect(log, isNot(contains('currentToken')));
      expect(app.activeUid, isNull);
    });

    test('a token refresh arriving during logout never re-registers the '
        'signed-out account', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      log.clear();

      net.disableHangs = true;
      final revoking = app.revokeBeforeSignOut();
      messagings.last.refreshes.add('tok-refreshed');
      await drain();
      net.online = false;
      expect(await revoking, DeviceRevocation.unconfirmed);
      await drain();

      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);
    });

    test('a deletion that outlives its timeout cannot invalidate the next '
        'account\'s token', () async {
      await offlineLogout('parentA');
      net.online = true;
      // Every wait for the deletion times out at once, before it finishes.
      final app = launch(tokenDeletionTimeout: Duration.zero);

      net.deleteGate = Completer<void>();
      await app.onSignedOut();
      expect(log, ['deleteToken']);
      expect(await persisted(), {'parentA'}, reason: 'not confirmed yet');

      var signedIn = false;
      final signingIn = app.onSignedIn('parentB').then((_) => signedIn = true);
      await drain();
      expect(log, ['deleteToken'], reason: 'no token fetched mid-deletion');
      expect(signedIn, isFalse);

      net.deleteGate!.complete();
      await signingIn;
      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(_Messaging.generation, 2, reason: 'registered token is current');
      expect(await persisted(), isEmpty, reason: 'late success settles A');
    });

    test(
      'the same account signing back in after a timed-out revoke waits '
      'for the late deletion instead of registering a doomed token',
      () async {
        final app = launch();
        await app.onSignedIn('parentA');
        log.clear();
        net
          ..disableHangs = true
          ..deleteGate = Completer<void>();
        expect(await app.revokeBeforeSignOut(), DeviceRevocation.unconfirmed);

        final signingIn = app.onSignedIn('parentA');
        await drain();
        expect(log, ['disable:parentA', 'deleteToken']);

        net.deleteGate!.complete();
        await signingIn;
        expect(log.last, 'upsert:parentA:tok-2');
        expect(_Messaging.generation, 2);
        expect(await persisted(), isEmpty);
      },
    );

    test('a late deletion that fails leaves the previous account pending; '
        'the next start recovers it', () async {
      await offlineLogout('parentA');
      net.online = true;
      final app = launch();
      net.deleteGate = Completer<void>();
      await app.onSignedOut();

      final signingIn = app.onSignedIn('parentB');
      await drain();
      net.online = false;
      net.deleteGate!.complete();
      await signingIn;
      expect(log, ['deleteToken'], reason: 'tok-1 may still reach parentA');
      expect(_Messaging.generation, 1, reason: 'tok-1 was never deleted');
      expect(await persisted(), {'parentA'});

      net
        ..online = true
        ..deleteGate = null;
      log.clear();
      await launch().onSignedIn('parentB');
      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test('a sign-in left waiting on a late deletion is superseded by logout '
        'and never registers or changes state afterwards', () async {
      await offlineLogout('parentA');
      net.online = true;
      final app = launch();
      net.deleteGate = Completer<void>();
      await app.onSignedOut();

      final signingIn = app.onSignedIn('parentB');
      await drain();
      final result = await app.revokeBeforeSignOut().timeout(
        const Duration(seconds: 2),
      );
      expect(result, isNot(DeviceRevocation.notRegistered));
      expect(app.activeUid, isNull);
      final before = await persisted();

      net.deleteGate!.complete();
      await signingIn;
      await drain();
      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);
      expect(log, isNot(contains('currentToken')));
      expect(app.activeUid, isNull);
      expect(await persisted(), before, reason: 'stale sign-in wrote nothing');
    });

    test('a sign-in still queued when logout is requested never starts '
        'afterwards', () async {
      await offlineLogout('parentA');
      net.online = true;
      final app = launch(tokenDeletionTimeout: const Duration(seconds: 1));
      net.deleteGate = Completer<void>();
      final signedOut = app.onSignedOut();
      await drain();

      final queuedB = app.onSignedIn('parentB');
      final result = await app.revokeBeforeSignOut().timeout(
        const Duration(seconds: 2),
      );
      expect(result, DeviceRevocation.notRegistered);

      net.deleteGate!.complete();
      await signedOut;
      await queuedB;
      await drain();

      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);
      expect(log, isNot(contains('currentToken')));
      expect(app.activeUid, isNull);
    });

    test('repeated logout is idempotent and never re-adds a record', () async {
      final app = launch();
      await app.onSignedIn('parentA');

      expect(await app.revokeBeforeSignOut(), DeviceRevocation.confirmed);
      expect(await app.revokeBeforeSignOut(), DeviceRevocation.notRegistered);
      await app.onSignedOut();

      expect(log.where((e) => e == 'disable:parentA'), hasLength(1));
      expect(log, isNot(contains('deleteToken')));
      expect(await persisted(), isEmpty);
    });

    test(
      'back-to-back sign-ins of different accounts run in order, rotate '
      'the token between them and leave only the last account active',
      () async {
        final app = launch();
        final first = app.onSignedIn('parentA');
        final second = app.onSignedIn('parentB');
        await first;
        await second;

        expect(log, [
          'currentToken',
          'upsert:parentA:tok-1',
          'deleteToken',
          'currentToken',
          'upsert:parentB:tok-2',
        ]);
        expect(app.activeUid, 'parentB');
        expect(await persisted(), isEmpty);
      },
    );

    test('a direct account switch while offline defers the new account and '
        'keeps the previous one pending for the next start', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      net.online = false;
      log.clear();

      await app.onSignedIn('parentB');
      expect(log, ['deleteToken']);
      expect(log.any((e) => e.startsWith('disable:')), isFalse);
      expect(await persisted(), {'parentA'});

      net.online = true;
      log.clear();
      await launch().onSignedIn('parentB');
      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test('signing the same account in again is a no-op', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      await app.onSignedIn('parentA');

      expect(log, ['currentToken', 'upsert:parentA:tok-1']);
      expect(await persisted(), isEmpty);
    });
  });

  group('offline direct account switch A -> B', () {
    const retry = [Duration(milliseconds: 20)];

    Future<void> settle([int ms = 150]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    Future<void> drainQueue() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<FcmTokenRegistrar> offlineSwitch({
      List<Duration> retryDelays = const [],
    }) async {
      final app = launch(retryDelays: retryDelays);
      await app.onSignedIn('parentA');
      net.online = false;
      log.clear();
      await app.onSignedIn('parentB');
      return app;
    }

    test('1. switching offline does not register B with the shared token, '
        'keeps only A pending, and never writes A\'s record under B or B '
        'into the pending set', () async {
      final app = await offlineSwitch();

      expect(log, ['deleteToken']);
      expect(log.any((e) => e.startsWith('disable:')), isFalse);
      expect(await persisted(), {'parentA'});
      expect(app.activeUid, 'parentB');
    });

    test('2. killed mid-switch and restarted still offline: A stays pending, '
        'nothing is written for A or B', () async {
      await offlineSwitch();

      log.clear();
      await launch().onSignedIn('parentB');

      expect(log, ['deleteToken']);
      expect(await persisted(), {'parentA'});
    });

    test('reconnecting while B stays signed in (no restart) deletes the shared '
        'token, re-registers B with the new one and clears A', () async {
      final app = await offlineSwitch(retryDelays: retry);

      net.online = true;
      log.clear();
      await settle();

      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(_Messaging.generation, 2);
      expect(await persisted(), isEmpty);
      expect(app.activeUid, 'parentB');
    });

    test('3. reconnecting while signed out deletes the token, registers '
        'nobody and clears the record', () async {
      final app = launch(retryDelays: retry);
      await app.onSignedIn('parentA');
      net.online = false;
      expect(await app.revokeBeforeSignOut(), DeviceRevocation.unconfirmed);

      net.online = true;
      log.clear();
      await settle();

      expect(log, ['deleteToken']);
      expect(await persisted(), isEmpty);
      expect(app.activeUid, isNull);
    });

    test('while still offline, retries back off and never clear the record '
        'without a confirmed deletion', () async {
      final app = launch(
        retryDelays: const [Duration(milliseconds: 20), Duration(hours: 1)],
      );
      await app.onSignedIn('parentA');
      net.online = false;
      log.clear();
      await app.onSignedIn('parentB');
      await settle();

      expect(log.where((e) => e == 'deleteToken'), hasLength(2));
      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);
      expect(await persisted(), {'parentA'});
    });

    test('a retry whose deletion finishes after B signed out never registers '
        'B again', () async {
      final app = launch(
        retryDelays: retry,
        tokenDeletionTimeout: const Duration(seconds: 1),
      );
      await app.onSignedIn('parentA');
      net.online = false;
      await app.onSignedIn('parentB');

      net
        ..online = true
        ..deleteGate = Completer<void>();
      log.clear();
      await settle(60);
      expect(log, ['deleteToken'], reason: 'retry running');

      final revoking = app.revokeBeforeSignOut();
      net.deleteGate!.complete();
      expect(await revoking, DeviceRevocation.confirmed);
      await settle(60);

      expect(log, isNot(contains('currentToken')));
      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);
      expect(app.activeUid, isNull);
      expect(await persisted(), isEmpty);
    });

    test('4. B signing in before A\'s cleanup completes waits for it and '
        'registers only the post-deletion token', () async {
      await offlineLogout('parentA');
      net.online = true;
      final app = launch(tokenDeletionTimeout: Duration.zero);
      net.deleteGate = Completer<void>();
      await app.onSignedOut();

      final signingIn = app.onSignedIn('parentB');
      await drainQueue();
      expect(log, ['deleteToken']);

      net.deleteGate!.complete();
      await signingIn;
      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test('5. the same account after an interrupted logout drops only its own '
        'record and keeps another account\'s', () async {
      await offlineLogout('parentC');
      await offlineLogout('parentA');
      expect(await persisted(), {'parentA', 'parentC'});

      await launch().onSignedIn('parentA');
      expect(await persisted(), {'parentC'});

      net.online = true;
      log.clear();
      await launch().onSignedIn('parentA');
      expect(log, ['deleteToken', 'currentToken', 'upsert:parentA:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test('7. repeated offline logout calls keep exactly one record for the '
        'account and never invent entries', () async {
      final app = launch();
      await app.onSignedIn('parentA');
      net.online = false;

      expect(await app.revokeBeforeSignOut(), DeviceRevocation.unconfirmed);
      expect(await app.revokeBeforeSignOut(), DeviceRevocation.notRegistered);
      await app.onSignedOut();
      await app.onSignedOut();

      expect(await persisted(), {'parentA'});
      expect(log.where((e) => e == 'disable:parentA'), hasLength(1));
    });
  });

  group('retry lifecycle', () {
    Future<void> settle([int ms = 150]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    test('a retry deletion that outlives its timeout still re-registers B '
        'when it completes, without another rotation', () async {
      final app = launch(
        retryDelays: const [Duration(milliseconds: 20), Duration(hours: 1)],
      );
      await app.onSignedIn('parentA');
      net.online = false;
      await app.onSignedIn('parentB');

      net
        ..online = true
        ..deleteGate = Completer<void>();
      log.clear();
      await settle(100);
      expect(log, ['deleteToken'], reason: 'retry timed out, still running');
      expect(await persisted(), {'parentA'});

      net.deleteGate!.complete();
      await settle(60);

      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(_Messaging.generation, 2);
      expect(await persisted(), isEmpty);
    });

    test('only one retry runs at a time: a hanging deletion arms no further '
        'timers and never overlaps another deletion', () async {
      final app = launch(
        retryDelays: const [Duration(milliseconds: 10)],
        tokenDeletionTimeout: const Duration(seconds: 1),
      );
      await app.onSignedIn('parentA');
      net.online = false;
      await app.onSignedIn('parentB');

      net
        ..online = true
        ..deleteGate = Completer<void>();
      log.clear();
      await settle(200);
      expect(log, ['deleteToken']);

      net.deleteGate!.complete();
      await settle(60);
      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test('repeated signed-out transitions arm a single timer', () async {
      final app = launch(
        retryDelays: const [Duration(milliseconds: 20), Duration(hours: 1)],
      );
      await app.onSignedIn('parentA');
      net.online = false;
      await app.revokeBeforeSignOut();
      for (var i = 0; i < 5; i++) {
        await app.onSignedOut();
      }

      net.online = true;
      log.clear();
      await settle();

      expect(log, ['deleteToken']);
      expect(await persisted(), isEmpty);
    });

    test('a failed retry keeps the record; the next one succeeds and '
        'registers the deferred account', () async {
      final app = launch(
        retryDelays: const [
          Duration(milliseconds: 20),
          Duration(milliseconds: 60),
        ],
      );
      await app.onSignedIn('parentA');
      net.online = false;
      await app.onSignedIn('parentB');
      log.clear();

      await settle(40);
      expect(log, ['deleteToken']);
      expect(await persisted(), {'parentA'});

      net.online = true;
      await settle();
      expect(log, [
        'deleteToken',
        'deleteToken',
        'currentToken',
        'upsert:parentB:tok-2',
      ]);
      expect(await persisted(), isEmpty);
    });

    test('a recreated service (restart) with persisted state recovers on its '
        'own retry while the account stays signed in', () async {
      final first = launch();
      await first.onSignedIn('parentA');
      net.online = false;
      await first.onSignedIn('parentB');
      await first.dispose();

      final second = launch(retryDelays: const [Duration(milliseconds: 20)]);
      await second.onSignedIn('parentB');
      net.online = true;
      log.clear();
      await settle();

      expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
      expect(await persisted(), isEmpty);
    });

    test(
      'dispose cancels the armed timer and makes later work a no-op',
      () async {
        final app = launch(retryDelays: const [Duration(milliseconds: 20)]);
        await app.onSignedIn('parentA');
        net.online = false;
        await app.onSignedIn('parentB');

        await app.dispose();
        net.online = true;
        log.clear();
        await settle();
        await app.onSignedIn('parentC');

        expect(log, isEmpty);
        expect(await persisted(), {'parentA'}, reason: 'kept for next start');
      },
    );

    test('a getToken failure never escapes sign-in; a later refresh is '
        'registered for the same session only', () async {
      final app = launch();
      net.tokenThrows = true;
      await app.onSignedIn('parentA');
      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);

      messagings.last.refreshes.add('tok-refreshed');
      await settle(20);
      expect(log.last, 'upsert:parentA:tok-refreshed');

      await app.revokeBeforeSignOut();
      log.clear();
      messagings.last.refreshes.add('tok-late');
      await settle(20);
      expect(log.where((e) => e.startsWith('upsert:')), isEmpty);
    });
  });
}
