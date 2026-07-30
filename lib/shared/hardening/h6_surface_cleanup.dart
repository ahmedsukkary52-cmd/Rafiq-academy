import '../../core/router/router_app.dart';

/// H6 surface cleanup inventory (A-H8, A-H9, A-H16, A-H17).
///
/// Documents deleted / quarantined presentation surfaces. Does **not** change
/// W1–W8 ownership, admit, day board, events, or استئذان behavior.
class H6SurfaceCleanup {
  const H6SurfaceCleanup._();

  /// Orphan routes removed from [AppRouter] (were deep-link only).
  static const removedRoutePaths = <String>[
    '/student/history',
    '/teacher/halaqa/:halaqaId/analytics',
    '/teacher/calendar',
    '/teacher/content',
  ];

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
