import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/router/app_routes.dart';
import 'package:rafiq_academy/core/router/supervisor_escalation_paths.dart';

void main() {
  group('AppRouteAccess (H8 / A-H11 router guards)', () {
    test('homeForRole maps each role to its shell path', () {
      expect(AppRouteAccess.homeForRole(AppRoles.student), AppRoutes.student);
      expect(AppRouteAccess.homeForRole(AppRoles.parent), AppRoutes.parent);
      expect(AppRouteAccess.homeForRole(AppRoles.teacher), AppRoutes.teacher);
      expect(
        AppRouteAccess.homeForRole(AppRoles.supervisor),
        AppRoutes.supervisor,
      );
      expect(AppRouteAccess.homeForRole(AppRoles.admin), AppRoutes.admin);
      expect(AppRouteAccess.homeForRole('unknown'), AppRoutes.login);
    });

    test('role may stay under its own prefix and auth routes', () {
      expect(
        AppRouteAccess.isAllowed(
          path: '/student/homework',
          role: AppRoles.student,
        ),
        isTrue,
      );
      expect(
        AppRouteAccess.isAllowed(
          path: '/teacher/attendance/h1',
          role: AppRoles.teacher,
        ),
        isTrue,
      );
      expect(
        AppRouteAccess.isAllowed(path: AppRoutes.splash, role: AppRoles.parent),
        isTrue,
      );
      expect(
        AppRouteAccess.isAllowed(path: AppRoutes.login, role: AppRoles.admin),
        isTrue,
      );
    });

    test('student journey map is student-only', () {
      expect(
        AppRouteAccess.isAllowed(
          path: AppRoutes.studentJourneyMap,
          role: AppRoles.student,
        ),
        isTrue,
      );
      for (final role in [
        AppRoles.parent,
        AppRoles.teacher,
        AppRoles.supervisor,
        AppRoles.admin,
      ]) {
        expect(
          AppRouteAccess.isAllowed(
            path: AppRoutes.studentJourneyMap,
            role: role,
          ),
          isFalse,
          reason: role,
        );
      }
    });

    test('cross-role product shells are denied', () {
      expect(
        AppRouteAccess.isAllowed(path: AppRoutes.admin, role: AppRoles.parent),
        isFalse,
      );
      expect(
        AppRouteAccess.isAllowed(
          path: AppRoutes.teacher,
          role: AppRoles.student,
        ),
        isFalse,
      );
      expect(
        AppRouteAccess.isAllowed(
          path: AppRoutes.admin,
          role: AppRoles.supervisor,
        ),
        isFalse,
      );
    });

    test('supervisor may escalate into teacher attendance/halaqa only', () {
      expect(
        AppRouteAccess.isAllowed(
          path: '/teacher/attendance/h1',
          role: AppRoles.supervisor,
        ),
        isTrue,
      );
      expect(
        AppRouteAccess.isAllowed(
          path: '/teacher/halaqa/h1',
          role: AppRoles.supervisor,
        ),
        isTrue,
      );
      expect(
        AppRouteAccess.isAllowed(
          path: '/teacher/notifications',
          role: AppRoles.supervisor,
        ),
        isFalse,
      );
    });
  });

  group('SupervisorEscalationPaths', () {
    test('allowlist matches W6 operational teacher routes only', () {
      expect(
        SupervisorEscalationPaths.isAllowed('/teacher/attendance/abc'),
        isTrue,
      );
      expect(
        SupervisorEscalationPaths.isAllowed('/teacher/halaqa/abc/evaluations'),
        isTrue,
      );
      expect(SupervisorEscalationPaths.isAllowed('/teacher'), isFalse);
      expect(
        SupervisorEscalationPaths.isAllowed('/teacher/chat/c1'),
        isFalse,
      );
    });
  });

  group('Admin student profile navigation', () {
    test('admin may open student profile under /admin prefix', () {
      expect(
        AppRouteAccess.isAllowed(
          path: '/admin/student/s1',
          role: AppRoles.admin,
        ),
        isTrue,
      );
      expect(
        AppRouteAccess.isAllowed(
          path: '/teacher/student/s1',
          role: AppRoles.admin,
        ),
        isFalse,
      );
    });

    test('adminStudentProfile helper builds path with optional halaqaId', () {
      expect(
        AppRoutes.adminStudentProfile('abc'),
        '/admin/student/abc',
      );
      expect(
        AppRoutes.adminStudentProfile('abc', halaqaId: 'h1'),
        '/admin/student/abc?halaqaId=h1',
      );
    });
  });

  group('Assistant teacher and academy directory routes', () {
    test('assistant teacher has its own shell and nothing else', () {
      expect(AppRoles.all, contains(AppRoles.assistantTeacher));
      expect(
        AppRouteAccess.homeForRole(AppRoles.assistantTeacher),
        AppRoutes.assistant,
      );
      expect(
        AppRouteAccess.isAllowed(
          path: AppRoutes.assistant,
          role: AppRoles.assistantTeacher,
        ),
        isTrue,
      );
      for (final path in [
        AppRoutes.admin,
        AppRoutes.adminDirectory,
        AppRoutes.teacher,
        AppRoutes.teacherCover,
        '/teacher/attendance/h1',
        AppRoutes.supervisor,
      ]) {
        expect(
          AppRouteAccess.isAllowed(path: path, role: AppRoles.assistantTeacher),
          isFalse,
          reason: path,
        );
      }
    });

    test('directory and profiles are admin-only', () {
      for (final path in [
        AppRoutes.adminDirectory,
        AppRoutes.adminPersonProfile('u1'),
        AppRoutes.adminHalaqaProfile('h1'),
        AppRoutes.adminAddMemberFor(AppRoles.assistantTeacher),
      ]) {
        expect(AppRouteAccess.isAllowed(path: path, role: AppRoles.admin), isTrue);
        for (final role in [
          AppRoles.teacher,
          AppRoles.supervisor,
          AppRoles.assistantTeacher,
          AppRoles.parent,
          AppRoles.student,
        ]) {
          expect(
            AppRouteAccess.isAllowed(path: path, role: role),
            isFalse,
            reason: '$role → $path',
          );
        }
      }
      expect(AppRoutes.adminPersonProfile('u1'), '/admin/person/u1');
      expect(AppRoutes.adminHalaqaProfile('h1'), '/admin/halaqa/h1');
      expect(
        AppRoutes.adminAddMemberFor('assistant_teacher'),
        '/admin/add-member?role=assistant_teacher',
      );
    });

    test('teacher cover screen stays under the teacher shell', () {
      expect(
        AppRouteAccess.isAllowed(path: AppRoutes.teacherCover, role: AppRoles.teacher),
        isTrue,
      );
      expect(
        AppRouteAccess.isAllowed(path: AppRoutes.teacherCover, role: AppRoles.supervisor),
        isFalse,
      );
    });
  });
}
