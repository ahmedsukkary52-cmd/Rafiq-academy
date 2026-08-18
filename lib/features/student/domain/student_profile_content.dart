/// Existing teacher evaluations destination for this student in [halaqaId].
/// Returns null when either id is missing — callers must not invent a page.
String? studentProfileEvaluationsPath({
  required String? halaqaId,
  required String studentId,
}) {
  final halaqa = halaqaId?.trim() ?? '';
  final student = studentId.trim();
  if (halaqa.isEmpty || student.isEmpty) return null;
  return '/teacher/halaqa/$halaqa/evaluations'
      '?studentId=${Uri.encodeQueryComponent(student)}';
}

/// Join date from `studentProfiles.createdAt` or `users.createdAt`.
String? formatStudentProfileJoinDate(DateTime? createdAt) {
  if (createdAt == null) return null;
  const months = [
    '',
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${createdAt.day} ${months[createdAt.month]} ${createdAt.year}';
}

String? nonEmptyTrimmed(String? raw) {
  final value = raw?.trim() ?? '';
  return value.isEmpty ? null : value;
}
