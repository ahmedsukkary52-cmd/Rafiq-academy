import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
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
}
