import 'package:equatable/equatable.dart';

import '../../../shared/domain/academy_membership_invariant.dart';
import '../../student/domain/entities/halaqa_entity.dart';
import '../../teacher/domain/entities/halaqa_students_summary_entity.dart';

/// One student across assigned halaqat (deduped). Dual membership = 1–2 halaqa ids.
class SupervisorStudentRow extends Equatable {
  final String studentId;
  final String name;
  final String? profileImageUrl;
  final List<String> halaqaIds;
  final List<String> halaqaNames;
  final List<String> teacherIds;
  final List<String> teacherNames;
  final int level;
  final bool isAtRisk;
  final double attendancePercent;
  final String? lastGradeLabel;
  final double overallProgressPercent;

  const SupervisorStudentRow({
    required this.studentId,
    required this.name,
    this.profileImageUrl,
    this.halaqaIds = const [],
    this.halaqaNames = const [],
    this.teacherIds = const [],
    this.teacherNames = const [],
    this.level = 1,
    this.isAtRisk = false,
    this.attendancePercent = 0,
    this.lastGradeLabel,
    this.overallProgressPercent = 0,
  });

  int get membershipCount => halaqaIds.length;

  bool get isDualMember => membershipCount >= 2;

  bool get isOutstanding =>
      overallProgressPercent >= 80 || (lastGradeLabel?.trim() == 'ممتاز');

  bool get hasAttendanceConcern =>
      attendancePercent > 0 && attendancePercent < 70;

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'طالب' : trimmed;
  }

  String get halaqaLabel {
    if (halaqaNames.isEmpty) return '—';
    return halaqaNames.join(' · ');
  }

  String get teacherLabel {
    final names = teacherNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return '';
    return names.map((n) => n.startsWith('أ.') ? n : 'أ. $n').join(' · ');
  }

  String get searchBlob {
    return [
      displayName,
      halaqaLabel,
      teacherLabel,
      ...teacherIds,
      'مستوى $level',
      if (lastGradeLabel != null) lastGradeLabel!,
    ].join(' ').toLowerCase();
  }

  @override
  List<Object?> get props => [
    studentId,
    name,
    profileImageUrl,
    halaqaIds,
    halaqaNames,
    teacherIds,
    teacherNames,
    level,
    isAtRisk,
    attendancePercent,
    lastGradeLabel,
    overallProgressPercent,
  ];
}

/// Pure roster helpers for Supervisor scope (no Firestore).
class SupervisorRoster {
  const SupervisorRoster._();

  /// Unique student ids from assigned halaqat rosters.
  static List<String> uniqueStudentIds(Iterable<HalaqaEntity> halaqat) {
    final seen = <String>{};
    final out = <String>[];
    for (final h in halaqat) {
      for (final raw in h.studentIds) {
        final id = raw.trim();
        if (id.isEmpty || !seen.add(id)) continue;
        out.add(id);
      }
    }
    return out;
  }

  /// Halaqa ids (from [halaqat]) that contain [studentId].
  static List<String> membershipHalaqaIds({
    required Iterable<HalaqaEntity> halaqat,
    required String studentId,
  }) {
    final sid = studentId.trim();
    if (sid.isEmpty) return const [];
    final out = <String>[];
    for (final h in halaqat) {
      if (h.studentIds.any((id) => id.trim() == sid)) {
        out.add(h.id);
      }
    }
    return out;
  }

