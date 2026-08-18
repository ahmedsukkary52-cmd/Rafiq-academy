/// UI/filtering state for the Awards create sheet.
///
/// Recipients remain explicit student UIDs. Halaqa checks only decide which
/// rosters are shown; they are not a Firestore grant scope.
class AwardRecipientStudent {
  final String uid;
  final String name;
  final String? imageUrl;

  const AwardRecipientStudent({
    required this.uid,
    required this.name,
    this.imageUrl,
  });
}

class AwardHalaqaOption {
  final String id;
  final String name;

  const AwardHalaqaOption({required this.id, required this.name});
}

class AwardRecipientHalaqaGroup {
  final String halaqaId;
  final String halaqaName;
  final List<AwardRecipientStudent> students;

  const AwardRecipientHalaqaGroup({
    required this.halaqaId,
    required this.halaqaName,
    required this.students,
  });
}

class AwardRecipientSelection {
  final Set<String> selectedHalaqaIds;
  final Set<String> selectedStudentIds;

  const AwardRecipientSelection({
    this.selectedHalaqaIds = const {},
    this.selectedStudentIds = const {},
  });

  int get selectedHalaqaCount => selectedHalaqaIds.length;

  int get selectedStudentCount => selectedStudentIds.length;

  bool get hasHalaqa => selectedHalaqaIds.isNotEmpty;

  bool get hasStudent => selectedStudentIds.isNotEmpty;

  static bool canGrant({
    required bool hasHalaqa,
    required bool hasStudent,
    required String title,
  }) => hasHalaqa && hasStudent && title.trim().isNotEmpty;

  static List<AwardRecipientStudent> uniqueStudents(
    Iterable<AwardRecipientStudent> students,
  ) {
    final seen = <String>{};
    final out = <AwardRecipientStudent>[];
    for (final student in students) {
      if (student.uid.isEmpty || !seen.add(student.uid)) continue;
      out.add(student);
    }
    return out;
  }

  static Set<String> uniqueStudentIdsForHalaqat({
    required Iterable<String> halaqaIds,
    required Map<String, List<AwardRecipientStudent>> rosters,
  }) {
    final ids = <String>{};
    for (final halaqaId in halaqaIds) {
      for (final student in uniqueStudents(rosters[halaqaId] ?? const [])) {
        ids.add(student.uid);
      }
    }
    return ids;
  }

  static List<AwardRecipientHalaqaGroup> visibleGroups({
    required List<AwardHalaqaOption> teacherHalaqat,
    required Set<String> selectedHalaqaIds,
    required Map<String, List<AwardRecipientStudent>> rosters,
  }) {
    final groups = <AwardRecipientHalaqaGroup>[];
    for (final halaqa in teacherHalaqat) {
      if (!selectedHalaqaIds.contains(halaqa.id)) continue;
      groups.add(
        AwardRecipientHalaqaGroup(
          halaqaId: halaqa.id,
          halaqaName: halaqa.name,
          students: uniqueStudents(rosters[halaqa.id] ?? const []),
        ),
      );
    }
    return groups;
  }

  AwardRecipientSelection copyWith({
    Set<String>? selectedHalaqaIds,
    Set<String>? selectedStudentIds,
  }) {
    return AwardRecipientSelection(
      selectedHalaqaIds: selectedHalaqaIds ?? this.selectedHalaqaIds,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
    );
  }

  AwardRecipientSelection toggleHalaqa(
    String halaqaId, {
    required Iterable<String> allHalaqaIds,
    required Map<String, List<AwardRecipientStudent>> rosters,
  }) {
    final nextHalaqat = Set<String>.from(selectedHalaqaIds);
    if (!nextHalaqat.add(halaqaId)) {
      nextHalaqat.remove(halaqaId);
    }
    final allowed = allHalaqaIds.toSet();
    nextHalaqat.removeWhere((id) => !allowed.contains(id));
    return _withVisibleStudents(nextHalaqat, rosters);
  }

  AwardRecipientSelection toggleSelectAllHalaqat({
    required Iterable<String> allHalaqaIds,
    required Map<String, List<AwardRecipientStudent>> rosters,
  }) {
    final all = allHalaqaIds.toSet();
    if (all.isEmpty) {
      return const AwardRecipientSelection();
    }
    final allSelected =
        selectedHalaqaIds.length == all.length && selectedHalaqaIds.containsAll(all);
    if (allSelected) {
      return const AwardRecipientSelection();
    }
    return _withVisibleStudents(all, rosters);
  }

