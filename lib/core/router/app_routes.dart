import '../../features/auth/presentation/bloc/auth_state.dart';
import '../constants/app_constants.dart';
import 'supervisor_escalation_paths.dart';

class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  /// Mandatory replacement of an Admin-issued temporary password.
  static const String firstLogin = '/first-login';

  /// D1 / WA-1 — public self-registration removed. Path kept only so deep links
  /// redirect to login (no RegisterPage route).
  static const String register = '/register';

  /// B10 — blocking screen for a build below the configured minimum.
  static const String updateRequired = '/update-required';

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
  static const String studentJourneyMap = '/student/journey-map';
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

  /// Halaqat a teacher covers temporarily (Admin-activated cover).
  static const String teacherCover = '/teacher/cover';

  /// مساعد مدرس — assigned halaqat and active covers.
  static const String assistant = '/assistant';

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

  // Admin operational subpages (P0-02 / P0-03), callable-backed.
  static const String adminAccounts = '/admin/accounts';
  static const String adminParentLinks = '/admin/parent-links';

  /// Halaqa + weekly schedule creation (`adminCreateHalaqa`).
  static const String adminHalaqat = '/admin/halaqat';
  static const String adminMembership = '/admin/membership';

  /// Payment proof review (`reviewPaymentProof`).
  static const String adminPayments = '/admin/payments';
  static const String adminAccess = '/admin/access';

  static const String adminAdmit = '/admin/admit';

  /// Student onboarding wizard (accounts + link + halaqa + credentials).
  static const String adminOnboardStudent = '/admin/onboard-student';
  static const String adminComplaints = '/admin/complaints';
  static const String adminBroadcast = '/admin/broadcast';
  static const String adminTeachers = '/admin/teachers';
  static const String adminContent = '/admin/content';
  static const String adminNotifications = '/admin/notifications';
  static const String adminCommunication = '/admin/communication';
  static const String adminCommunicationAnalytics =
      '/admin/communication-analytics';
  static const String adminChat = '/admin/chat';
  static const String adminChatRoom = '/admin/chat/:conversationId';
  static const String adminComplaintsReview = '/admin/complaints-review';
  static const String adminRegistration = '/admin/registration-requests';
  static const String adminAnnouncements = '/admin/announcements';
  static const String adminReports = '/admin/reports';
  static const String adminRewards = '/admin/rewards';
  static const String adminInternalNotes = '/admin/internal-notes';

  /// Academy payment destinations (Vodafone Cash, InstaPay) shown to parents.
  static const String adminPaymentDestinations = '/admin/payment-destinations';

  /// Legacy entry point; redirects to [adminHalaqat] (schedule required, D8).
  static const String adminCreateHalaqa = '/admin/create-halaqa';
  static const String adminFinanceDetail = '/admin/finance-detail';

  /// Read-only list of `payments` documents.
  static const String adminPaymentsOverview = '/admin/payments-overview';
  static const String adminSupervisors = '/admin/supervisors';

  /// Read-only academy-wide halaqat directory.
  static const String adminHalaqatDirectory = '/admin/halaqat-directory';

  /// Central academy directory (people, halaqat, relationships).
  static const String adminDirectory = '/admin/directory';
  static String adminPersonProfile(String uid) =>
      '/admin/person/${Uri.encodeComponent(uid.trim())}';
  static String adminHalaqaProfile(String halaqaId) =>
      '/admin/halaqa/${Uri.encodeComponent(halaqaId.trim())}';
  static const String adminAddMember = '/admin/add-member';
  static String adminAddMemberFor(String role) =>
      '$adminAddMember?role=${Uri.encodeQueryComponent(role)}';
  static const String adminStudent = '/admin/student/:studentId';

  /// Admin view of [StudentProfilePage]. Pass [halaqaId] when opening from roster.
  static String adminStudentProfile(String studentId, {String? halaqaId}) {
    final id = studentId.trim();
    final scoped = halaqaId?.trim() ?? '';
    if (scoped.isEmpty) return '/admin/student/$id';
    return '/admin/student/$id?halaqaId=${Uri.encodeQueryComponent(scoped)}';
  }
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
    AppRoles.assistantTeacher => AppRoutes.assistant,
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
      if (state.user.mustChangePassword) {
        return path == AppRoutes.firstLogin ? null : AppRoutes.firstLogin;
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
