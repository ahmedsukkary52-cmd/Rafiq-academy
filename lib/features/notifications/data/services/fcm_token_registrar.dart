import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../auth/domain/services/sign_out_preparation.dart';
import '../../domain/entities/fcm_device_registration.dart';
import '../../domain/repositories/fcm_token_repository.dart';
import '../../domain/services/fcm_messaging_port.dart';
import 'fcm_device_id_provider.dart';
import 'fcm_pending_revocation_store.dart';

/// Single FCM token lifecycle owner for the whole app (C11 / WA-13).
///
/// Wired once from the root auth listener — screens must not register tokens
/// themselves. Registration is idempotent: the same stable device id is
/// upserted on sign-in and on every token refresh.
///
/// H2: an account whose device record could not be confirmed disabled at
/// sign-out is kept in [pendingRevocations] until either the server confirms
/// the disable or this install's token is deleted at FCM (which makes every
/// record holding it undeliverable). Rules only let an account write its own
/// records, so another account can never disable them — recovery for the
/// previous account is token deletion, attempted before the next account
/// registers and on every signed-out start.
///
/// A-1: public operations run one at a time, in call order, so a token
/// deletion can never interleave with a registration. Sign-in and refresh
/// registration can wait without bound (permission prompt, an offline
/// upsert), so the next operation waits for them at most [queueWaitTimeout].
/// Ending a session bumps [_session] and [_signOutEpoch] at call time: a
/// stalled sign-in stops at its next check, and a sign-in requested before
/// the sign-out never starts afterwards.
///
/// A timeout ends the wait, not the SDK call: a token deletion can still
/// complete after its caller gave up. Deletions are therefore tracked
/// ([_deletion]) and chained, and sign-in waits for the last one to finish
/// before it fetches a token, so a late deletion can never invalidate a token
/// registered by a newer session.
@lazySingleton
class FcmTokenRegistrar {
  final FcmMessagingPort messaging;
  final FcmDeviceIdProvider deviceIdProvider;
  final FcmTokenRepository repository;
  final FcmPendingRevocationStore pendingRevocations;
  final Duration revocationTimeout;
  final Duration tokenDeletionTimeout;
  final Duration storeTimeout;
  final Duration queueWaitTimeout;

  /// Back-off between in-process recovery attempts while [pendingRevocations]
  /// is non-empty; the last delay repeats. Without these, a device that comes
  /// back online without restarting would keep the previous account's record
  /// deliverable until the next start or sign-in.
  final List<Duration> pendingRetryDelays;

  FcmTokenRegistrar({
    required this.messaging,
    required this.deviceIdProvider,
    required this.repository,
    @ignoreParam
    this.pendingRevocations =
        const SharedPreferencesFcmPendingRevocationStore(),
    @ignoreParam this.revocationTimeout = const Duration(seconds: 8),
    @ignoreParam this.tokenDeletionTimeout = const Duration(seconds: 5),
    @ignoreParam this.storeTimeout = const Duration(seconds: 2),
    @ignoreParam this.queueWaitTimeout = const Duration(seconds: 3),
    @ignoreParam
    this.pendingRetryDelays = const [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ],
  });

  String? _activeUid;
  StreamSubscription<String>? _refreshSubscription;

  /// In-memory mirror of the durable set; still authoritative for this
  /// process if the store cannot be read or written.
  final Set<String> _pending = {};
  bool _pendingLoaded = false;

  Future<void> _tail = Future.value();
  bool _tailUnbounded = false;
  int _session = 0;
  int _signOutEpoch = 0;
  _TokenDeletion? _deletion;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _retryInFlight = false;
  bool _disposed = false;

  /// Session whose owner granted notification permission; only that session
  /// may be registered later by a recovery retry.
  int _permittedSession = -1;

  String? get activeUid => _activeUid;

  /// Runs [op] after the previously queued operation. Never waits for an
  /// [unbounded] predecessor longer than [queueWaitTimeout].
  Future<T> _serialized<T>(Future<T> Function() op, {bool unbounded = false}) {
    final previous = _tail;
    final wait = _tailUnbounded
        ? previous.timeout(queueWaitTimeout, onTimeout: () {})
        : previous;
    final result = wait.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    _tailUnbounded = unbounded;
    return result;
  }

  void _endSession() {
    _session++;
    _signOutEpoch++;
  }

  Future<void> onSignedIn(String uid) {
    final next = uid.trim();
    if (next.isEmpty || _disposed) return Future.value();
    final epoch = _signOutEpoch;
    return _serialized(() => _signIn(next, epoch), unbounded: true);
  }

  Future<void> _signIn(String next, int epoch) async {
    if (_signOutEpoch != epoch) return;
    final previous = _activeUid;
    if (previous == next) return;

    _activeUid = next;
    final session = ++_session;
    bool current() => _session == session && _activeUid == next;
    await _stopRefreshWatch();
    if (!current()) return;

    // A direct account switch never went through sign-out, so the previous
    // account's record still holds this token and only token deletion (below)
    // can stop its pushes reaching the new account.
    if (previous != null) await _addPending(previous);
    if (!current()) return;

    await _reconcileBeforeRegister(next, current);
    _schedulePendingRetry();
    if (!current()) return;

    await _awaitDeletion(current);
    if (!current()) return;

    if (!await messaging.requestPermission()) return;
    if (!current()) return;
    _permittedSession = session;

    // While another account's record may still hold this token, registering
    // would make both records deliverable to this device. The retry registers
    // [next] once the token deletion is confirmed.
    if (_blocksRegistration(next)) {
      _schedulePendingRetry();
      return;
    }
    await _registerCurrentToken(next, session);
  }

