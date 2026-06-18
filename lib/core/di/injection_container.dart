// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:get_it/get_it.dart';
// import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
//
// import '../network/network_info.dart';
// import '../../features/auth/data/datasources/auth_remote_datasource.dart';
// import '../../features/auth/data/repositories/auth_repository_impl.dart';
// import '../../features/auth/domain/repositories/auth_repository.dart';
// import '../../features/auth/domain/usecases/login_with_email_usecase.dart';
// import '../../features/auth/domain/usecases/logout_usecase.dart';
// import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
// import '../../features/auth/presentation/bloc/auth_bloc.dart';
//
// /// GetIt instance - يتم استخدامه في كل التطبيق بالاسم [sl] (Service Locator)
// final sl = GetIt.instance;
//
// Future<void> initDependencies() async {
//   //! ── Core ─────────────────────────────────────────────────────────────────
//
//   sl.registerLazySingleton<NetworkInfo>(
//         () => NetworkInfoImpl(sl()),
//   );
//
//   sl.registerLazySingleton<InternetConnection>(
//         () => InternetConnection(),
//   );
//
//   //! ── Firebase ─────────────────────────────────────────────────────────────
//
//   sl.registerLazySingleton<FirebaseAuth>(
//         () => FirebaseAuth.instance,
//   );
//
//   sl.registerLazySingleton<FirebaseFirestore>(
//         () => FirebaseFirestore.instance,
//   );
//
//   sl.registerLazySingleton<FirebaseMessaging>(
//         () => FirebaseMessaging.instance,
//   );
//
//   //! ── Feature: Auth ────────────────────────────────────────────────────────
//
//   // DataSource
//   sl.registerLazySingleton<AuthRemoteDatasource>(
//         () => AuthRemoteDatasourceImpl(
//       firebaseAuth: sl(),
//       firestore: sl(),
//     ),
//   );
//
//   // Repository
//   sl.registerLazySingleton<AuthRepository>(
//         () => AuthRepositoryImpl(
//       remoteDatasource: sl(),
//       networkInfo: sl(),
//     ),
//   );
//
//   // Use Cases
//   sl.registerLazySingleton(() => LoginWithEmailUseCase(sl()));
//   sl.registerLazySingleton(() => LogoutUseCase(sl()));
//   sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
//
//   // Bloc - ليس Singleton لأن كل rebuild ممكن يحتاج instance جديد
//   // AuthBloc استثناء لأنه بيستخدم في go_router redirect وطول عمر التطبيق
//   sl.registerLazySingleton<AuthBloc>(
//         () => AuthBloc(
//       loginWithEmail: sl(),
//       logout: sl(),
//       getCurrentUser: sl(),
//     ),
//   );
//
//   //! ── Feature: Student ─────────────────────────────────────────────────────
//   // TODO: يتكمل بعد بناء feature الطالب
//
//   //! ── Feature: Parent ──────────────────────────────────────────────────────
//   // TODO: يتكمل بعد بناء feature ولي الأمر
//
//   //! ── Feature: Teacher ─────────────────────────────────────────────────────
//   // TODO: يتكمل بعد بناء feature المعلم
//
//   //! ── Feature: Supervisor ──────────────────────────────────────────────────
//   // TODO: يتكمل بعد بناء feature المشرف
//
//   //! ── Feature: Admin ───────────────────────────────────────────────────────
//   // TODO: يتكمل بعد بناء feature الإدارة
// }
