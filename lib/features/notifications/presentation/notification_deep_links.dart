import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';

/// Where opening a notification leads. Exactly one of [route] /
/// [unavailableMessage] is set, or neither for informational notices.
class NotificationDestination {
  final String? route;
  final String? unavailableMessage;

  const NotificationDestination._({this.route, this.unavailableMessage});

  const NotificationDestination.route(String path) : this._(route: path);

  const NotificationDestination.unavailable()
    : this._(unavailableMessage: NotificationDeepLinks.unavailableMessage);

  /// Informational notice: marking it read is the whole interaction.
  const NotificationDestination.none() : this._();

  @override
  bool operator ==(Object other) =>
      other is NotificationDestination &&
      other.route == route &&
      other.unavailableMessage == unavailableMessage;

  @override
  int get hashCode => Object.hash(route, unavailableMessage);

  @override
  String toString() =>
      'NotificationDestination(route: $route, unavailable: $unavailableMessage)';
}

/// §15 — deterministic type → role route mapping. Payloads carry the type
/// only (no content); the destination page re-reads its data under rules, and
/// [AppRouteAccess] re-checks the role on open.
class NotificationDeepLinks {
  const NotificationDeepLinks._();

  static const String unavailableMessage =
      'هذا الإشعار لا يرتبط بصفحة متاحة لحسابك';

  static NotificationDestination resolve({
    required String type,
    required String role,
  }) {
    if (type == NotificationTypes.general) {
      return const NotificationDestination.none();
    }
    final route = _routeFor(type: type.trim(), role: role);
    if (route == null || !AppRouteAccess.isAllowed(path: route, role: role)) {
      return const NotificationDestination.unavailable();
    }
    return NotificationDestination.route(route);
  }

  /// Route for a tapped push: its destination, else the role inbox (where the
  /// unavailable state is shown on tap), else null (stay on the current page).
  static String? pushTarget({required String type, required String role}) =>
      resolve(type: type, role: role).route ?? inboxFor(role);

  /// Role inbox used when a push is opened but its type has no destination.
  static String? inboxFor(String role) => switch (role) {
    AppRoles.student => AppRoutes.studentNotifs,
    AppRoles.parent => AppRoutes.parentNotifs,
    AppRoles.teacher => AppRoutes.teacherNotifs,
    _ => null,
  };

  static String? _routeFor({required String type, required String role}) =>
      switch (role) {
        AppRoles.student => switch (type) {
          NotificationTypes.assignment => AppRoutes.studentHomework,
          NotificationTypes.achievement => AppRoutes.studentBadges,
          NotificationTypes.sessionReminder => AppRoutes.studentSchedule,
          NotificationTypes.attendance => AppRoutes.studentSchedule,
          _ => null,
        },
        AppRoles.parent => switch (type) {
          NotificationTypes.attendance => AppRoutes.parentAbsence,
          NotificationTypes.payment ||
          NotificationTypes.assignment ||
          NotificationTypes.achievement ||
          NotificationTypes.sessionReminder => AppRoutes.parent,
          _ => null,
        },
        AppRoles.teacher => switch (type) {
          NotificationTypes.attendance => AppRoutes.teacherExcuses,
          NotificationTypes.sessionReminder ||
          NotificationTypes.assignment => AppRoutes.teacher,
          _ => null,
        },
        AppRoles.supervisor => switch (type) {
          NotificationTypes.payment => AppRoutes.supervisorPayments,
          _ => null,
        },
        AppRoles.admin => switch (type) {
          NotificationTypes.payment => AppRoutes.adminPayments,
          _ => null,
        },
        _ => null,
      };
}
