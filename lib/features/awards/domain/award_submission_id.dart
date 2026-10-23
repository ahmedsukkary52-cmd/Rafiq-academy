import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'unresolved_award_store.dart';

/// Why a restored unresolved request cannot simply be resent.
enum AwardRecoveryProblem {
  /// The saved record is corrupt, from an unsupported version, or unreadable.
  unreadable,

  /// The request carried an image, and images are not kept across restarts.
  imageNotRestorable,
}

/// The form and account an award operation belongs to. Records of one scope
/// are never visible to another.
class AwardOperationScope {
  const AwardOperationScope({
    required this.operation,
    required this.form,
    required this.uid,
  });

  static const String grantAward = 'grantAward';
  static const String issueAchievement = 'issueAchievement';

  final String operation;
  final String form;
  final String uid;

  String get storageKey => 'awards.unresolved.$operation.$form.$uid';
}

/// Converts one form's submitted payload to and from its saved JSON.
abstract class AwardPayloadCodec<T extends Object> {
  const AwardPayloadCodec();

  /// The operation id carried inside [payload].
  String idOf(T payload);

  Map<String, Object?> encode(T payload);

  /// Throws when [json] is not a complete payload.
  T decode(Map<String, Object?> json);

  /// Set when the saved payload cannot reproduce the original request.
  AwardRecoveryProblem? problemOf(Map<String, Object?> json) => null;
}

enum AwardPrepareStatus {
  /// The record is saved; send [AwardPreparation.payload] now.
  ready,

  /// Another submission for this form is being prepared or awaits its
  /// outcome; nothing was created.
  busy,

  /// An unresolved or unreadable request must be retried or abandoned first.
  blocked,

  /// The request could not be saved on this device, so it must not be sent.
  /// Nothing was created; preparing the same payload again reuses the id.
  localSaveFailed,
}

class AwardPreparation<T extends Object> {
  const AwardPreparation(this.status, [this.payload]);

  final AwardPrepareStatus status;
  final T? payload;
}

/// The exact request sent under [id], kept while its outcome is unknown.
class PendingAwardRequest<T extends Object> {
  const PendingAwardRequest(
    this.id,
    this.fingerprint,
    this.payload, {
    this.problem,
  });

  final String id;

  /// Null for a request restored from disk; it can only be resent as-is.
  final String? fingerprint;

  /// The entity/params object that was submitted, resent as-is on retry.
  final T payload;

  final AwardRecoveryProblem? problem;
}

/// Holds the operation id for one logical award submission (`grantAward` or
/// `issueAchievement`).
///
/// Retrying the same payload reuses the id, so the server replays the
/// earlier operation instead of crediting stars twice. A changed payload is a
/// new submission and gets a new id, but only while nothing is unresolved:
/// after an unconfirmed outcome ([markUnresolved]) the id and the exact
/// payload are pinned, [idFor] refuses a different payload, and only
/// [complete] (confirmed success) or [abandon] (explicit user choice) release
/// them. Abandoning does not cancel anything on the server.
///
/// A [AwardSubmissionId.durable] instance submits only through [prepare]: it
/// admits one submission at a time per form and account, and returns a
/// payload to send only after the request is durably saved in its
/// [UnresolvedAwardStore]. The record is kept until one of those two
/// releases (or a confirmed rejection), so an app restart restores it
/// instead of minting a new id. A record that cannot be read back blocks new
/// submissions ([recoveryProblem]) until it is explicitly abandoned. Within
/// one app session the exact submitted object is reused, image included;
/// after a restart an image request cannot be rebuilt and is not resent.
class AwardSubmissionId<T extends Object> {
  AwardSubmissionId({Random? random})
    : _random = random ?? Random.secure(),
      scope = null,
      _store = null,
      _codec = null,
      _restored = true;

  AwardSubmissionId.durable({
    required AwardOperationScope this.scope,
    required UnresolvedAwardStore store,
    required AwardPayloadCodec<T> codec,
    Random? random,
  }) : _random = random ?? Random.secure(),
       _store = store,
       _codec = codec,
       _restored = false;

  static const int recordVersion = 1;
  static const String _inFlightStatus = 'inFlight';
  static const String _unresolvedStatus = 'unresolved';

  static final RegExp _pattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const int _length = 20;

  /// Exact submitted objects of this app session, by storage key.
  static final Map<String, PendingAwardRequest<Object>> _session = {};

  /// Storage keys with a [prepare] in progress, across all instances.
  static final Set<String> _preparingKeys = {};

