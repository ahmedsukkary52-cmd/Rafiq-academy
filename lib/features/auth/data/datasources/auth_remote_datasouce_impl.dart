import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

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
    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) throw const AuthException('فشل تسجيل الدخول');

      return await _fetchUserFromFirestore(uid);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await firebaseAuth.signOut();
    } catch (e) {
      throw const AuthException('فشل تسجيل الخروج');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) return null;
      return await _fetchUserFromFirestore(firebaseUser.uid);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      try {
        return await _fetchUserFromFirestore(firebaseUser.uid);
      } catch (_) {
        return null;
      }
    });
  }

  Future<UserModel> _fetchUserFromFirestore(String uid) async {
    final doc = await firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();

    if (!doc.exists) {
      throw const AuthException('لم يتم العثور على بيانات المستخدم');
    }

    final user = UserModel.fromFirestore(doc);

    if (!user.isActive) {
      throw const AuthException('هذا الحساب موقوف، يرجى التواصل مع الإدارة');
    }

    return user;
  }

  /// تحويل أكواد Firebase Auth لرسائل عربية مفهومة
  String _mapFirebaseAuthError(String code) {
    return switch (code) {
      'user-not-found' => 'البريد الإلكتروني غير مسجّل',
      'wrong-password' => 'كلمة المرور غير صحيحة',
      'invalid-email' => 'البريد الإلكتروني غير صالح',
      'user-disabled' => 'هذا الحساب موقوف',
      'too-many-requests' => 'تم تجاوز عدد المحاولات، حاول لاحقاً',
      'network-request-failed' => 'تحقق من اتصالك بالإنترنت',
      'invalid-credential' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      _ => 'حدث خطأ غير متوقع',
    };
  }
}
