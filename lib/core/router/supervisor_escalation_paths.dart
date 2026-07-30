/// Client allowlist for supervisor → teacher escalation navigation (W6).
///
/// Presentation and [AppRouter] share this list so the board never offers a
/// CTA the router would bounce. Does **not** encode readiness or ownership
/// rules (Rules 5–6).
class SupervisorEscalationPaths {
  const SupervisorEscalationPaths._();

  static const String teacherRoot = '/teacher';

  /// True when [path] is an existing teacher-owned operational workflow route.
  static bool isAllowed(String path) {
    return path.startsWith('$teacherRoot/attendance/') ||
        path.startsWith('$teacherRoot/halaqa/');
  }
}