  bool _blocksRegistration(String uid) => _pending.any((other) => other != uid);

  /// Registers the current token for [uid] and watches refreshes, all guarded
  /// by [session].
  Future<void> _registerCurrentToken(String uid, int session) async {
    bool current() => _session == session && _activeUid == uid;
    await _stopRefreshWatch();
    if (!current()) return;

    String? token;
    try {
      token = await messaging.currentToken();
    } catch (_) {
      // getToken fails while offline on Android; the refresh watch below
      // still registers a token issued later.
    }
    if (!current()) return;
    if (token != null) {
      await _register(uid: uid, token: token, session: session);
    }
    if (!current()) return;

    _refreshSubscription = messaging.tokenRefreshes().listen((refreshed) {
      if (_session != session) return;
      unawaited(
        _serialized(
          () => _register(uid: uid, token: refreshed, session: session),
          unbounded: true,
        ),
      );
    });
  }

  /// Runs while the user is still authenticated, because Rules reject a
  /// disable written after sign-out. The pending entry is persisted first, so
  /// a crash or kill mid-logout still leaves a recovery record. Bounded by
  /// [queueWaitTimeout] + [storeTimeout] + [revocationTimeout] +
  /// [tokenDeletionTimeout].
  Future<DeviceRevocation> revokeBeforeSignOut() {
    _endSession();
    return _serialized(_revokeBeforeSignOut);
  }

  Future<DeviceRevocation> _revokeBeforeSignOut() async {
    final previous = _activeUid;
    _activeUid = null;
    await _stopRefreshWatch();
    if (previous == null) return DeviceRevocation.notRegistered;

    await _addPending(previous);
    if (await _disable(previous)) {
      await _removePending({previous});
      return DeviceRevocation.confirmed;
    }
    if (await _deleteDeviceToken()) return DeviceRevocation.confirmed;
    _schedulePendingRetry();
    return DeviceRevocation.unconfirmed;
  }

  /// Called for every transition to signed-out, including a signed-out app
  /// start. Records a session that ended without [revokeBeforeSignOut] (e.g.
  /// revoked by the server) and retries recovery for anything still pending.
  Future<void> onSignedOut() {
    _endSession();
    return _serialized(_signedOut);
  }

  Future<void> _signedOut() async {
    final previous = _activeUid;
    _activeUid = null;
    await _stopRefreshWatch();

    if (previous != null) {
      await _addPending(previous);
      // Auth is already gone, so Rules normally reject this; it is kept for
      // the rare case the session is still accepted server-side.
      if (await _disable(previous)) await _removePending({previous});
    }
    if ((await _loadPending()).isNotEmpty) await _deleteDeviceToken();
    _schedulePendingRetry();
  }

  /// Arms at most one timer, and never while a retry is queued or running.
  void _schedulePendingRetry() {
    if (_disposed || _pending.isEmpty) return;
    if (_retryTimer != null || _retryInFlight) return;
    if (pendingRetryDelays.isEmpty) return;
    final index = _retryAttempt < pendingRetryDelays.length
        ? _retryAttempt
        : pendingRetryDelays.length - 1;
    _retryTimer = Timer(pendingRetryDelays[index], () {
      _retryTimer = null;
      if (_disposed) return;
      _retryAttempt++;
      _retryInFlight = true;
      unawaited(
        _serialized(_retryPending).whenComplete(() {
          _retryInFlight = false;
          _schedulePendingRetry();
        }),
      );
    });
  }

  /// Deletes the token for everything still pending. Entries are only removed
  /// by a confirmed deletion ([_settle]). A deletion that outlives
  /// [tokenDeletionTimeout] is finished when it completes, because the active
  /// account's registered token is then dead.
  Future<void> _retryPending() async {
    if (_disposed || (await _loadPending()).isEmpty) return;
    final uid = _activeUid;
    final session = _session;

    final deletion = _startDeletion();
    final confirmed = await deletion.result.timeout(
      tokenDeletionTimeout,
      onTimeout: () => false,
    );
    if (confirmed) {
      await _afterRetryDeletion(deletion, uid, session);
    } else if (!deletion.done) {
      unawaited(
        deletion.result.then((ok) async {
          if (!ok || _disposed) return;
          await _serialized(
            () => _afterRetryDeletion(deletion, uid, session),
            unbounded: true,
          );
        }),
      );
    }
  }

  /// Settles [deletion], then registers the new token only for the same,
  /// permitted session and only if no other account is still pending.
  Future<void> _afterRetryDeletion(
    _TokenDeletion deletion,
    String? uid,
    int session,
  ) async {
    await _settle(deletion);
    if (uid == null || _session != session || _activeUid != uid) return;
    if (_permittedSession != session || _blocksRegistration(uid)) return;
    await _registerCurrentToken(uid, session);
  }

