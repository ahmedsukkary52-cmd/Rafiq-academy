import 'package:equatable/equatable.dart';

import 'entities/admin_halaqa_roster_entity.dart';

/// Admin grant target — student or entire halaqa roster.
enum AdminRewardTargetKind { student, halaqa }

class AdminGrantRewardParams extends Equatable {
  /// `grantAward` operation id; reused by retries of the same submission.
  final String awardId;
  final AdminRewardTargetKind targetKind;
  final String targetId;
  final String type;
  final String title;
  final String? description;
  final String grantedBy;
  final String? halaqaId;
  final String? halaqaName;
  final String? studentName;

  /// Resolved before the first send and sent unchanged on every retry, so a
  /// later roster change never alters the request under this [awardId].
  final List<String> recipientStudentIds;

  const AdminGrantRewardParams({
    required this.awardId,
    required this.targetKind,
    required this.targetId,
    required this.type,
    required this.title,
    this.description,
    required this.grantedBy,
    this.halaqaId,
    this.halaqaName,
    this.studentName,
    this.recipientStudentIds = const [],
  });

  @override
  List<Object?> get props => [
    awardId,
    targetKind,
    targetId,
    type,
    title,
    description,
    grantedBy,
    halaqaId,
    halaqaName,
    studentName,
    recipientStudentIds,
  ];
}

typedef AdminRewardRecipients = ({
  String halaqaId,
  String halaqaName,
  String? studentName,
  List<String> recipientStudentIds,
});

/// Every halaqa in [roster] that lists [studentId].
List<AdminHalaqaRosterEntity> halaqatOfStudent(
  List<AdminHalaqaRosterEntity> roster,
  String studentId,
) => [
  for (final halaqa in roster)
    if (halaqa.students.any((s) => s.uid == studentId)) halaqa,
];

/// The halaqa and recipients a new admin grant targets, from a loaded
/// [roster]: the halaqa's whole roster, or the student alone under their
/// halaqa. A student in several halaqat needs an explicit
/// [studentHalaqaId]; it is never picked by ordering. Null when the target
/// is not on the roster or the student's halaqa is not determined.
AdminRewardRecipients? resolveAdminRewardRecipients({
  required List<AdminHalaqaRosterEntity> roster,
  required AdminRewardTargetKind kind,
  required String targetId,
  String? studentHalaqaId,
}) {
  if (kind == AdminRewardTargetKind.halaqa) {
    for (final halaqa in roster) {
      if (halaqa.id != targetId) continue;
      final ids = [for (final s in halaqa.students) s.uid];
      if (ids.isEmpty) return null;
      return (
        halaqaId: halaqa.id,
        halaqaName: halaqa.name,
        studentName: null,
        recipientStudentIds: List.unmodifiable(ids),
      );
    }
    return null;
  }
  final candidates = halaqatOfStudent(roster, targetId);
  final AdminHalaqaRosterEntity halaqa;
  if (studentHalaqaId != null) {
    final chosen = candidates.where((h) => h.id == studentHalaqaId);
    if (chosen.isEmpty) return null;
    halaqa = chosen.first;
  } else if (candidates.length == 1) {
    halaqa = candidates.single;
  } else {
    return null;
  }
  final student = halaqa.students.firstWhere((s) => s.uid == targetId);
  return (
    halaqaId: halaqa.id,
    halaqaName: halaqa.name,
    studentName: student.name,
    recipientStudentIds: List.unmodifiable([student.uid]),
  );
}
