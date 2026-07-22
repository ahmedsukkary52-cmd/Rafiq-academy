import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

const _authRequestTimeout = Duration(seconds: 20);
const _firestoreTimeout = Duration(seconds: 15);

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
      final credential = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(_authRequestTimeout);

      final uid = credential.user?.uid;
      if (uid == null) throw const AuthException('فشل تسجيل الدخول');

      return await _fetchUserFromFirestore(uid);
    } on TimeoutException {
      throw const AuthException(
        'انتهت مهلة الاتصال، تحقق من الشبكة وحاول مرة أخرى',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthException('خطأ في تسجيل الدخول: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final credential = await firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(_authRequestTimeout);

      final uid = credential.user?.uid;
      if (uid == null) throw const AuthException('فشل إنشاء الحساب');

      // 2. Create user document in Firestore (هنا هنكون الكولكشن تلقائياً!)
      final newUser = UserModel(
        uid: uid,
        name: name,
        role: role,
        phone: phone,
        email: email,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(newUser.toFirestore())
          .timeout(_firestoreTimeout);

      // 3. If registering a student, also create a student profile
      if (role == AppRoles.student) {
        await _createStudentProfile(uid, name);
      }

      return newUser;
    } on TimeoutException {
      throw const AuthException(
        'انتهت مهلة الاتصال، تحقق من الشبكة وحاول مرة أخرى',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthException('خطأ في إنشاء الحساب: ${e.toString()}');
    }
  }

  Future<void> _createStudentProfile(String uid, String name) async {
    // Create a default student profile in studentProfiles collection
    final studentData = {
      'uid': uid,
      'name': name,
      'avatarId': 'fox',
      'level': 1,
      'coins': 0,
      'totalStars': 0,
      'streakDays': 0,
      'halaqaId': null,
      'halaqaName': null,
      'currentPlanName': null,
      'overallProgressPercent': 0,
      'totalVersesMemorized': 0,
      'completedJuz': 0,
      'completedSurahs': 0,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };

    await firestore
        .collection('studentProfiles')
        .doc(uid)
        .set(studentData)
        .timeout(_firestoreTimeout);
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
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
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
    try {
      final doc = await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get()
          .timeout(_firestoreTimeout);

      if (!doc.exists) {
        throw const AuthException('لم يتم العثور على بيانات المستخدم');
      }

      final user = UserModel.fromFirestore(doc);

      if (!user.isActive) {
        throw const AuthException('هذا الحساب موقوف، يرجى التواصل مع الإدارة');
      }

      return user;
    } on TimeoutException {
      throw const AuthException(
        'انتهت مهلة الاتصال بقاعدة البيانات، تحقق من الشبكة',
      );
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
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

  /// تحويل أكواد Firebase (Firestore, Storage, ...) لرسائل عربية مفهومة
  String _mapFirebaseError(String code) {
    return switch (code) {
      'unavailable' => 'خدمة قاعدة البيانات غير متاحة الآن، حاول لاحقاً',
      'permission-denied' => 'ليس لديك صلاحية الوصول إلى هذه البيانات',
      'not-found' => 'لم يتم العثور على البيانات المطلوبة',
      'already-exists' => 'البيانات موجودة بالفعل',
      'resource-exhausted' => 'تم تجاوز الحد المسموح به',
      'cancelled' => 'تم إلغاء العملية',
      'unknown' => 'حدث خطأ غير معروف',
      'deadline-exceeded' => 'انتهت مهلة العملية',
      _ => 'خطأ في الاتصال: $code',
    };
  }
}
