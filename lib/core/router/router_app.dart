import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_home_page.dart';
import '../../features/chat/presentation/pages/chat_room.dart';
import '../../features/chat/presentation/pages/student_chat_page.dart';
import '../../features/content/presentation/pages/content_library_page.dart';
import '../../features/notifications/presentation/pages/notification_page.dart';
import '../../features/parent/presentation/pages/parent_home_page.dart';
import '../../features/student/presentation/pages/student_evaluation_page.dart';
import '../../features/student/presentation/pages/student_profile_page.dart';
import '../../features/supervisor/presentation/pages/supervisor_home_page.dart';
import '../../features/teacher/presentation/pages/teacher_evalutation_page.dart';
import '../constants/app_constants.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';

// Student
import '../../features/student/presentation/pages/student_home_page.dart';
import '../../features/student/presentation/pages/avatar_selection_page.dart';
import '../../features/student/presentation/pages/settings_page.dart';
import '../../features/student/presentation/pages/student_achievements_page.dart';
import '../../features/student/presentation/pages/student_badges_page.dart';
import '../../features/student/presentation/pages/student_streak_page.dart';
import '../../features/student/presentation/pages/student_mushaf_page.dart';
import '../../features/student/presentation/pages/student_audio_library_page.dart';
import '../../features/schedule/presentation/pages/student_schedule_page.dart';
import '../../features/homework/presentation/pages/student_homework_page.dart';
import '../../features/review_schedule/presentation/pages/student_review_schedule_page.dart';
import '../../features/progress_report/presentation/pages/student_progress_report_page.dart';

// Teacher
import '../../features/teacher/presentation/pages/teacher_home_page.dart';
import '../../features/teacher/presentation/pages/teacher_class_detail_page.dart';
import '../../features/teacher/presentation/pages/teacher_attendance_page.dart';

// Analytics
import '../../features/analytics/presentation/pages/analytics_dashboard_page.dart';

// Awards
import '../../features/awards/presentation/pages/awards_page.dart';

// Calendar
import '../../features/calendar/presentation/pages/calendar_page.dart';

class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';

  // Student
  static const String student = '/student';
  static const String studentEvals = '/student/evaluations';
  static const String studentSchedule = '/student/schedule';
  static const String studentReviewSchedule = '/student/review-schedule';
  static const String studentHomework = '/student/homework';
  static const String studentProgressReport = '/student/progress-report';
  static const String studentAchieve = '/student/achievements';
  static const String studentMushaf = '/student/mushaf';
  static const String studentNotifs = '/student/notifications';
  static const String studentHistory = '/student/history';
  static const String studentAvatar = '/student/avatar';
  static const String studentSettings = '/student/settings';
  static const String studentBadges = '/student/badges';
  static const String studentStreak = '/student/streak';
  static const String studentContent = '/student/content';
  static const String studentAudio = '/student/audio';
  static const String studentChat = '/student/chat';
  static const String studentChatRoom = '/student/chat/:conversationId';

  // Teacher
  static const String teacher = '/teacher';
  static const String teacherHalaqa = '/teacher/halaqa/:halaqaId';
  static const String teacherAttend = '/teacher/attendance/:halaqaId';
  static const String teacherEvals = '/teacher/halaqa/:halaqaId/evaluations';
  static const String teacherStudent = '/teacher/student/:studentId';
  static const String teacherAnalytics = '/teacher/halaqa/:halaqaId/analytics';
  static const String teacherAwards = '/teacher/halaqa/:halaqaId/awards';
  static const String teacherCalendar = '/teacher/calendar';
  static const String teacherContent = '/teacher/content';
  static const String teacherChat = '/teacher/chat/:conversationId';
  static const String teacherNotifs = '/teacher/notifications';

  // Other roles
  static const String parent = '/parent';
  static const String parentNotifs = '/parent/notifications';
  static const String supervisor = '/supervisor';
  static const String admin = '/admin';
}

class AppRouter {
  final AuthBloc authBloc;
  final ValueNotifier<bool> onboardingSeen;

  AppRouter({required this.authBloc, required this.onboardingSeen});

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: Listenable.merge([
      _BlocListenable(authBloc),
      onboardingSeen,
    ]),

    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final currentPath = state.matchedLocation;

