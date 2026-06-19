// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';
//
// import '../../features/auth/presentaiton/bloc/auth_bloc.dart';
// import '../../features/auth/presentaiton/bloc/auth_state.dart';
// import '../constants/app_constants.dart';
// import '../../features/auth/presentation/pages/splash_page.dart';
// import '../../features/student/presentation/pages/student_home_page.dart';
// import '../../features/parent/presentation/pages/parent_home_page.dart';
// import '../../features/teacher/presentation/pages/teacher_home_page.dart';
// import '../../features/supervisor/presentation/pages/supervisor_home_page.dart';
// import '../../features/admin/presentation/pages/admin_home_page.dart';
//
// class AppRoutes {
//   const AppRoutes._();
//
//   static const String splash     = '/';
//   static const String login      = '/login';
//   static const String student    = '/student';
//   static const String parent     = '/parent';
//   static const String teacher    = '/teacher';
//   static const String supervisor = '/supervisor';
//   static const String admin      = '/admin';
// }
//
// class AppRouter {
//   final AuthBloc authBloc;
//
//   AppRouter({required this.authBloc});
//
//   late final GoRouter router = GoRouter(
//     initialLocation: AppRoutes.splash,
//     debugLogDiagnostics: true,
//
//     /// الـ redirect هو قلب نظام الأدوار:
//     /// بيشيك على حالة الـ AuthBloc عند كل navigation
//     /// ويوجّه المستخدم للشاشة المناسبة لدوره تلقائياً.
//     redirect: (BuildContext context, GoRouterState state) {
//       final authState = authBloc.state;
//       final currentPath = state.matchedLocation;
//
//       // لسه في الـ Splash أو بيحمّل
//       if (authState is AuthInitial || authState is AuthLoading) {
//         return currentPath == AppRoutes.splash ? null : AppRoutes.splash;
//       }
//
//       // مش مسجّل دخول
//       if (authState is AuthUnauthenticated) {
//         return currentPath == AppRoutes.login ? null : AppRoutes.login;
//       }
//
//       // مسجّل دخول → وجّهه لنافذته حسب الـ role
//       if (authState is AuthAuthenticated) {
//         final roleRoute = _routeForRole(authState.user.role);
//
//         // لو في صفحة splash أو login، ابعته لنافذته
//         if (currentPath == AppRoutes.splash || currentPath == AppRoutes.login) {
//           return roleRoute;
//         }
//
//         // لو حاول يدخل نافذة مش بتاعته، ارفض
//         if (!currentPath.startsWith(roleRoute)) {
//           return roleRoute;
//         }
//       }
//
//       return null; // مفيش redirect
//     },
//
//     refreshListenable: _BlocListenable(authBloc),
//
//     routes: [
//       GoRoute(
//         path: AppRoutes.splash,
//         builder: (_, __) => const SplashPage(),
//       ),
//       GoRoute(
//         path: AppRoutes.login,
//         builder: (_, __) => const LoginPage(),
//       ),
//       GoRoute(
//         path: AppRoutes.student,
//         builder: (_, __) => const StudentHomePage(),
//         // Sub-routes للطالب (تفاصيل التسميع، الجدول...إلخ) هتتضاف هنا
//       ),
//       GoRoute(
//         path: AppRoutes.parent,
//         builder: (_, __) => const ParentHomePage(),
//       ),
//       GoRoute(
//         path: AppRoutes.teacher,
//         builder: (_, __) => const TeacherHomePage(),
//       ),
//       GoRoute(
//         path: AppRoutes.supervisor,
//         builder: (_, __) => const SupervisorHomePage(),
//       ),
//       GoRoute(
//         path: AppRoutes.admin,
//         builder: (_, __) => const AdminHomePage(),
//       ),
//     ],
//
//     errorBuilder: (context, state) => Scaffold(
//       body: Center(
//         child: Text('الصفحة غير موجودة: ${state.error}'),
//       ),
//     ),
//   );
//
//   static String _routeForRole(String role) {
//     return switch (role) {
//       AppRoles.student    => AppRoutes.student,
//       AppRoles.parent     => AppRoutes.parent,
//       AppRoles.teacher    => AppRoutes.teacher,
//       AppRoles.supervisor => AppRoutes.supervisor,
//       AppRoles.admin      => AppRoutes.admin,
//       _                   => AppRoutes.login,
//     };
//   }
// }
//
// class _BlocListenable extends ChangeNotifier {
//   _BlocListenable(AuthBloc bloc) {
//     bloc.stream.listen((_) => notifyListeners());
//   }
// }
