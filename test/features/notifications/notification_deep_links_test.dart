import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/notifications/presentation/notification_deep_links.dart';

void main() {
  group('NotificationDeepLinks.resolve', () {
    test('maps each type deterministically per role', () {
      expect(
        NotificationDeepLinks.resolve(
          type: NotificationTypes.assignment,
          role: AppRoles.student,
        ),
        const NotificationDestination.route(AppRoutes.studentHomework),
      );
      expect(
        NotificationDeepLinks.resolve(
          type: NotificationTypes.attendance,
          role: AppRoles.parent,
        ),
        const NotificationDestination.route(AppRoutes.parentAbsence),
      );
      expect(
        NotificationDeepLinks.resolve(
          type: NotificationTypes.payment,
          role: AppRoles.supervisor,
        ),
        const NotificationDestination.route(AppRoutes.supervisorPayments),
      );
      expect(
        NotificationDeepLinks.resolve(
          type: NotificationTypes.payment,
          role: AppRoles.admin,
        ),
        const NotificationDestination.route(AppRoutes.adminPayments),
      );
    });

    test('a type with no destination for the role is unavailable', () {
      final d = NotificationDeepLinks.resolve(
        type: NotificationTypes.payment,
        role: AppRoles.student,
      );
      expect(d.route, isNull);
      expect(d.unavailableMessage, NotificationDeepLinks.unavailableMessage);
    });

    test('unknown types and unknown roles are unavailable', () {
      expect(
        NotificationDeepLinks.resolve(
          type: 'mystery',
          role: AppRoles.teacher,
        ).unavailableMessage,
        isNotNull,
      );
      expect(
        NotificationDeepLinks.resolve(
          type: NotificationTypes.assignment,
          role: 'guest',
        ).route,
        isNull,
      );
    });

    test('general notices are informational only', () {
      expect(
        NotificationDeepLinks.resolve(
          type: NotificationTypes.general,
          role: AppRoles.parent,
        ),
        const NotificationDestination.none(),
      );
    });

    test('every resolved route passes the role allowlist', () {
      const types = [
        NotificationTypes.sessionReminder,
        NotificationTypes.achievement,
        NotificationTypes.payment,
        NotificationTypes.assignment,
        NotificationTypes.attendance,
      ];
      const roles = [
        AppRoles.student,
        AppRoles.parent,
        AppRoles.teacher,
        AppRoles.supervisor,
        AppRoles.admin,
      ];
      for (final role in roles) {
        for (final type in types) {
          final route = NotificationDeepLinks.resolve(
            type: type,
            role: role,
          ).route;
          if (route != null) {
            expect(
              AppRouteAccess.isAllowed(path: route, role: role),
              isTrue,
              reason: '$role/$type → $route',
            );
          }
        }
      }
    });
  });

  group('NotificationDeepLinks.pushTarget', () {
    test('falls back to the role inbox when unavailable', () {
      expect(
        NotificationDeepLinks.pushTarget(
          type: NotificationTypes.payment,
          role: AppRoles.student,
        ),
        AppRoutes.studentNotifs,
      );
      expect(
        NotificationDeepLinks.pushTarget(type: 'mystery', role: AppRoles.admin),
        isNull,
      );
    });
  });
}