  /// Merge per-halaqa summaries into unique students (OR for isAtRisk).
  static List<SupervisorStudentRow> mergeSummaries({
    required Iterable<HalaqaEntity> halaqat,
    required Map<String, List<HalaqaStudentSummaryEntity>> byHalaqaId,
    Map<String, String> teacherNamesById = const {},
  }) {
    final byStudent = <String, SupervisorStudentRow>{};
    final namesById = {for (final h in halaqat) h.id: h.name};
    final teacherByHalaqa = {
      for (final h in halaqat)
        if (h.teacherId.trim().isNotEmpty) h.id: h.teacherId.trim(),
    };

    for (final entry in byHalaqaId.entries) {
      final halaqaId = entry.key;
      final halaqaName = namesById[halaqaId] ?? halaqaId;
      final teacherId = teacherByHalaqa[halaqaId];
      final teacherName = teacherId == null
          ? ''
          : (teacherNamesById[teacherId]?.trim() ?? '');
      for (final s in entry.value) {
        final id = s.uid.trim();
        if (id.isEmpty) continue;
        final existing = byStudent[id];
        if (existing == null) {
          byStudent[id] = SupervisorStudentRow(
            studentId: id,
            name: s.name,
            profileImageUrl: s.profileImageUrl,
            halaqaIds: [halaqaId],
            halaqaNames: [halaqaName],
            teacherIds: teacherId == null ? const [] : [teacherId],
            teacherNames: teacherName.isEmpty ? const [] : [teacherName],
            level: s.level,
            isAtRisk: s.isAtRisk,
            attendancePercent: s.attendancePercent,
            lastGradeLabel: s.lastGradeLabel,
            overallProgressPercent: s.overallProgressPercent,
          );
        } else {
          final ids = [...existing.halaqaIds];
          final names = [...existing.halaqaNames];
          final tIds = [...existing.teacherIds];
          final tNames = [...existing.teacherNames];
          if (!ids.contains(halaqaId)) {
            ids.add(halaqaId);
            names.add(halaqaName);
          }
          if (teacherId != null && !tIds.contains(teacherId)) {
            tIds.add(teacherId);
            if (teacherName.isNotEmpty) tNames.add(teacherName);
          }
          byStudent[id] = SupervisorStudentRow(
            studentId: id,
            name: existing.name.trim().isNotEmpty ? existing.name : s.name,
            profileImageUrl: existing.profileImageUrl ?? s.profileImageUrl,
            halaqaIds: ids,
            halaqaNames: names,
            teacherIds: tIds,
            teacherNames: tNames,
            level: existing.level >= s.level ? existing.level : s.level,
            isAtRisk: existing.isAtRisk || s.isAtRisk,
            attendancePercent: existing.attendancePercent > 0
                ? existing.attendancePercent
                : s.attendancePercent,
            lastGradeLabel: existing.lastGradeLabel ?? s.lastGradeLabel,
            overallProgressPercent: existing.overallProgressPercent > 0
                ? existing.overallProgressPercent
                : s.overallProgressPercent,
          );
        }
      }
    }

    final rows = byStudent.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return rows;
  }
}

/// Client-side validation for Register / Transfer forms (no writes).
class SupervisorMembershipFormValidation {
  const SupervisorMembershipFormValidation._();

  static const int maxHalaqatPerStudent =
      AcademyMembershipInvariant.maxHalaqatPerStudent;

  /// Existing-student admit/add into [targetHalaqaId].
  static String? registerError({
    required String studentId,
    required String? targetHalaqaId,
    required Iterable<HalaqaEntity> assignedHalaqat,
  }) {
    final sid = studentId.trim();
    if (sid.isEmpty) return 'أدخل معرّف الطالب';
    final target = targetHalaqaId?.trim() ?? '';
    if (target.isEmpty) return 'اختر الحلقة';
    final assigned = assignedHalaqat.map((h) => h.id).toSet();
    if (!assigned.contains(target)) {
      return 'الحلقة ليست ضمن نطاق إشرافك';
    }
    final memberships = SupervisorRoster.membershipHalaqaIds(
      halaqat: assignedHalaqat,
      studentId: sid,
    );
    if (memberships.contains(target)) {
      return 'الطالب موجود بالفعل في هذه الحلقة';
    }
    if (memberships.length >= maxHalaqatPerStudent) {
      return 'الطالب وصل للحد الأقصى (حلقتان)';
    }
    return null;
  }

  /// Transfer form validation (client-side; writes via AcademyAdmissionFirestore).
  static String? transferError({
    required String studentId,
    required String? sourceHalaqaId,
    required String? targetHalaqaId,
    required Iterable<HalaqaEntity> assignedHalaqat,
    required bool isMove,
  }) {
    final sid = studentId.trim();
    if (sid.isEmpty) return 'اختر الطالب';
    final target = targetHalaqaId?.trim() ?? '';
    if (target.isEmpty) return 'اختر الحلقة الهدف';
    final assigned = assignedHalaqat.map((h) => h.id).toSet();
    if (!assigned.contains(target)) {
      return 'الحلقة الهدف ليست ضمن نطاق إشرافك';
    }
    final memberships = SupervisorRoster.membershipHalaqaIds(
      halaqat: assignedHalaqat,
      studentId: sid,
    );
    if (memberships.contains(target)) {
      return 'الطالب موجود بالفعل في الحلقة الهدف';
    }
    if (isMove) {
      final source = sourceHalaqaId?.trim() ?? '';
      if (source.isEmpty) return 'اختر الحلقة المصدر';
      if (!assigned.contains(source)) {
        return 'الحلقة المصدر ليست ضمن نطاق إشرافك';
      }
      if (!memberships.contains(source)) {
        return 'الطالب ليس عضوًا في الحلقة المصدر';
      }
      if (source == target) return 'المصدر والهدف يجب أن يختلفا';
    } else {
      if (memberships.length >= maxHalaqatPerStudent) {
        return 'الطالب وصل للحد الأقصى (حلقتان)';
      }
    }
    return null;
  }
}
