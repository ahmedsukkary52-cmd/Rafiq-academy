import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_access_page.dart';
import '../../features/admin/presentation/pages/admin_accounts_page.dart';
import '../../features/admin/presentation/pages/admin_halaqat_page.dart';
import '../../features/admin/presentation/pages/admin_home_page.dart';
import '../../features/admin/presentation/pages/admin_membership_page.dart';
import '../../features/admin/presentation/pages/admin_parent_links_page.dart';
import '../../features/admin/presentation/pages/payment_review_page.dart';
import '../../features/analytics/presentation/pages/analytics_dashboard_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
// Awards
import '../../features/awards/presentation/pages/awards_page.dart';
import '../../features/chat/presentation/chat_route_extra.dart';
import '../../features/chat/presentation/pages/chat_room.dart';
import '../../features/chat/presentation/pages/student_chat_page.dart';
import '../../features/content/presentation/pages/content_library_page.dart';
import '../../features/homework/presentation/pages/student_homework_page.dart';
import '../../features/notifications/presentation/pages/notification_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/parent/presentation/pages/parent_absence_requests_page.dart';
import '../../features/parent/presentation/pages/parent_home_page.dart';
import '../../features/parent/presentation/pages/parent_notifications_page.dart';
import '../../features/progress_report/presentation/pages/student_progress_report_page.dart';
import '../../features/review_schedule/presentation/pages/student_review_schedule_page.dart';
import '../../features/schedule/presentation/pages/student_schedule_page.dart';
import '../../features/student/presentation/pages/avatar_selection_page.dart';
import '../../features/student/presentation/pages/settings_page.dart';
import '../../features/student/presentation/pages/student_achievements_page.dart';
import '../../features/student/presentation/pages/student_audio_library_page.dart';
import '../../features/student/presentation/pages/student_badges_page.dart';
import '../../features/student/presentation/pages/student_evaluation_page.dart';
// Student
import '../../features/student/presentation/pages/student_home_page.dart';
import '../../features/mushaf/presentation/pages/mushaf_reader_host.dart';
import '../../features/student/presentation/pages/student_mushaf_page.dart';
import '../../features/student/presentation/pages/student_profile_page.dart';
import '../../features/student/presentation/pages/student_streak_page.dart';
import '../../features/supervisor/presentation/pages/supervisor_home_page.dart';
import '../../features/teacher/presentation/pages/teacher_attendance_page.dart';
import '../../features/teacher/presentation/pages/teacher_class_detail_page.dart';
import '../../features/teacher/presentation/pages/teacher_evalutation_page.dart';
import '../../features/teacher/presentation/pages/teacher_excuses_page.dart';
// Teacher
import '../../features/teacher/presentation/pages/teacher_home_page.dart';
import '../constants/app_constants.dart';
import 'supervisor_escalation_paths.dart';

