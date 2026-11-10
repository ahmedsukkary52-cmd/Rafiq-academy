import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../../features/notifications/data/sinks/in_app_academy_event_handler.dart';
import '../../features/parent/domain/repositories/parent_repositories.dart';
import '../../features/student/data/repositories/student_halaqa_name_reader_impl.dart';
import '../../features/student/data/repositories/student_profile_details_reader_impl.dart';
import '../../features/student/data/repositories/student_profile_summary_reader_impl.dart';
import '../../features/student/domain/repositories/student_repository.dart';
import '../../features/supervisor/domain/repositories/parent_repository.dart';
import '../../features/teacher/domain/repositories/teacher_repository.dart';
import '../../shared/domain/academy_event_sink.dart';
import '../../shared/domain/fan_out_academy_event_sink.dart';
import '../../shared/domain/halaqa_name_reader.dart';
import '../../shared/domain/halaqa_roster.dart';
import '../../shared/domain/load_halaqa_day_readiness.dart';
import '../../shared/domain/payment_proof_reader.dart';
import '../../shared/domain/recitation_records_reader.dart';
import '../../shared/domain/student_achievements_reader.dart';
import '../../shared/domain/student_parent_links.dart';
import '../../shared/domain/student_profile_details.dart';
import '../../shared/domain/student_profile_summary.dart';
import '../../shared/domain/user_display_names.dart';
import '../firebase/app_firebase.dart';
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
  FirebaseAuth get firebaseAuth => useFirebaseEmulator
      ? FirebaseAuth.instanceFor(app: firebaseEmulatorApp)
      : FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firebaseFirestore => useFirebaseEmulator
      ? FirebaseFirestore.instanceFor(app: firebaseEmulatorApp)
      : FirebaseFirestore.instance;

  /// WA-13 / C11 — token lifecycle only. Sending is Cloud Functions + Admin
  /// SDK; the client never holds server credentials.
  @lazySingleton
  FirebaseMessaging get firebaseMessaging => FirebaseMessaging.instance;

  @lazySingleton
  FirebaseStorage get firebaseStorage => useFirebaseEmulator
      ? FirebaseStorage.instanceFor(app: firebaseEmulatorApp)
      : FirebaseStorage.instance;

  /// region لازم يطابق الـ region اللي اتنشرت بيه الـ Cloud Functions
  /// (حطيناها europe-west1 في functions/src/paymob/*.ts) - لو
  /// مش متطابقين هياخد رد "not-found" مع إن الـ function منشورة فعلاً.
  @lazySingleton
  FirebaseFunctions get firebaseFunctions => useFirebaseEmulator
      ? FirebaseFunctions.instanceFor(
          app: firebaseEmulatorApp,
          region: functionsRegion,
        )
      : FirebaseFunctions.instanceFor(region: 'europe-west1');

  @lazySingleton
  InternetConnection get internetConnection => InternetConnection();

  @lazySingleton
  NetworkInfo networkInfo(InternetConnection connection) =>
      NetworkInfoImpl(connection);

  /// Sole academy-event publish port (H3 / A-H4).
  ///
  /// PH-02 / C11: academy notifications (attendance, homework, activities,
  /// evaluations) are authored by Cloud Functions from the committed
  /// Firestore facts — recipients are derived server-side and Firestore
  /// Rules deny device-authored cards. No client handler is registered;
  /// [InAppAcademyEventHandler] is retired (kept only as copy reference).
  ///
  /// Admin ops broadcast is **not** routed here (see A-H15 quarantine).
  @lazySingleton
  AcademyEventSink get academyEventSink =>
      const FanOutAcademyEventSink(handlers: <AcademyEventHandler>[]);

  /// The roster is read through the teacher data source for every role.
  @lazySingleton
  HalaqaRosterReader halaqaRosterReader(TeacherRepository repository) =>
      repository;

  /// Halaqa-day facts (attendance, homework, reviews) are read through the
  /// teacher data source for the teacher agenda and the supervisor board.
  @lazySingleton
  HalaqaDayFactsReader halaqaDayFactsReader(TeacherRepository repository) =>
      repository;

  /// Payment proofs are read through the parent data source for the parent,
  /// Admin and scoped Supervisor review (Storage Rules decide access).
  @lazySingleton
  PaymentProofReader paymentProofReader(ParentRepository repository) =>
      repository;

  /// Student → parent links are read through the parent data source for the
  /// teacher and supervisor "contact parent" flows.
  @lazySingleton
  StudentParentLinkReader studentParentLinkReader(
    ParentRepository repository,
  ) => repository;

  /// `users` display names are read through the supervisor data source.
  @lazySingleton
  UserDisplayNameReader userDisplayNameReader(
    SupervisorRepository repository,
  ) => repository;

  /// Recitation records are read through the student data source for the
  /// parent pages (same query, filter and order as the student's own read).
  @lazySingleton
  RecitationRecordsReader recitationRecordsReader(
    StudentRepository repository,
  ) => repository;

  @lazySingleton
  StudentAchievementsReader studentAchievementsReader(
    StudentRepository repository,
  ) => repository;

  /// Profile display fields for the parent child profile, mapped from the
  /// same [StudentRepository.getStudentProfile] read.
  @lazySingleton
  StudentProfileSummaryReader studentProfileSummaryReader(
    StudentRepository repository,
  ) => StudentProfileSummaryReaderImpl(repository);

  /// Profile fields for the staff student profile, mapped from the same
  /// [StudentRepository.getStudentProfile] read.
  @lazySingleton
  StudentProfileDetailsReader studentProfileDetailsReader(
    StudentRepository repository,
  ) => StudentProfileDetailsReaderImpl(repository);

  /// Halaqa display name for the staff student profile, from the same
  /// [StudentRepository.getStudentHalaqa] read.
  @lazySingleton
  HalaqaNameReader halaqaNameReader(StudentRepository repository) =>
      StudentHalaqaNameReaderImpl(repository);
}
