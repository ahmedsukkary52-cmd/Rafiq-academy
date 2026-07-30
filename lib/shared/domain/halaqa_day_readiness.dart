import 'package:equatable/equatable.dart';

import '../utils/attendance_policy.dart';

/// One of the three W3 day-operation pillars (attendance / homework / reviews).
///
/// Shared by teacher agenda and supervisor oversight (W6 D-W6-3). Not persisted.
enum HalaqaDayGapKind { attendanceIncomplete, homeworkPending, reviewsPending }

/// One explainable readiness gap — **facts only**, no presentation copy.
///
/// Rule 4 (W6): UI answers "what" and "why" from [kind] + [quantity].
///
/// Quantity meaning:
/// - [HalaqaDayGapKind.attendanceIncomplete] → unmarked roster students
/// - [HalaqaDayGapKind.homeworkPending] → unused (`null`)
/// - [HalaqaDayGapKind.reviewsPending] → pending-review count
class HalaqaDayGap extends Equatable {
  final HalaqaDayGapKind kind;

  /// Supporting count when the gap needs a numeric explanation. See class docs.
  final int? quantity;

  const HalaqaDayGap({required this.kind, this.quantity});

  @override
  List<Object?> get props => [kind, quantity];
}

/// Pure read projection of one halaqa's remaining day operations.
///
/// Not a domain aggregate and not persisted. Empty [gaps] means the halaqa's
/// operational workflow for the evaluated day is complete.
class HalaqaDayReadiness extends Equatable {
  /// Stable order: attendance → homework → reviews (matches W3 agenda actions).
  final List<HalaqaDayGap> gaps;

  const HalaqaDayReadiness({required this.gaps});

  static const complete = HalaqaDayReadiness(gaps: []);

  bool get isComplete => gaps.isEmpty;

  bool get needsAttention => gaps.isNotEmpty;

  @override
  List<Object?> get props => [gaps];
}

/// Single owner of halaqa day-readiness math (W6 D-W6-3).
///
/// Encodes **exactly** the W3 checks already used by [GetTodayAgendaUseCase]:
/// - register incomplete via [AttendancePolicy.isRegisterIncomplete]
/// - homework pending when roster is non-empty and latest dueDate is not today
/// - reviews pending when pending-review count > 0
///
/// **Rule 5 (W6):** role-neutral academy facts only. Never teacher/supervisor UI,
/// layout, priority, colors, navigation, or permissions. Consumers decide how
/// to present and order the same [HalaqaDayReadiness].
///
/// No I/O. No new business rules. No Firestore fields.
class HalaqaDayReadinessProjector {
  const HalaqaDayReadinessProjector._();

  /// Project readiness from already-loaded W1/W2 facts.
  static HalaqaDayReadiness project({
    required Iterable<String> rosterStudentIds,
    required Iterable<String> markedStudentIds,
    required DateTime now,
    required DateTime? latestAssignmentDueDate,
    required int pendingReviewCount,
  }) {
    final gaps = <HalaqaDayGap>[];

    final roster = _normalizedIds(rosterStudentIds);
    final marked = _normalizedIds(markedStudentIds);

    if (AttendancePolicy.isRegisterIncomplete(
      rosterStudentIds: roster,
      markedStudentIds: marked,
    )) {
      gaps.add(
        HalaqaDayGap(
          kind: HalaqaDayGapKind.attendanceIncomplete,
          quantity: roster.difference(marked).length,
        ),
      );
    }

    // Empty roster: align with sendAssignment guard (nothing to assign).
    if (roster.isNotEmpty) {
      final assignedToday =
          latestAssignmentDueDate != null &&
          AttendancePolicy.isSameCalendarDay(latestAssignmentDueDate, now);
      if (!assignedToday) {
        gaps.add(const HalaqaDayGap(kind: HalaqaDayGapKind.homeworkPending));
      }
    }

    if (pendingReviewCount > 0) {
      gaps.add(
        HalaqaDayGap(
          kind: HalaqaDayGapKind.reviewsPending,
          quantity: pendingReviewCount,
        ),
      );
    }

    return HalaqaDayReadiness(gaps: gaps);
  }

  static Set<String> _normalizedIds(Iterable<String> ids) =>
      ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
}
