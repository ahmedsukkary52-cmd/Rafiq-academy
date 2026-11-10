import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/domain/auth_error_messages.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/domain/repositories/auth_repository.dart';
import 'package:rafiq_academy/features/auth/domain/services/sign_out_preparation.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/login_with_email_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/logout_usecase.dart';
import 'package:rafiq_academy/features/auth/domain/usecases/watch_auth_session_usecase.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_device_id_provider.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_pending_revocation_store.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_sign_out_preparation.dart';
import 'package:rafiq_academy/features/notifications/data/services/fcm_token_registrar.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/fcm_device_registration.dart';
import 'package:rafiq_academy/features/notifications/domain/repositories/fcm_token_repository.dart';
import 'package:rafiq_academy/features/notifications/domain/services/fcm_messaging_port.dart';
import 'package:rafiq_academy/shared/domain/fcm_token_contract.dart';

final _parentA = UserEntity(
  uid: 'parentA',
  name: 'ولي أمر',
  role: 'parent',
  isActive: true,
  createdAt: DateTime(2026),
);

class _Messaging implements FcmMessagingPort {
  _Messaging(this.log);

  final List<String> log;
  int generation = 1;
  bool deleteFails = false;
  Completer<void>? deleteGate;
  Completer<bool>? permissionGate;
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<String?> currentToken() async {
    log.add('currentToken');
    return 'tok-$generation';
  }

  @override
  Future<void> deleteToken() async {
    log.add('deleteToken');
    final gate = deleteGate;
    if (gate != null) await gate.future;
    if (deleteFails) throw Exception('offline');
    generation++;
  }

  @override
  String platformKey() => FcmTokenContract.platformAndroid;

  @override
  Future<bool> requestPermission() async {
    final gate = permissionGate;
    return gate == null ? true : gate.future;
  }

  @override
  Stream<String> tokenRefreshes() => refreshes.stream;
}

class _DeviceIds implements FcmDeviceIdProvider {
  @override
  Future<String> deviceId() async => 'dev_stable';
}

class _TokenRepository implements FcmTokenRepository {
  _TokenRepository(this.log);

  final List<String> log;
  Either<Failure, Unit> disableResult = const Right(unit);
  bool disableHangs = false;
  final upserts = <({String uid, String token})>[];

  @override
  Future<Either<Failure, Unit>> disableDeviceToken({
    required String uid,
    required String deviceId,
  }) {
    log.add('disable:$uid');
    if (disableHangs) return Completer<Either<Failure, Unit>>().future;
    return Future.value(disableResult);
  }

  @override
  Future<Either<Failure, Unit>> upsertDeviceToken({
    required String uid,
    required FcmDeviceRegistration registration,
  }) async {
    log.add('upsert:$uid:${registration.token}');
    upserts.add((uid: uid, token: registration.token));
    return const Right(unit);
  }
}

class _AuthRepository implements AuthRepository {
  _AuthRepository(this.log);

  final List<String> log;
  Either<Failure, Unit> logoutResult = const Right(unit);
  final session = StreamController<String?>.broadcast();

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      Right(_parentA);

  @override
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  }) async => Right(_parentA);

  @override
  Future<Either<Failure, Unit>> logout() async {
    log.add('signOut');
    if (logoutResult.isRight()) session.add(null);
    return logoutResult;
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async => const Right(unit);

  @override
  Stream<String?> get sessionUidChanges => session.stream;
}

class _MemoryStore implements FcmPendingRevocationStore {
  Set<String> uids = {};

  @override
  Future<Set<String>> read() async => Set.of(uids);

  @override
  Future<void> write(Set<String> next) async => uids = Set.of(next);
}

class _ThrowingPreparation implements SignOutPreparation {
  @override
  Future<DeviceRevocation> beforeSignOut() => throw StateError('boom');

  @override
  Future<void> signOutAborted(String uid) async {}
}

