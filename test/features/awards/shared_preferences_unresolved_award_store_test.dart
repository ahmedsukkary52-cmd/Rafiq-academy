import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/data/shared_preferences_unresolved_award_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A platform write whose outcome the test decides.
class _PendingWrite {
  _PendingWrite(this.key, this.label, this.persist);

  final String key;
  final String label;
  final void Function() persist;
  final result = Completer<bool>();
}

/// Mirrors SharedPreferences: the in-memory cache changes when a mutation is
/// called; [disk] changes only when its platform write succeeds.
class _ControlledPrefs extends Fake implements SharedPreferences {
  _ControlledPrefs([Map<String, String> initial = const {}])
    : cache = Map.of(initial),
      disk = Map.of(initial);

  final Map<String, String> cache;
  final Map<String, String> disk;
  final calls = <String>[];
  final pending = <_PendingWrite>[];

  @override
  String? getString(String key) => cache[key];

  @override
  Future<bool> setString(String key, String value) {
    cache[key] = value;
    return _platform(key, 'set $key=$value', () => disk[key] = value);
  }

  @override
  Future<bool> remove(String key) {
    cache.remove(key);
    return _platform(key, 'remove $key', () => disk.remove(key));
  }

  Future<bool> _platform(String key, String label, void Function() persist) {
    calls.add(label);
    final write = _PendingWrite(key, label, persist);
    pending.add(write);
    return write.result.future;
  }

  /// Settles the oldest platform write for [key].
  void finish(String key, {bool ok = true, bool throws = false}) {
    final write = pending.firstWhere((w) => w.key == key);
    pending.remove(write);
    if (throws) {
      write.result.completeError(StateError('platform channel failed'));
    } else {
      if (ok) write.persist();
      write.result.complete(ok);
    }
  }
}