  AwardRecipientSelection toggleStudent(String studentId) {
    if (studentId.isEmpty) return this;
    final next = Set<String>.from(selectedStudentIds);
    if (!next.add(studentId)) {
      next.remove(studentId);
    }
    return copyWith(selectedStudentIds: next);
  }

  bool isHalaqaFullySelected(
    String halaqaId,
    Map<String, List<AwardRecipientStudent>> rosters,
  ) {
    final ids = uniqueStudents(rosters[halaqaId] ?? const [])
        .map((student) => student.uid)
        .toSet();
    if (ids.isEmpty) return false;
    return ids.every(selectedStudentIds.contains);
  }

  bool isGlobalAllSelected(Map<String, List<AwardRecipientStudent>> rosters) {
    final visible = uniqueStudentIdsForHalaqat(
      halaqaIds: selectedHalaqaIds,
      rosters: rosters,
    );
    if (visible.isEmpty) return false;
    return visible.every(selectedStudentIds.contains);
  }

  AwardRecipientSelection toggleSelectAllInHalaqa(
    String halaqaId,
    Map<String, List<AwardRecipientStudent>> rosters,
  ) {
    final ids = uniqueStudents(rosters[halaqaId] ?? const [])
        .map((student) => student.uid)
        .toSet();
    if (ids.isEmpty) return this;
    final next = Set<String>.from(selectedStudentIds);
    if (isHalaqaFullySelected(halaqaId, rosters)) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
    }
    return copyWith(selectedStudentIds: next);
  }

  AwardRecipientSelection toggleSelectAllStudents(
    Map<String, List<AwardRecipientStudent>> rosters,
  ) {
    final visible = uniqueStudentIdsForHalaqat(
      halaqaIds: selectedHalaqaIds,
      rosters: rosters,
    );
    if (visible.isEmpty) return this;
    if (isGlobalAllSelected(rosters)) {
      return copyWith(
        selectedStudentIds: selectedStudentIds.difference(visible),
      );
    }
    return copyWith(selectedStudentIds: {...selectedStudentIds, ...visible});
  }

  List<AwardRecipientStudent> resolvedRecipients(
    Map<String, List<AwardRecipientStudent>> rosters,
  ) {
    final byId = <String, AwardRecipientStudent>{};
    for (final halaqaId in selectedHalaqaIds) {
      for (final student in uniqueStudents(rosters[halaqaId] ?? const [])) {
        byId.putIfAbsent(student.uid, () => student);
      }
    }
    return selectedStudentIds
        .where(byId.containsKey)
        .map((id) => byId[id]!)
        .toList(growable: false);
  }

  List<String> uniqueRecipientIds(
    Map<String, List<AwardRecipientStudent>> rosters,
  ) => resolvedRecipients(rosters).map((student) => student.uid).toList();

  AwardRecipientSelection ensuringStudentSelected(String studentId) {
    final id = studentId.trim();
    if (id.isEmpty || selectedStudentIds.contains(id)) return this;
    return copyWith(selectedStudentIds: {...selectedStudentIds, id});
  }

  static List<AwardHalaqaOption> selectedHalaqatInOrder({
    required List<AwardHalaqaOption> teacherHalaqat,
    required Set<String> selectedHalaqaIds,
  }) {
    return teacherHalaqat
        .where((halaqa) => selectedHalaqaIds.contains(halaqa.id))
        .toList(growable: false);
  }

  static String primaryHalaqaId({
    required Iterable<String> selectedHalaqaIds,
    String? preferredHalaqaId,
  }) {
    final ids = <String>[];
    final seen = <String>{};
    for (final id in selectedHalaqaIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      ids.add(trimmed);
    }
    final preferred = preferredHalaqaId?.trim() ?? '';
    if (preferred.isNotEmpty && ids.contains(preferred)) return preferred;
    return ids.isEmpty ? preferred : ids.first;
  }

  AwardRecipientSelection _withVisibleStudents(
    Set<String> nextHalaqat,
    Map<String, List<AwardRecipientStudent>> rosters,
  ) {
    final visible = uniqueStudentIdsForHalaqat(
      halaqaIds: nextHalaqat,
      rosters: rosters,
    );
    return AwardRecipientSelection(
      selectedHalaqaIds: nextHalaqat,
      selectedStudentIds: selectedStudentIds.intersection(visible),
    );
  }
}