  /// Stops the retry timer and refresh watch; queued work becomes a no-op.
  /// The DI singleton lives for the whole process, so only tests and
  /// shutdown call this.
  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _endSession();
    await _stopRefreshWatch();
  }

  /// [uid]'s own pending entry is dropped (the account is back and owns this
  /// device again); any other account's entry requires deleting the token
  /// first so [uid] never registers a token another account still holds.
  /// If deletion fails (offline) [uid] is not registered yet; deletion is
  /// retried in-process ([pendingRetryDelays]) and on the next start or
  /// sign-in, and [uid] is registered after it is confirmed.
  Future<void> _reconcileBeforeRegister(
    String uid,
    bool Function() current,
  ) async {
    final pending = await _loadPending();
    if (pending.isEmpty || !current()) return;
    if (pending.contains(uid)) await _removePending({uid});
    if (!current()) return;
    if (pending.any((other) => other != uid)) {
      await _deleteDeviceToken(current: current);
    }
  }

  /// True only when the server acknowledged the write in time; a queued
  /// offline write is not a confirmation.
  Future<bool> _disable(String uid) async {
    try {
      final deviceId = await deviceIdProvider.deviceId();
      final result = await repository
          .disableDeviceToken(uid: uid, deviceId: deviceId)
          .timeout(revocationTimeout);
      return result.isRight();
    } catch (_) {
      return false;
    }
  }

  /// A deleted token can no longer be delivered to, whichever accounts' records
  /// still hold it, so a confirmed deletion settles every entry pending when
  /// it started. Waits at most [tokenDeletionTimeout]; the deletion itself
  /// keeps running and is settled later by [_awaitDeletion].
  Future<bool> _deleteDeviceToken({bool Function()? current}) async {
    final deletion = _startDeletion();
    final confirmed = await deletion.result.timeout(
      tokenDeletionTimeout,
      onTimeout: () => false,
    );
    if (confirmed && (current?.call() ?? true)) await _settle(deletion);
    return confirmed;
  }

  /// Joins a running deletion that already covers every pending account;
  /// otherwise starts after it, so deletions never overlap.
  _TokenDeletion _startDeletion() {
    final previous = _deletion;
    if (previous != null &&
        !previous.done &&
        previous.covers.containsAll(_pending)) {
      return previous;
    }
    Future<void> run() => Future.sync(messaging.deleteToken);
    final raw = previous == null || previous.done
        ? run()
        : previous.result.then((_) => run());
    final deletion = _TokenDeletion(
      raw.then((_) => true, onError: (Object _) => false),
      Set.of(_pending),
    );
    _deletion = deletion;
    return deletion;
  }

  /// Waits, without a bound, for the last deletion to finish. Only called
  /// from sign-in, which the queue already treats as unbounded.
  Future<void> _awaitDeletion(bool Function() current) async {
    final deletion = _deletion;
    if (deletion == null) return;
    final confirmed = await deletion.result;
    if (!current()) return;
    if (confirmed) {
      await _settle(deletion);
    } else if (identical(_deletion, deletion)) {
      _deletion = null;
    }
  }

  Future<void> _settle(_TokenDeletion deletion) async {
    if (identical(_deletion, deletion)) _deletion = null;
    if (deletion.settled) return;
    deletion.settled = true;
    await _removePending(deletion.covers);
  }

  Future<Set<String>> _loadPending() async {
    if (!_pendingLoaded) {
      try {
        _pending.addAll(await pendingRevocations.read().timeout(storeTimeout));
        _pendingLoaded = true;
      } catch (_) {
        // Unreadable store: keep what this process knows and retry next time.
      }
    }
    return Set.unmodifiable(_pending);
  }

  Future<void> _addPending(String uid) async {
    await _loadPending();
    _pending.add(uid);
    await _persistPending();
  }

  Future<void> _removePending(Set<String> uids) async {
    await _loadPending();
    if (!_pending.any(uids.contains)) return;
    _pending.removeAll(uids);
    if (_pending.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempt = 0;
    }
    await _persistPending();
  }

  Future<void> _persistPending() async {
    // Writing without having read the stored set would drop entries this
    // process never saw.
    await _loadPending();
    if (!_pendingLoaded) return;
    try {
      await pendingRevocations.write(Set.of(_pending)).timeout(storeTimeout);
    } catch (_) {
      // The in-memory set still drives recovery for this process; the next
      // successful write persists it.
    }
  }

  Future<void> _register({
    required String uid,
    required String token,
    required int session,
  }) async {
    final deviceId = await deviceIdProvider.deviceId();
    if (_session != session || _activeUid != uid) return;
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

class _TokenDeletion {
  _TokenDeletion(this.result, this.covers) {
    result.whenComplete(() => done = true);
  }

  /// Completes with whether FCM confirmed the deletion; never errors.
  final Future<bool> result;

  /// Pending accounts whose records held the token being deleted.
  final Set<String> covers;
  bool done = false;
  bool settled = false;
}