/// Lets every queued microtask and zero-delay continuation run.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _ControlledPrefs prefs;
  late SharedPreferencesUnresolvedAwardStore store;

  SharedPreferencesUnresolvedAwardStore storeFor(_ControlledPrefs p) =>
      SharedPreferencesUnresolvedAwardStore(preferences: () async => p);

  setUp(() {
    prefs = _ControlledPrefs({'k': 'old'});
    store = storeFor(prefs);
  });

  tearDown(() async {
    await _flush();
    expect(prefs.pending, isEmpty, reason: 'every platform write settled');
    expect(SharedPreferencesUnresolvedAwardStore.queuedKeyCount, 0);
  });

  test('A: a remove queued behind a failing write leaves the key absent',
      () async {
    final write = store.write('k', 'new');
    final remove = store.remove('k');
    final writeFailed = expectLater(write, throwsStateError);
    await _flush();
    expect(prefs.calls, ['set k=new'], reason: 'remove waits its turn');

    prefs.finish('k', ok: false);
    await _flush();
    expect(prefs.calls, ['set k=new', 'set k=old']);
    prefs.finish('k');
    await writeFailed;
    await _flush();
    expect(prefs.calls.last, 'remove k');
    prefs.finish('k');
    await remove;

    expect(prefs.cache.containsKey('k'), isFalse);
    expect(prefs.disk.containsKey('k'), isFalse);
  });

  test('B: a write queued after the remove survives the earlier write '
      'failing', () async {
    final write = store.write('k', 'stale');
    final remove = store.remove('k');
    final next = store.write('k', 'next');
    final writeFailed = expectLater(write, throwsStateError);
    await _flush();

    prefs.finish('k', ok: false);
    await _flush();
    prefs.finish('k');
    await writeFailed;
    await _flush();
    prefs.finish('k');
    await remove;
    await _flush();
    prefs.finish('k');
    await next;

    expect(prefs.calls, [
      'set k=stale',
      'set k=old',
      'remove k',
      'set k=next',
    ]);
    expect(prefs.cache['k'], 'next');
    expect(prefs.disk['k'], 'next');
  });

  test('C: a thrown write and a failed rollback do not block later '
      'operations, and each caller sees its own outcome', () async {
    final first = store.write('k', 'a');
    final second = store.write('k', 'b');
    final firstFailed = expectLater(first, throwsStateError);
    await _flush();

    prefs.finish('k', throws: true);
    await _flush();
    expect(prefs.calls.last, 'set k=old');
    prefs.finish('k', ok: false);
    await firstFailed;
    await _flush();
    expect(prefs.calls.last, 'set k=b');
    prefs.finish('k');
    await expectLater(second, completes);

    expect(prefs.cache['k'], 'b');
    expect(prefs.disk['k'], 'b');
  });

  test('D: two store instances over the same preferences share one order',
      () async {
    final other = storeFor(prefs);
    final write = store.write('k', 'new');
    final remove = other.remove('k');
    final writeFailed = expectLater(write, throwsStateError);
    await _flush();
    expect(prefs.calls, ['set k=new']);

    prefs.finish('k', ok: false);
    await _flush();
    prefs.finish('k');
    await writeFailed;
    await _flush();
    prefs.finish('k');
    await remove;

    expect(prefs.calls, ['set k=new', 'set k=old', 'remove k']);
    expect(prefs.disk.containsKey('k'), isFalse);
  });

  test('E: operations on different keys do not wait for each other',
      () async {
    final slow = store.write('k', 'held');
    final fast = store.write('other', 'free');
    await _flush();
    expect(prefs.calls, ['set k=held', 'set other=free']);

    prefs.finish('other');
    await fast;
    expect(prefs.disk['other'], 'free');
    expect(prefs.pending.single.key, 'k');

    prefs.finish('k');
    await slow;
    expect(prefs.disk['k'], 'held');
  });

  test('F: a read waits for earlier writes, never sees a value that is '
      'rolled back, and sees later queued changes in order', () async {
    final write = store.write('k', 'unconfirmed');
    final writeFailed = expectLater(write, throwsStateError);
    String? seen;
    var readDone = false;
    unawaited(
      store.read('k').then((v) {
        seen = v;
        readDone = true;
      }),
    );
    await _flush();
    expect(prefs.cache['k'], 'unconfirmed');
    expect(readDone, isFalse, reason: 'the read is queued behind the write');

    prefs.finish('k', ok: false);
    await _flush();
    prefs.finish('k');
    await writeFailed;
    await _flush();
    expect(readDone, isTrue);
    expect(seen, 'old');

    final remove = store.remove('k');
    final afterRemove = store.read('k');
    await _flush();
    prefs.finish('k');
    await remove;
    expect(await afterRemove, isNull);
  });

  test('G: a rollback finishes before a newer write starts and cannot '
      'overwrite it', () async {
    final failing = store.write('k', 'stale');
    final newer = store.write('k', 'newer');
    final failed = expectLater(failing, throwsStateError);
    await _flush();

    prefs.finish('k', ok: false);
    await _flush();
    expect(prefs.calls, ['set k=stale', 'set k=old'],
        reason: 'the newer write has not begun during the rollback');
    expect(prefs.cache['k'], 'old');
    prefs.finish('k');
    await failed;
    await _flush();
    expect(prefs.calls.last, 'set k=newer');
    prefs.finish('k');
    await newer;

    expect(prefs.cache['k'], 'newer');
    expect(prefs.disk['k'], 'newer');
  });

  test('a finished queue removes its entry without dropping a newer tail',
      () async {
    final first = store.write('k', 'a');
    await _flush();
    expect(SharedPreferencesUnresolvedAwardStore.queuedKeyCount, 1);
    final second = store.write('k', 'b');

    prefs.finish('k');
    await first;
    await _flush();
    expect(SharedPreferencesUnresolvedAwardStore.queuedKeyCount, 1,
        reason: 'the second operation still owns the tail');
    final third = store.write('k', 'c');
    await _flush();
    expect(prefs.calls, ['set k=a', 'set k=b'], reason: 'c waits for b');

    prefs.finish('k');
    await second;
    await _flush();
    prefs.finish('k');
    await third;
    await _flush();
    expect(prefs.calls, ['set k=a', 'set k=b', 'set k=c']);
    expect(SharedPreferencesUnresolvedAwardStore.queuedKeyCount, 0);
  });
}