  final Random _random;
  final AwardOperationScope? scope;
  final UnresolvedAwardStore? _store;
  final AwardPayloadCodec<T>? _codec;
  bool _restored;
  AwardRecoveryProblem? _problem;
  String? _id;
  String? _fingerprint;
  PendingAwardRequest<T>? _lastSubmitted;
  PendingAwardRequest<T>? _pinned;
  bool _preparing = false;

  /// Prepared and handed over for sending; its outcome is not reported yet.
  PendingAwardRequest<T>? _inFlight;

  /// Matches the server's `awardId` validation.
  static bool isValid(String id) => _pattern.hasMatch(id);

  /// Forgets this session's in-memory copies, as an app restart would.
  @visibleForTesting
  static void clearUnresolvedRegistry() {
    _session.clear();
    _preparingKeys.clear();
  }

  /// The request whose outcome is unknown, if any.
  PendingAwardRequest<T>? get unresolved => _pinned;

  bool get isUnresolved => _pinned != null;

  bool get isRestored => _restored;

  AwardRecoveryProblem? get recoveryProblem => _problem ?? _pinned?.problem;

  bool get isPreparing => _preparing;

  /// True until [restore] finishes, while a submission is being prepared or
  /// awaits its outcome, and while anything is unresolved or unreadable.
  bool get blocksNewSubmission =>
      !_restored ||
      _preparing ||
      _inFlight != null ||
      _pinned != null ||
      _problem != null;

  /// Whether the pinned request can be resent exactly.
  bool get canRetry => _pinned != null && recoveryProblem == null;

  /// Loads an unresolved request saved earlier for this [scope].
  Future<void> restore() async {
    if (_restored) return;
    final key = scope!.storageKey;
    final cached = _session[key];
    if (cached is PendingAwardRequest<T>) {
      _pinned = cached;
      _restored = true;
      return;
    }
    try {
      final raw = await _store!.read(key);
      if (raw != null) _pinned = _decode(raw);
    } catch (_) {
      _problem = AwardRecoveryProblem.unreadable;
    }
    _restored = true;
  }

  String idFor(Iterable<Object?> payload) {
    if (!_restored || _problem != null) {
      throw StateError('Saved award requests are not restored or unreadable.');
    }
    final fingerprint = payload.map((v) => '$v').join('\u0001');
    final pinned = _pinned;
    if (pinned != null) {
      if (pinned.fingerprint != fingerprint) {
        throw StateError(
          'An unresolved award request is pinned; retry it or abandon it.',
        );
      }
      return pinned.id;
    }
    if (_id == null || _fingerprint != fingerprint) {
      _id = List.generate(
        _length,
        (_) => _alphabet[_random.nextInt(_alphabet.length)],
      ).join();
      _fingerprint = fingerprint;
    }
    return _id!;
  }

  /// Non-durable instances only: records the exact [payload] sent under the
  /// id last returned by [idFor]. Durable instances submit via [prepare].
  void submitted(T payload) {
    assert(_store == null, 'durable submissions must use prepare()');
    final id = _id;
    final fingerprint = _fingerprint;
    if (id == null || fingerprint == null) return;
    _lastSubmitted = PendingAwardRequest<T>(id, fingerprint, payload);
  }

  /// Starts one submission: assigns the id for [fingerprint], builds the
  /// payload with it, and saves the request durably. Only a
  /// [AwardPrepareStatus.ready] result may be sent; until its outcome is
  /// reported ([complete], [markUnresolved], [confirmedFailure]) every other
  /// call returns [AwardPrepareStatus.busy]. The guard is taken before the
  /// first await, so overlapping calls never create a second operation.
  Future<AwardPreparation<T>> prepare(
    Iterable<Object?> fingerprint,
    T Function(String id) build,
  ) async {
    final key = scope?.storageKey;
    if (_preparing ||
        _inFlight != null ||
        (key != null && _preparingKeys.contains(key))) {
      return AwardPreparation<T>(AwardPrepareStatus.busy);
    }
    if (blocksNewSubmission) {
      return AwardPreparation<T>(AwardPrepareStatus.blocked);
    }
    _preparing = true;
    if (key != null) _preparingKeys.add(key);
    try {
      final id = idFor(fingerprint);
      final request = PendingAwardRequest<T>(id, _fingerprint, build(id));
      final status = await _saveInitial(request);
      if (status != AwardPrepareStatus.ready) {
        return AwardPreparation<T>(status);
      }
      _inFlight = request;
      _lastSubmitted = request;
      return AwardPreparation<T>(AwardPrepareStatus.ready, request.payload);
    } finally {
      _preparing = false;
      if (key != null) _preparingKeys.remove(key);
    }
  }