void main() {
  late List<String> log;
  late _Messaging messaging;
  late _TokenRepository tokens;
  late _AuthRepository auth;
  late FcmTokenRegistrar registrar;
  late _MemoryStore store;

  setUp(() {
    log = [];
    store = _MemoryStore();
    messaging = _Messaging(log);
    tokens = _TokenRepository(log);
    auth = _AuthRepository(log);
    registrar = FcmTokenRegistrar(
      messaging: messaging,
      deviceIdProvider: _DeviceIds(),
      repository: tokens,
      pendingRevocations: store,
      revocationTimeout: const Duration(milliseconds: 40),
      tokenDeletionTimeout: const Duration(milliseconds: 40),
      storeTimeout: const Duration(milliseconds: 40),
      queueWaitTimeout: const Duration(milliseconds: 40),
    );
  });

  tearDown(() async {
    await messaging.refreshes.close();
    await auth.session.close();
  });

  AuthBloc buildBloc({SignOutPreparation? preparation}) =>
      AuthBloc(
        loginWithEmail: LoginWithEmailUseCase(auth),
        logout: LogoutUseCase(auth),
        getCurrentUser: GetCurrentUserUseCase(auth),
        watchSession: WatchAuthSessionUseCase(auth),
      )..attachSignOutPreparation(
        preparation ?? FcmSignOutPreparation(() => registrar),
      );

  Future<AuthBloc> signedInBloc({SignOutPreparation? preparation}) async {
    final bloc = buildBloc(preparation: preparation)
      ..add(const CheckAuthStatusEvent());
    await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
    await registrar.onSignedIn(_parentA.uid);
    log.clear();
    return bloc;
  }

  Future<AuthState> logoutAndSettle(AuthBloc bloc) {
    final settled = bloc.stream.firstWhere(
      (s) => s is AuthUnauthenticated || s is AuthLogoutFailure,
    );
    bloc.add(const LogoutEvent());
    return settled.timeout(const Duration(seconds: 2));
  }

  test('without an attached preparation logout behaves as before', () async {
    final bloc = AuthBloc(
      loginWithEmail: LoginWithEmailUseCase(auth),
      logout: LogoutUseCase(auth),
      getCurrentUser: GetCurrentUserUseCase(auth),
      watchSession: WatchAuthSessionUseCase(auth),
    )..add(const CheckAuthStatusEvent());
    await bloc.stream.firstWhere((s) => s is AuthAuthenticated);

    final state = await logoutAndSettle(bloc);

    expect(log, ['signOut']);
    expect(state, const AuthUnauthenticated());
    await bloc.close();
  });

  test('disable is confirmed while still signed in, before sign-out', () async {
    final bloc = await signedInBloc();

    final state = await logoutAndSettle(bloc);

    expect(log, ['disable:parentA', 'signOut']);
    expect(state, const AuthUnauthenticated());
    expect(registrar.activeUid, isNull);
    await bloc.close();
  });

  test('the post-logout signed-out hook writes nothing more', () async {
    final bloc = await signedInBloc();
    await logoutAndSettle(bloc);
    log.clear();

    await registrar.onSignedOut();

    expect(log, isEmpty);
    await bloc.close();
  });

  test('a rejected disable falls back to deleting the FCM token', () async {
    tokens.disableResult = const Left(ServerFailure('denied'));
    final bloc = await signedInBloc();

    final state = await logoutAndSettle(bloc);

    expect(log, ['disable:parentA', 'deleteToken', 'signOut']);
    expect(state, const AuthUnauthenticated());
    await bloc.close();
  });

  test('offline logout signs out but says revocation is unconfirmed', () async {
    tokens.disableResult = const Left(NetworkFailure());
    messaging.deleteFails = true;
    final bloc = await signedInBloc();

    final state = await logoutAndSettle(bloc);

    expect(log, ['disable:parentA', 'deleteToken', 'signOut']);
    expect(
      state,
      const AuthUnauthenticated(
        message: AuthErrorMessages.pushRevocationUnconfirmed,
      ),
    );
    await bloc.close();
  });

  test('hanging network calls are bounded; auth never stays loading', () async {
    tokens.disableHangs = true;
    messaging.deleteGate = Completer<void>();
    final bloc = await signedInBloc();
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    final state = await logoutAndSettle(bloc);

    expect(
      state,
      const AuthUnauthenticated(
        message: AuthErrorMessages.pushRevocationUnconfirmed,
      ),
    );
    expect(states.whereType<AuthLoading>(), isEmpty);
    await sub.cancel();
    await bloc.close();
  });

  test('a preparation error never blocks sign-out', () async {
    final bloc = await signedInBloc(preparation: _ThrowingPreparation());

    final state = await logoutAndSettle(bloc);

    expect(log, ['signOut']);
    expect(
      state,
      const AuthUnauthenticated(
        message: AuthErrorMessages.pushRevocationUnconfirmed,
      ),
    );
    await bloc.close();
  });

  test('a late token refresh after logout is not registered', () async {
    final bloc = await signedInBloc();
    await logoutAndSettle(bloc);

    messaging.refreshes.add('tok-late');
    await Future<void>.delayed(Duration.zero);

    expect(tokens.upserts.where((u) => u.token == 'tok-late'), isEmpty);
    await bloc.close();
  });

  test('next sign-in waits for a still-running token deletion', () async {
    tokens.disableResult = const Left(ServerFailure('denied'));
    final gate = messaging.deleteGate = Completer<void>();
    final bloc = await signedInBloc();
    await logoutAndSettle(bloc);
    log.clear();

    final signIn = registrar.onSignedIn('parentB');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(log, isEmpty);

    gate.complete();
    await signIn;

    expect(log, ['currentToken', 'upsert:parentB:tok-2']);
    await bloc.close();
  });

  test(
    'a sign-in stalled on permission never registers after logout',
    () async {
      final permission = messaging.permissionGate = Completer<bool>();
      final signIn = registrar.onSignedIn('parentA');

      await registrar.revokeBeforeSignOut();
      permission.complete(true);
      await signIn;

      expect(tokens.upserts, isEmpty);
      expect(registrar.activeUid, isNull);
    },
  );

  test('after a confirmed revocation the token is not rotated', () async {
    final bloc = await signedInBloc();
    await logoutAndSettle(bloc);
    log.clear();

    await registrar.onSignedIn('parentB');

    expect(log, ['currentToken', 'upsert:parentB:tok-1']);
    await bloc.close();
  });

  test('a failed sign-out re-registers the still-signed-in user', () async {
    auth.logoutResult = const Left(AuthFailure(AuthErrorMessages.logoutFailed));
    final bloc = await signedInBloc();

    final state = await logoutAndSettle(bloc);
    await Future<void>.delayed(Duration.zero);

    expect(state, isA<AuthLogoutFailure>());
    expect(registrar.activeUid, _parentA.uid);
    expect(log, [
      'disable:parentA',
      'signOut',
      'currentToken',
      'upsert:parentA:tok-1',
    ]);
    expect(store.uids, isEmpty);
    await bloc.close();
  });

  test('an unconfirmed logout keeps a durable uid-only recovery record, and '
      'the next account gets a fresh token before registering', () async {
    tokens.disableResult = const Left(NetworkFailure());
    messaging.deleteFails = true;
    final bloc = await signedInBloc();
    await logoutAndSettle(bloc);

    expect(store.uids, {'parentA'});

    messaging.deleteFails = false;
    log.clear();
    await registrar.onSignedIn('parentB');

    expect(log, ['deleteToken', 'currentToken', 'upsert:parentB:tok-2']);
    expect(tokens.upserts.where((u) => u.uid == 'parentA'), hasLength(1));
    expect(store.uids, isEmpty);
    await bloc.close();
  });

  test('switching accounts after a confirmed logout never rotates or '
      'reuses the previous registration', () async {
    final bloc = await signedInBloc();
    await logoutAndSettle(bloc);
    log.clear();

    await registrar.onSignedIn('parentB');

    expect(log, ['currentToken', 'upsert:parentB:tok-1']);
    expect(registrar.activeUid, 'parentB');
    expect(store.uids, isEmpty);
    await bloc.close();
  });
}