      // أول تشغيل للتطبيق → الأونبوردنج قبل أي حاجة تانية
      if (!onboardingSeen.value) {
        return currentPath == AppRoutes.onboarding
            ? null
            : AppRoutes.onboarding;
      }
      if (currentPath == AppRoutes.onboarding) {
        return AppRoutes.splash;
      }

      // Loading / Initial → فضّل على Splash
      // (استثناء: لو المستخدم أصلاً في صفحة اللوجن أو الريجستر وبيحاول يسجّل دخول أو يتسجّل،
      // سيبه فيها - هي بتعرض حالة التحميل والخطأ بنفسها، ومفيش داعي
      // نوديه لصفحة Splash اللي مفيهاش أي تعامل مع حالة الخطأ)
      if (authState is AuthInitial || authState is AuthLoading) {
        if (currentPath == AppRoutes.login || currentPath == AppRoutes.register)
          return null;
        return currentPath == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // غير مسجّل → Login أو Register مسموحين بس
      if (authState is AuthUnauthenticated) {
        if (currentPath == AppRoutes.login ||
            currentPath == AppRoutes.register) {
          return null;
        }
        return AppRoutes.login;
      }

      // مسجّل → وجّهه لنافذته لو في صفحة auth
      if (authState is AuthAuthenticated) {
        final roleRoute = _routeForRole(authState.user.role);
        if (currentPath == AppRoutes.splash || currentPath == AppRoutes.login) {
          return roleRoute;
        }
        // حماية: لو المستخدم حاول يدخل route مش بتاعه
        if (!_isAllowedRoute(currentPath, authState.user.role)) {
          return roleRoute;
        }
      }

      return null;
    },

