import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/supervisor_escalation_paths.dart';

/// Staff role that opened the student profile. Each entry point (teacher
/// route, admin route, supervisor destination) passes its own role so the page
/// only offers actions that role can complete.
enum StudentProfileViewer {
  teacher(AppRoles.teacher),
  supervisor(AppRoles.supervisor),
  admin(AppRoles.admin);

  const StudentProfileViewer(this.role);

  final String role;

  /// Evaluations live on the teacher halaqa route. Must match
  /// `AppRouteAccess.isAllowed` for that route: teachers by prefix,
  /// supervisors by escalation, admin never.
  bool get canOpenEvaluations => switch (this) {
    StudentProfileViewer.teacher => true,
    StudentProfileViewer.supervisor => SupervisorEscalationPaths.isAllowed(
      '${SupervisorEscalationPaths.teacherRoot}/halaqa/probe/evaluations',
    ),
    StudentProfileViewer.admin => false,
  };
}
