import 'package:equatable/equatable.dart';

import '../../../../shared/domain/assignment_entity.dart';

enum HalaqaPlanTrackKind { newMemorization, review }

/// One portion the teacher assigned (free text exactly as written by the
/// teacher — no verse-range parsing).
class HalaqaPlanEntry extends Equatable {
  final String assignmentId;
  final String portion;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime? completedAt;

  const HalaqaPlanEntry({
    required this.assignmentId,
    required this.portion,
    required this.dueDate,
    required this.isCompleted,
    this.completedAt,
  });

  @override
  List<Object?> get props => [
    assignmentId,
    portion,
    dueDate,
    isCompleted,
    completedAt,
  ];
}

/// «الجديد» or «المراجعة» track derived from the student's lesson homework.
///
/// There is no halaqa-level plan contract yet, so the start point is the
/// earliest recorded assignment, not a declared plan start. No percentage is
/// computed because no authoritative total exists.
class HalaqaPlanTrack extends Equatable {
  final HalaqaPlanTrackKind kind;

  /// Oldest → newest.
  final List<HalaqaPlanEntry> entries;

  const HalaqaPlanTrack({required this.kind, this.entries = const []});

  bool get isEmpty => entries.isEmpty;

  /// أين بدأنا — the earliest recorded portion.
  HalaqaPlanEntry? get startPoint => entries.isEmpty ? null : entries.first;

  /// أين وصلنا — the most recent completed portion.
  HalaqaPlanEntry? get reachedPoint {
    for (final e in entries.reversed) {
      if (e.isCompleted) return e;
    }
    return null;
  }

  /// المطلوب القادم — the earliest-due portion not yet completed.
  HalaqaPlanEntry? get nextPortion {
    for (final e in entries) {
      if (!e.isCompleted) return e;
    }
    return null;
  }

  /// ما تم إنجازه — completed portions, newest first.
  List<HalaqaPlanEntry> get completed =>
      entries.reversed.where((e) => e.isCompleted).toList();

  /// Latest assignments regardless of status, newest first.
  List<HalaqaPlanEntry> recent([int count = 5]) =>
      entries.reversed.take(count).toList();

  @override
  List<Object?> get props => [kind, entries];
}

class HalaqaPlan extends Equatable {
  final HalaqaPlanTrack newMemorization;
  final HalaqaPlanTrack review;

  const HalaqaPlan({required this.newMemorization, required this.review});

  bool get isEmpty => newMemorization.isEmpty && review.isEmpty;

  /// Builds both tracks from lesson-homework assignments. Assignments of a
  /// different halaqa are skipped when [halaqaId] is known (legacy docs with
  /// no halaqaId are kept); blank ranges are not entries.
  factory HalaqaPlan.fromAssignments(
    Iterable<AssignmentEntity> assignments, {
    String? halaqaId,
  }) {
    final scope = halaqaId?.trim() ?? '';
    final sorted =
        assignments
            .where(
              (a) =>
                  scope.isEmpty ||
                  a.halaqaId.trim().isEmpty ||
                  a.halaqaId.trim() == scope,
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    List<HalaqaPlanEntry> entriesFor(String Function(AssignmentEntity) pick) =>
        [
          for (final a in sorted)
            if (pick(a).trim().isNotEmpty)
              HalaqaPlanEntry(
                assignmentId: a.id,
                portion: pick(a).trim(),
                dueDate: a.dueDate,
                isCompleted: a.isSubmitted,
                completedAt: a.completedAt,
              ),
        ];

    return HalaqaPlan(
      newMemorization: HalaqaPlanTrack(
        kind: HalaqaPlanTrackKind.newMemorization,
        entries: entriesFor((a) => a.newMemorizationRange),
      ),
      review: HalaqaPlanTrack(
        kind: HalaqaPlanTrackKind.review,
        entries: entriesFor((a) => a.reviewRange),
      ),
    );
  }

  @override
  List<Object?> get props => [newMemorization, review];
}
