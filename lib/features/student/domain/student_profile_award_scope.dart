import '../../teacher/domain/entities/halaqa_students_summary_entity.dart';

/// Resolves which halaqa the teacher Student Profile should use for grants
/// and roster-derived stats (attendance).
///
/// Class Details [routeHalaqaId] wins. [profileHalaqaId] is the fallback
/// when the profile is opened without a class context.
/// TeacherBloc.selectedHalaqaId is intentionally not an input.
String? resolveStudentProfileAwardHalaqaId({
  String? routeHalaqaId,
  String? profileHalaqaId,
}) {
  final route = routeHalaqaId?.trim() ?? '';
  if (route.isNotEmpty) return route;
  final profile = profileHalaqaId?.trim() ?? '';
  if (profile.isNotEmpty) return profile;
  return null;
}

/// Attendance % already computed by [HalaqaStudentSummaryProjector] on the
/// teacher roster. Lookup only — does not recalculate.
double? attendancePercentFromRoster({
  required Iterable<HalaqaStudentSummaryEntity> roster,
  required String studentId,
}) {
  final id = studentId.trim();
  if (id.isEmpty) return null;
  for (final student in roster) {
    if (student.uid.trim() == id) return student.attendancePercent;
  }
  return null;
}
