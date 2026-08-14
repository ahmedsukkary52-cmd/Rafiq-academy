import '../../core/router/router_app.dart';

/// H6 surface cleanup inventory (A-H8, A-H9, A-H16, A-H17).
///
/// Documents deleted / quarantined / **re-entered** presentation surfaces.
/// Does **not** change W1–W8 ownership, admit, day board, events, or استئذان
/// behavior beyond approved product re-entries (Analytics Phase 2).
class H6SurfaceCleanup {
  const H6SurfaceCleanup._();

  /// Orphan routes still removed from [AppRouter] (deep-link only / unwired).
  static const removedRoutePaths = <String>[
    '/student/history',
    '/teacher/calendar',
    '/teacher/content',
  ];

  /// Teacher Analytics — re-entered in Analytics Phase 2 (no longer orphan).
  ///
  /// Was removed under A-H8; restored with Class Details entry + honesty
  /// hardening. Listed for audit trail, not as an active quarantine.
  static const reEnteredTeacherAnalyticsPath =
      '/teacher/halaqa/:halaqaId/analytics';

  /// Unregistered duplicate page deleted in H6.
  /// Live chat remains [TeacherMessagesTab] / [StudentChatPage] + [ChatRoomPage].
  static const deletedUnregisteredPage = 'ChatConversationsPage';

  /// Teacher bottom-nav posts placeholder removed; [PostsListPage] never wired.
  static const teacherPostsTabRemoved = true;

  /// Supervisor “رفع تقرير” UI hidden — Firestore write stack remains ops-only.
  static const supervisorReportUiHidden = true;

  /// Admin product UI must not expose non-admit AdminBloc writers (A-H9).
  static const adminProductUiAdmitOnly = true;

  /// Live surfaces that must stay registered.
  static const preservedStudentContentPath = AppRoutes.studentContent;
  static const preservedTeacherAwardsPath = AppRoutes.teacherAwards;
  static const preservedTeacherChatPath = AppRoutes.teacherChat;
  static const preservedTeacherAnalyticsPath = AppRoutes.teacherAnalytics;
  static const preservedAdminPath = AppRoutes.admin;
  static const preservedSupervisorPath = AppRoutes.supervisor;

  /// Teacher home bottom-nav labels after H6 (no posts).
  static const teacherBottomNavLabels = <String>[
    'الرئيسية',
    'الحلقات',
    'الرسائل',
    'حسابي',
  ];
}
