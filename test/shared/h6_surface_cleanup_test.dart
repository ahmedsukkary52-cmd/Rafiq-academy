import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/shared/hardening/h6_surface_cleanup.dart';

void main() {
  group('H6SurfaceCleanup inventory', () {
    test('remaining orphan routes stay removed; analytics is re-entered', () {
      expect(
        H6SurfaceCleanup.removedRoutePaths,
        containsAll(const [
          '/student/history',
          '/teacher/calendar',
          '/teacher/content',
        ]),
      );
      expect(
        H6SurfaceCleanup.removedRoutePaths,
        isNot(contains('/teacher/halaqa/:halaqaId/analytics')),
      );
      expect(
        H6SurfaceCleanup.reEnteredTeacherAnalyticsPath,
        AppRoutes.teacherAnalytics,
      );
      expect(
        H6SurfaceCleanup.preservedTeacherAnalyticsPath,
        AppRoutes.teacherAnalytics,
      );
      expect(AppRoutes.teacherAnalytics, contains('/analytics'));
    });

    test('live W1–W8 surfaces stay registered on AppRoutes', () {
      expect(
        AppRoutes.studentContent,
        H6SurfaceCleanup.preservedStudentContentPath,
      );
      expect(
        AppRoutes.teacherAwards,
        H6SurfaceCleanup.preservedTeacherAwardsPath,
      );
      expect(
        AppRoutes.teacherChat,
        H6SurfaceCleanup.preservedTeacherChatPath,
      );
      expect(
        AppRoutes.teacherAnalytics,
        H6SurfaceCleanup.preservedTeacherAnalyticsPath,
      );
      expect(AppRoutes.admin, H6SurfaceCleanup.preservedAdminPath);
      expect(
        AppRoutes.supervisor,
        H6SurfaceCleanup.preservedSupervisorPath,
      );
      expect(AppRoutes.teacherAttend, startsWith('/teacher/attendance/'));
      expect(AppRoutes.parentAbsence, contains('absence-requests'));
    });

    test('teacher posts tab and supervisor report UI stay removed', () {
      expect(H6SurfaceCleanup.teacherPostsTabRemoved, isTrue);
      expect(H6SurfaceCleanup.supervisorReportUiHidden, isTrue);
      expect(H6SurfaceCleanup.adminProductUiAdmitOnly, isTrue);
      expect(
        H6SurfaceCleanup.teacherBottomNavLabels,
        ['الرئيسية', 'الحلقات', 'الرسائل', 'حسابي'],
      );
      expect(
        H6SurfaceCleanup.teacherBottomNavLabels,
        isNot(contains('المنشورات')),
      );
      expect(
        H6SurfaceCleanup.deletedUnregisteredPage,
        'ChatConversationsPage',
      );
    });
  });
}
