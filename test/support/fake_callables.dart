import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/network/network_info.dart';

/// Server-side callable error, as surfaced by the Functions SDK.
class FakeFunctionsError extends FirebaseFunctionsException {
  FakeFunctionsError(String code, [String message = 'denied'])
    : super(code: code, message: message);
}

typedef CallableHandler = Object? Function(Object? payload);

/// Records every callable invocation; [handlers] decide the server response
/// (return data, or throw a [FakeFunctionsError]).
class FakeFunctions extends Fake implements FirebaseFunctions {
  final calls = <(String, Object?)>[];
  final handlers = <String, CallableHandler>{};

  List<String> get calledNames => [for (final c in calls) c.$1];

  Object? payloadOf(String name) =>
      calls.lastWhere((c) => c.$1 == name).$2;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable(this, name);
}

class _FakeCallable extends Fake implements HttpsCallable {
  final FakeFunctions owner;
  final String name;

  _FakeCallable(this.owner, this.name);

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.calls.add((name, parameters));
    final handler = owner.handlers[name];
    if (handler == null) {
      throw FakeFunctionsError('not-found', 'no handler for $name');
    }
    return _FakeResult<T>(handler(parameters) as T);
  }
}

class _FakeResult<T> extends Fake implements HttpsCallableResult<T> {
  @override
  final T data;

  _FakeResult(this.data);
}

/// Any direct Firestore/Storage access throws, proving a code path is
/// callable-only.
class UnusedFirestore extends Fake implements FirebaseFirestore {}

class UnusedStorage extends Fake implements FirebaseStorage {}

class FakeNetworkInfo implements NetworkInfo {
  bool connected;

  FakeNetworkInfo({this.connected = true});

  @override
  Future<bool> get isConnected async => connected;
}