class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  /// D1 / WA-1 — public self-registration removed. Path kept only so deep links
  /// redirect to login (no RegisterPage route).
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
  // H6 / A-H8: studentHistory placeholder route removed (was unreachable).
  static const String studentAvatar = '/student/avatar';
  static const String studentSettings = '/student/settings';
  static const String studentBadges = '/student/badges';
  static const String studentStreak = '/student/streak';
  static const String studentContent = '/student/content';

  /// Halaqa shared content (P0 §8) for the student's own Halaqa.
  static String studentContentFor(String halaqaId) =>
      '$studentContent?halaqaId=${Uri.encodeQueryComponent(halaqaId.trim())}';
  static const String studentAudio = '/student/audio';
  static const String studentChat = '/student/chat';
  static const String studentChatRoom = '/student/chat/:conversationId';

  // Teacher
  static const String teacher = '/teacher';
  static const String teacherHalaqa = '/teacher/halaqa/:halaqaId';
  static const String teacherAttend = '/teacher/attendance/:halaqaId';
  static const String teacherEvals = '/teacher/halaqa/:halaqaId/evaluations';
  static const String teacherStudent = '/teacher/student/:studentId';

  /// Teacher Student Profile. Pass [halaqaId] when opening from Class Details.
  static String teacherStudentProfile(String studentId, {String? halaqaId}) {
    final id = studentId.trim();
    final scoped = halaqaId?.trim() ?? '';
    if (scoped.isEmpty) return '/teacher/student/$id';
    return '/teacher/student/$id?halaqaId=${Uri.encodeQueryComponent(scoped)}';
  }

  /// Analytics Phase 2 re-entry (was H6 / A-H8 orphan quarantine).
  static const String teacherAnalytics = '/teacher/halaqa/:halaqaId/analytics';

  // H6 / A-H8: teacherCalendar / teacherContent remain removed (orphan).
  static const String teacherAwards = '/teacher/halaqa/:halaqaId/awards';

  /// Halaqa Details → Shared Content (Teacher; Supervisor via escalation).
  static String teacherHalaqaContent(String halaqaId) =>
      '/teacher/halaqa/${Uri.encodeComponent(halaqaId.trim())}/content';
  static const String teacherChat = '/teacher/chat/:conversationId';
  static const String teacherNotifs = '/teacher/notifications';
  static const String teacherExcuses = '/teacher/excuses';

  // Other roles
  static const String parent = '/parent';
  static const String parentAbsence = '/parent/absence-requests';
  static const String parentNotifs = '/parent/notifications';
  static const String parentContent = '/parent/content';

  /// Shared content of a linked child's Halaqa.
  static String parentContentFor(String halaqaId) =>
      '$parentContent?halaqaId=${Uri.encodeQueryComponent(halaqaId.trim())}';
  static const String supervisor = '/supervisor';
  static const String supervisorPayments = '/supervisor/payments';
  static const String admin = '/admin';

  // Admin operational subpages (P0-02 / P0-03)
  static const String adminAccounts = '/admin/accounts';
  static const String adminParentLinks = '/admin/parent-links';
  static const String adminHalaqat = '/admin/halaqat';
  static const String adminMembership = '/admin/membership';
  static const String adminPayments = '/admin/payments';
  static const String adminAccess = '/admin/access';
}

/// Pure role → home route and path allowlist used by [AppRouter] (H8 / A-H11).
///
/// Extracted so regression tests can lock W1–W8 navigation contracts without
/// spinning up GoRouter / AuthBloc.
class AppRouteAccess {
  const AppRouteAccess._();

  /// Home path for an authenticated [role], or login for unknown roles.
  static String homeForRole(String role) => switch (role) {
    AppRoles.student => AppRoutes.student,
    AppRoles.parent => AppRoutes.parent,
    AppRoles.teacher => AppRoutes.teacher,
    AppRoles.supervisor => AppRoutes.supervisor,
    AppRoles.admin => AppRoutes.admin,
    _ => AppRoutes.login,
  };

  /// Whether [path] is allowed for [role] (prefix home + splash/login +
  /// supervisor escalation into teacher-owned operational routes).
  static bool isAllowed({required String path, required String role}) {
    final roleRoute = homeForRole(role);
    if (path.startsWith(roleRoute) ||
        path == AppRoutes.splash ||
        path == AppRoutes.login) {
      return true;
    }
    // W6 D-W6-1: supervisor may escalate into existing teacher-owned workflows.
    if (role == AppRoles.supervisor &&
        SupervisorEscalationPaths.isAllowed(path)) {
      return true;
    }
    return false;
  }
}

/// Pure auth redirect used by [AppRouter]. Fails closed: only an
/// [AuthAuthenticated] state with a known role reaches role routes; every
/// other state is confined to Splash or the public sign-in pages.
class AuthRedirect {
  const AuthRedirect._();

  static const Set<String> publicAuthPaths = {
    AppRoutes.login,
    AppRoutes.forgotPassword,
  };

  static String? resolve({required AuthState state, required String path}) {
    if (state is AuthInitial ||
        state is AuthLoading ||
        state is AuthStartupFailure) {
      // A sign-in in progress keeps its own page (it renders loading/error).
      if (state is AuthLoading && publicAuthPaths.contains(path)) return null;
      return path == AppRoutes.splash ? null : AppRoutes.splash;
    }

    if (state is AuthAuthenticated) {
      final home = AppRouteAccess.homeForRole(state.user.role);
      if (home == AppRoutes.login) {
        return path == AppRoutes.login ? null : AppRoutes.login;
      }
      if (path == AppRoutes.splash ||
          path == AppRoutes.register ||
          publicAuthPaths.contains(path)) {
        return home;
      }
      return AppRouteAccess.isAllowed(path: path, role: state.user.role)
          ? null
          : home;
    }

    // Unauthenticated / failed sign-in: public sign-in pages only
    // (legacy /register deep links land on login — D1).
    return publicAuthPaths.contains(path) ? null : AppRoutes.login;
  }
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