  /// Pins the request whose outcome is unknown. Its in-flight record is
  /// already durable, so updating its status is best-effort.
  Future<void> markUnresolved() async {
    if (_pinned != null) return;
    final last = _inFlight ?? _lastSubmitted;
    if (last == null) return;
    _inFlight = null;
    _pinned = last;
    await _save(last, _unresolvedStatus);
  }

  /// The server rejected the request, so nothing was committed. A pinned
  /// request stays pinned: its earlier attempt may still have committed.
  Future<void> confirmedFailure() async {
    if (_pinned != null) return;
    if (_inFlight == null && _lastSubmitted == null) return;
    _inFlight = null;
    _lastSubmitted = null;
    await _clear();
  }

  /// After a confirmed success: the next submission is a new operation.
  Future<void> complete() => _release();

  /// The user explicitly gives up on an unresolved or unreadable request.
  /// The server may already have committed it.
  Future<void> abandon() => _release();

  Future<void> _release() async {
    _id = null;
    _fingerprint = null;
    _lastSubmitted = null;
    _inFlight = null;
    _pinned = null;
    _problem = null;
    await _clear();
  }

  PendingAwardRequest<T> _decode(String raw) {
    final scope = this.scope!;
    final codec = _codec!;
    final record = jsonDecode(raw);
    if (record is! Map<String, Object?>) {
      throw const FormatException('award record');
    }
    final id = record['id'];
    final payload = record['payload'];
    final status = record['status'];
    if (record['v'] != recordVersion ||
        record['operation'] != scope.operation ||
        record['form'] != scope.form ||
        record['uid'] != scope.uid ||
        (status != _inFlightStatus && status != _unresolvedStatus) ||
        id is! String ||
        !isValid(id) ||
        payload is! Map<String, Object?>) {
      throw const FormatException('award record');
    }
    final decoded = codec.decode(payload);
    if (codec.idOf(decoded) != id) {
      throw const FormatException('award record id');
    }
    return PendingAwardRequest<T>(
      id,
      null,
      decoded,
      problem: codec.problemOf(payload),
    );
  }

  /// Saves the first record of a new submission. Never replaces an existing
  /// record: one found here (written by another form instance) is adopted
  /// as the unresolved request instead. Any read, encode or write failure
  /// means nothing may be sent.
  Future<AwardPrepareStatus> _saveInitial(PendingAwardRequest<T> request) async {
    final scope = this.scope;
    final store = _store;
    if (scope == null || store == null) return AwardPrepareStatus.ready;
    final key = scope.storageKey;
    final active = _session[key];
    if (active != null) {
      if (active is PendingAwardRequest<T>) _pinned = active;
      return AwardPrepareStatus.blocked;
    }
    final String? existing;
    try {
      existing = await store.read(key);
    } catch (_) {
      return AwardPrepareStatus.localSaveFailed;
    }
    if (existing != null) {
      try {
        _pinned = _decode(existing);
      } catch (_) {
        _problem = AwardRecoveryProblem.unreadable;
      }
      return AwardPrepareStatus.blocked;
    }
    try {
      await store.write(key, _encode(request, _inFlightStatus));
    } catch (_) {
      return AwardPrepareStatus.localSaveFailed;
    }
    _session[key] = request;
    return AwardPrepareStatus.ready;
  }

  /// Updates an existing record. Best-effort: only used once the in-flight
  /// record is durable, which already restores the request after a restart.
  Future<void> _save(PendingAwardRequest<T> request, String status) async {
    final scope = this.scope;
    final store = _store;
    if (scope == null || store == null) return;
    _session[scope.storageKey] = request;
    try {
      await store.write(scope.storageKey, _encode(request, status));
    } catch (_) {
      // The in-flight record on disk and the in-memory copy still guard it.
    }
  }

  String _encode(PendingAwardRequest<T> request, String status) {
    final scope = this.scope!;
    return jsonEncode({
      'v': recordVersion,
      'operation': scope.operation,
      'form': scope.form,
      'uid': scope.uid,
      'id': request.id,
      'status': status,
      'payload': _codec!.encode(request.payload),
    });
  }

  Future<void> _clear() async {
    final scope = this.scope;
    final store = _store;
    if (scope == null || store == null) return;
    _session.remove(scope.storageKey);
    try {
      await store.remove(scope.storageKey);
    } catch (_) {
      // A record left behind restores as unresolved; its retry replays.
    }
  }
}
