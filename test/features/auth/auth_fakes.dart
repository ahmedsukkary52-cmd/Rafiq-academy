import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal Firebase fakes for the Auth datasource: only the calls the
/// datasource makes are implemented; anything else throws via [Fake].
class FakeUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  FakeUser(this.uid, {this.email});
}

class FakeCredential extends Fake implements UserCredential {
  @override
  final User? user;

  FakeCredential(this.user);
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  /// uid -> password for accounts that exist in Firebase Auth.
  final Map<String, String> passwords;
  final Map<String, String> emailToUid;
  final _authState = StreamController<User?>.broadcast();

  User? _current;
  String? signInErrorCode;
  String? resetErrorCode;
  bool restoreFromStream = false;
  User? restoredUser;
  int signOutCalls = 0;
  final List<String> resetEmails = [];
  @override
  String? languageCode;

  FakeFirebaseAuth({
    this.passwords = const {},
    this.emailToUid = const {},
    User? current,
  }) : _current = current;

  @override
  User? get currentUser => _current;

  @override
  Stream<User?> authStateChanges() async* {
    if (restoreFromStream) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      _current = restoredUser;
    }
    yield _current;
    yield* _authState.stream;
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final code = signInErrorCode;
    if (code != null) throw FirebaseAuthException(code: code);
    final uid = emailToUid[email];
    if (uid == null) throw FirebaseAuthException(code: 'user-not-found');
    if (passwords[uid] != password) {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    _current = FakeUser(uid, email: email);
    _authState.add(_current);
    return FakeCredential(_current);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _authState.add(null);
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    this.languageCode = languageCode;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final code = resetErrorCode;
    if (code != null) throw FirebaseAuthException(code: code);
    resetEmails.add(email);
  }
}

// ignore: subtype_of_sealed_class
class FakeSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  FakeSnapshot(this.id, this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

// ignore: subtype_of_sealed_class
class FakeDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final FakeFirestore store;
  @override
  final String path;

  FakeDocRef(this.store, this.path);

  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final code = store.getErrorCode;
    if (code != null) {
      throw FirebaseException(plugin: 'cloud_firestore', code: code);
    }
    return FakeSnapshot(id, store.docs[path]);
  }
}

// ignore: subtype_of_sealed_class
class FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final FakeFirestore store;
  final String name;

  FakeCollection(this.store, this.name);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      FakeDocRef(store, '$name/$path');
}

class FakeFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> docs;
  String? getErrorCode;

  FakeFirestore([Map<String, Map<String, dynamic>>? docs]) : docs = docs ?? {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      FakeCollection(this, collectionPath);
}