      return AuthRedirect.resolve(state: authState, path: currentPath);
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
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      // WA-1: /register intentionally omitted — redirects to login above.

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
              final preferredSurah = surahParam != null
                  ? int.tryParse(surahParam)
                  : null;
              final initialMode = modeParam == 'recitation'
                  ? MushafMode.recitation
                  : MushafMode.reading;
              // D23: last-read / Al-Fatihah via MushafBloc — no surah-67 default.
              return MushafBlocScope(
                child: MushafReaderHost(
                  preferredSurah: preferredSurah,
                  forceSurahJump: preferredSurah != null && preferredSurah >= 1,
                  initialMode: initialMode,
                ),
              );
            },
          ),
          GoRoute(
            path: 'avatar',
            builder: (_, __) => const AvatarSelectionPage(),
          ),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsPage()),
          // Live student content (not an H6 orphan — teacher content route removed).
          GoRoute(
            path: 'content',
            builder: (_, state) => ContentLibraryPage(
              halaqaId: state.uri.queryParameters['halaqaId'],
            ),
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
              final extra = ChatRouteExtra.parse(state.extra);
              return ChatRoomPage(
                conversationId: state.pathParameters['conversationId']!,
                otherUserName: extra[ChatRouteExtra.nameKey] ?? 'المعلم',
                otherUserImage: extra[ChatRouteExtra.imageKey],
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
                  initialStudentId: state.uri.queryParameters['studentId'],
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
              GoRoute(
                path: 'content',
                builder: (_, state) => ContentLibraryPage(
                  halaqaId: state.pathParameters['halaqaId'],
                ),
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
              halaqaId: state.uri.queryParameters['halaqaId'],
            ),
          ),
          // شاشة المحادثة
          GoRoute(
            path: 'chat/:conversationId',
            builder: (_, state) {
              final extra = ChatRouteExtra.parse(state.extra);
              return ChatRoomPage(
                conversationId: state.pathParameters['conversationId']!,
                otherUserName: extra[ChatRouteExtra.nameKey] ?? 'محادثة',
                otherUserImage: extra[ChatRouteExtra.imageKey],
              );
            },
          ),
          // الإشعارات
          GoRoute(
            path: 'notifications',
            builder: (_, __) => const NotificationsPage(),
          ),
          // طلبات الاعتذار (Phase 1 UI shell)
          GoRoute(
            path: 'excuses',
            builder: (_, __) => const TeacherExcusesPage(),
          ),
        ],
      ),

      // ── Parent ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.parent,
        builder: (_, __) => const ParentHomePage(),
        routes: [
          GoRoute(
            path: 'absence-requests',
            builder: (_, __) => const ParentAbsenceRequestsPage(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (_, __) => const ParentNotificationsPage(),
          ),
          GoRoute(
            path: 'content',
            builder: (_, state) => ContentLibraryPage(
              halaqaId: state.uri.queryParameters['halaqaId'],
            ),
          ),
        ],
      ),

      // ── Supervisor ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.supervisor,
        builder: (_, __) => const SupervisorHomePage(),
        routes: [
          GoRoute(
            path: 'payments',
            builder: (_, __) => const PaymentReviewPage(isAdmin: false),
          ),
        ],
      ),

      // ── Admin ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.admin,
        builder: (_, __) => const AdminHomePage(),
        routes: [
          GoRoute(
            path: 'accounts',
            builder: (_, __) => const AdminAccountsPage(),
          ),
          GoRoute(
            path: 'parent-links',
            builder: (_, __) => const AdminParentLinksPage(),
          ),
          GoRoute(
            path: 'halaqat',
            builder: (_, __) => const AdminHalaqatPage(),
          ),
          GoRoute(
            path: 'membership',
            builder: (_, __) => const AdminMembershipPage(),
          ),
          GoRoute(
            path: 'payments',
            builder: (_, __) => const PaymentReviewPage(isAdmin: true),
          ),
          GoRoute(path: 'access', builder: (_, __) => const AdminAccessPage()),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('خطأ')),
      body: Center(child: Text('الصفحة غير موجودة: ${state.error}')),
    ),
  );

}

class _BlocListenable extends ChangeNotifier {
  _BlocListenable(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());
  }
}