    routes: [
      // ── Auth ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => OnboardingPage(onboardingSeen: onboardingSeen),
      ),
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterPage(),
      ),

      // ── Student ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.student,
        builder: (_, __) => const StudentHomePage(),
        routes: [
          GoRoute(
            path: 'evaluations',
            builder: (_, __) => const StudentEvaluationsPage(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (_, __) => const NotificationsPage(),
          ),
          GoRoute(
            path: 'schedule',
            builder: (_, __) => const StudentSchedulePage(),
          ),
          GoRoute(
            path: 'review-schedule',
            builder: (_, __) => const StudentReviewSchedulePage(),
          ),
          GoRoute(
            path: 'homework',
            builder: (_, __) => const StudentHomeworkPage(),
          ),
          GoRoute(
            path: 'progress-report',
            builder: (_, __) => const StudentProgressReportPage(),
          ),
          GoRoute(
            path: 'achievements',
            builder: (_, __) => const StudentAchievementsPage(),
          ),
          GoRoute(
            path: 'badges',
            builder: (_, __) => const StudentBadgesPage(),
          ),
          GoRoute(
            path: 'streak',
            builder: (_, __) => const StudentStreakPage(),
          ),
          GoRoute(
            path: 'mushaf',
            builder: (_, state) {
              final surahParam = state.uri.queryParameters['surah'];
              final modeParam = state.uri.queryParameters['mode'];
              final isFreeMode = state.uri.queryParameters['free'] == 'true';
              final int surahNumber;
              if (surahParam != null) {
                surahNumber = int.tryParse(surahParam) ?? 1;
              } else if (isFreeMode) {
                surahNumber = 0;
              } else {
                surahNumber = 67;
              }
              final initialMode = modeParam == 'recitation'
                  ? MushafMode.recitation
                  : MushafMode.reading;
              return StudentMushafPage(
                surahNumber: surahNumber,
                initialMode: initialMode,
                isFreeMode: isFreeMode,
              );
            },
          ),
          GoRoute(
            path: 'history',
            builder: (_, __) => const _PlaceholderPage(title: 'السجل'),
          ),
          GoRoute(
            path: 'avatar',
            builder: (_, __) => const AvatarSelectionPage(),
          ),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsPage()),
          GoRoute(
            path: 'content',
            builder: (_, __) => const ContentLibraryPage(),
          ),
          GoRoute(
            path: 'audio',
            builder: (_, __) => const StudentAudioLibraryPage(),
          ),
          // بوابة شات الطالب → تفتح محادثة المعلم تلقائياً
          GoRoute(path: 'chat', builder: (_, __) => const StudentChatPage()),
          GoRoute(
            path: 'chat/:conversationId',
            builder: (_, state) {
              final extra = state.extra as Map<String, String?>?;
              return ChatRoomPage(
                conversationId: state.pathParameters['conversationId']!,
                otherUserName: extra?['name'] ?? 'المعلم',
                otherUserImage: extra?['image'],
              );
            },
          ),
        ],
      ),

      // ── Teacher ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.teacher,
        builder: (_, __) => const TeacherHomePage(),
        routes: [
          // تفاصيل حلقة
          GoRoute(
            path: 'halaqa/:halaqaId',
            builder: (_, state) => TeacherClassDetailPage(
              halaqaId: state.pathParameters['halaqaId']!,
              openAssignSheet:
                  state.uri.queryParameters['assign'] == '1' ||
                  state.uri.queryParameters['assign'] == 'true',
            ),
            routes: [
              GoRoute(
                path: 'evaluations',
                builder: (_, state) => TeacherEvaluationsPage(
                  halaqaId: state.pathParameters['halaqaId']!,
                ),
              ),
              GoRoute(
                path: 'analytics',
                builder: (_, state) => AnalyticsDashboardPage(
                  halaqaId: state.pathParameters['halaqaId']!,
                ),
              ),
              GoRoute(
                path: 'awards',
                builder: (_, state) =>
                    AwardsPage(halaqaId: state.pathParameters['halaqaId']!),
              ),
            ],
          ),
          // الحضور
          GoRoute(
            path: 'attendance/:halaqaId',
            builder: (_, state) => TeacherAttendancePage(
              halaqaId: state.pathParameters['halaqaId']!,
            ),
          ),
          // ملف طالب
          GoRoute(
            path: 'student/:studentId',
            builder: (_, state) => StudentProfilePage(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
          // التقويم
          GoRoute(path: 'calendar', builder: (_, __) => const CalendarPage()),
          // مكتبة المحتوى
          GoRoute(
            path: 'content',
            builder: (_, __) => const ContentLibraryPage(),
          ),
          // شاشة المحادثة
          GoRoute(
            path: 'chat/:conversationId',
            builder: (_, state) {
              final extra = state.extra as Map<String, String?>?;
              return ChatRoomPage(
                conversationId: state.pathParameters['conversationId']!,
                otherUserName: extra?['name'] ?? 'محادثة',
                otherUserImage: extra?['image'],
              );
            },
          ),
          // الإشعارات
          GoRoute(
            path: 'notifications',
            builder: (_, __) => const NotificationsPage(),
          ),
        ],
      ),

      // ── Parent ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.parent,
        builder: (_, __) => const ParentHomePage(),
        routes: [
          GoRoute(
            path: 'notifications',
            builder: (_, __) => const NotificationsPage(),
          ),
        ],
      ),

      // ── Supervisor ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.supervisor,
        builder: (_, __) => const SupervisorHomePage(),
      ),

      // ── Admin ─────────────────────────────────────────────────
      GoRoute(path: AppRoutes.admin, builder: (_, __) => const AdminHomePage()),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('خطأ')),
      body: Center(child: Text('الصفحة غير موجودة: ${state.error}')),
    ),
  );

  static String _routeForRole(String role) => switch (role) {
    AppRoles.student => AppRoutes.student,
    AppRoles.parent => AppRoutes.parent,
    AppRoles.teacher => AppRoutes.teacher,
    AppRoles.supervisor => AppRoutes.supervisor,
    AppRoles.admin => AppRoutes.admin,
    _ => AppRoutes.login,
  };

  static bool _isAllowedRoute(String path, String role) {
    final roleRoute = _routeForRole(role);
    // كل route بيبدأ بـ roleRoute مسموح، + Auth routes
    return path.startsWith(roleRoute) ||
        path == AppRoutes.splash ||
        path == AppRoutes.login;
  }
}

class _BlocListenable extends ChangeNotifier {
  _BlocListenable(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());
  }
}

// ── Placeholder ────────────────────────────────────────────────────────────

class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title — Coming Soon',
          style: const TextStyle(fontFamily: 'NotoNaskhArabic'),
        ),
      ),
    );
  }
}
