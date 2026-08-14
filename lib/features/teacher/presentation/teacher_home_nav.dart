/// Live Teacher Home bottom-nav contract (index 2 = الجوائز).
class TeacherHomeNav {
  TeacherHomeNav._();

  static const awardsIndex = 2;

  static const labels = ['الرئيسية', 'الطلاب', 'الجوائز', 'الرسائل', 'حسابي'];
}

/// Option A: Home Awards uses [selectedHalaqaId], else the first teacher halaqa.
String? resolveTeacherAwardsHalaqaId({
  required String? selectedHalaqaId,
  required List<String> teacherHalaqaIds,
}) {
  final selected = selectedHalaqaId?.trim();
  if (selected != null && selected.isNotEmpty) return selected;
  for (final id in teacherHalaqaIds) {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
