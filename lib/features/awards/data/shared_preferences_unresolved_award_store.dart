import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/unresolved_award_store.dart';

/// Every operation on one key runs alone, in call order, across all store
/// instances of this isolate. This is not a cross-process lock, and a
/// successful write is only as durable as the platform makes it.
@LazySingleton(as: UnresolvedAwardStore)
class SharedPreferencesUnresolvedAwardStore implements UnresolvedAwardStore {
  SharedPreferencesUnresolvedAwardStore({
    @ignoreParam Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  /// The last queued operation per key; removed once it is the last to finish.
  static final Map<String, Future<void>> _tails = {};

  @visibleForTesting
  static int get queuedKeyCount => _tails.length;

  /// Queued like a mutation, so it never observes a value whose write may
  /// still be rolled back.
  @override
  Future<String?> read(String key) => _serial(key, () async {
    final prefs = await _preferences();
    return prefs.getString(key);
  });

  @override
  Future<void> write(String key, String record) => _serial(key, () async {
    final prefs = await _preferences();
    final previous = prefs.getString(key);
    var saved = false;
    try {
      saved = await prefs.setString(key, record);
    } catch (_) {
      saved = false;
    }
    if (saved) return;
    // SharedPreferences updates its in-memory cache before the platform
    // write, so a failed write must be undone there to keep reads honest.
    try {
      if (previous == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previous);
      }
    } catch (_) {}
    throw StateError('unresolved award record was not saved');
  });

  @override
  Future<void> remove(String key) => _serial(key, () async {
    final prefs = await _preferences();
    await prefs.remove(key);
  });

  /// Runs [operation] after every earlier operation on [key] has finished,
  /// whether it succeeded or failed. Operations must not call back into this
  /// store for the same key, or they would wait on themselves.
  static Future<T> _serial<T>(String key, Future<T> Function() operation) {
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    _tails[key] = tail;
    return result;
  }
}
