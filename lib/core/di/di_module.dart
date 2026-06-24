import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../network/network_info.dart';

/// DiModule مسؤول عن تسجيل:
/// 1. الـ Firebase platform singletons (مش كلاسات إحنا كتبناها)
/// 2. أي abstract class محتاج factory/provider بدل ما يتسجل تلقائي
///
/// أي حاجة Injectable يقدر يكتشفها أوتوماتيك (زي الكلاسات اللي عليها
/// @injectable / @lazySingleton) متحتاجش تتسجل هنا.
@module
abstract class DiModule {
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  FirebaseMessaging get firebaseMessaging => FirebaseMessaging.instance;

  /// region لازم يطابق الـ region اللي اتنشرت بيه الـ Cloud Functions
  /// (حطيناها europe-west1 في functions/src/paymob/*.ts) - لو
  /// مش متطابقين هياخد رد "not-found" مع إن الـ function منشورة فعلاً.
  @lazySingleton
  FirebaseFunctions get firebaseFunctions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @lazySingleton
  InternetConnection get internetConnection => InternetConnection();

  @lazySingleton
  NetworkInfo networkInfo(InternetConnection connection) =>
      NetworkInfoImpl(connection);
}