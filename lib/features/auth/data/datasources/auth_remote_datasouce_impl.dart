import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/auth_error_messages.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

const _authRequestTimeout = Duration(seconds: 20);
const _firestoreTimeout = Duration(seconds: 15);
const _sessionRestoreTimeout = Duration(seconds: 10);

@LazySingleton(as: AuthRemoteDatasource)
class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  const AuthRemoteDatasourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final String uid;
    try {
      final credential = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(_authRequestTimeout);
      final signedIn = credential.user?.uid;
      if (signedIn == null) {
        throw const AuthException(AuthErrorMessages.generic);
      }
      uid = signedIn;
    } on TimeoutException {
      throw const AuthException(
        AuthErrorMessages.network,
        reason: AuthErrorReason.network,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMessages.fromAuthCode(e.code);
    }

    // A Firebase identity alone is not an academy account: any profile
    // failure ends the Firebase session so no half-signed-in state remains.
    try {
      return await _loadAuthorizedProfile(uid);
    } on AuthException {
      await _signOutQuietly();
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await firebaseAuth.setLanguageCode('ar');
      await firebaseAuth
          .sendPasswordResetEmail(email: email)
          .timeout(_authRequestTimeout);
    } on TimeoutException {
      throw const AuthException(
        AuthErrorMessages.network,
        reason: AuthErrorReason.network,
      );
    } on FirebaseAuthException catch (e) {
      // Never reveal whether an address is registered.
      if (e.code == 'user-not-found') return;
      throw AuthErrorMessages.fromAuthCode(e.code);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await firebaseAuth.signOut();
    } catch (_) {
      throw const AuthException(AuthErrorMessages.logoutFailed);
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final User? firebaseUser;
    try {
      firebaseUser =
          firebaseAuth.currentUser ??
          await firebaseAuth.authStateChanges().first.timeout(
            _sessionRestoreTimeout,
            onTimeout: () => firebaseAuth.currentUser,
          );
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMessages.fromAuthCode(e.code);
    }
    if (firebaseUser == null) return null;

    try {
      return await _loadAuthorizedProfile(firebaseUser.uid);
    } on AuthException catch (e) {
      // Network problems keep the session for a retry; account problems
      // (missing / disabled / unknown role) end it.
      if (e.reason != AuthErrorReason.network) await _signOutQuietly();
      rethrow;
    }
  }

  @override
  Stream<String?> get sessionUidChanges =>
      firebaseAuth.authStateChanges().map((user) => user?.uid);

  /// Loads `users/{uid}` and fails closed unless it is an active profile with
  /// a known academy role. Role comes only from the server-written profile.
  Future<UserModel> _loadAuthorizedProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get()
          .timeout(_firestoreTimeout);
    } on TimeoutException {
      throw const AuthException(
        AuthErrorMessages.network,
        reason: AuthErrorReason.network,
      );
    } on FirebaseException catch (e) {
      throw AuthErrorMessages.fromFirestoreCode(e.code);
    }

    if (!doc.exists) {
      throw const AuthException(
        AuthErrorMessages.notProvisioned,
        reason: AuthErrorReason.notProvisioned,
      );
    }

    final UserModel user;
    try {
      user = UserModel.fromFirestore(doc);
    } catch (_) {
      throw const AuthException(
        AuthErrorMessages.notProvisioned,
        reason: AuthErrorReason.notProvisioned,
      );
    }
    if (!AppRoles.all.contains(user.role)) {
      throw const AuthException(
        AuthErrorMessages.notProvisioned,
        reason: AuthErrorReason.notProvisioned,
      );
    }
    if (!user.isActive) {
      throw const AuthException(
        AuthErrorMessages.disabled,
        reason: AuthErrorReason.disabled,
      );
    }
    final authUser = firebaseAuth.currentUser;
    return user.withAuthEmail(authUser?.uid == uid ? authUser?.email : null);
  }

  Future<void> _signOutQuietly() async {
    try {
      await firebaseAuth.signOut();
    } catch (_) {}
  }
}
