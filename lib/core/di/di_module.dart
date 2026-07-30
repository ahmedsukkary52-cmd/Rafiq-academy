import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../../features/notifications/data/sinks/in_app_academy_event_handler.dart';
import '../../shared/domain/academy_event_sink.dart';
import '../../shared/domain/fan_out_academy_event_sink.dart';
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

  // FirebaseMessaging intentionally NOT registered (H3 / A-H19).
  // Package may remain in pubspec for future B-FCM — no token/handlers yet.

  @lazySingleton
  FirebaseStorage get firebaseStorage => FirebaseStorage.instance;

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

  /// Sole academy-event publish port (H3 / A-H4).
  ///
  /// Production story:
  ///   TeacherRepository → [AcademyEventSink] / [FanOutAcademyEventSink]
  ///     → [InAppAcademyEventHandler] → composer → upsertSignals
  ///
  /// Admin ops broadcast is **not** registered here (see A-H15 quarantine).
  /// Adding FCM later (B-FCM) = add another [AcademyEventHandler], not a second sink.
  @lazySingleton
  AcademyEventSink academyEventSink(InAppAcademyEventHandler inApp) =>
      FanOutAcademyEventSink(handlers: [inApp]);
}
