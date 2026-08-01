import 'package:equatable/equatable.dart';

/// One neutral, assistive action a teacher can still take today (W3 D9).
///
/// This is orchestration vocabulary only — not a Firestore-backed domain
/// concept. The presentation layer owns Arabic wording and deep-link routes.
enum TeacherAgendaAction { takeAttendance, sendHomework, reviewRecitations }

/// A single halaqa's remaining work for today.
///
/// Only halaqat that still have at least one pending action appear here — the
/// dashboard emphasises remaining work, never finished work (W3).
class TeacherAgendaItem extends Equatable {
  final String halaqaId;
  final String halaqaName;
  final DateTime startAt;
  final List<TeacherAgendaAction> pendingActions;

  const TeacherAgendaItem({
    required this.halaqaId,
    required this.halaqaName,
    required this.startAt,
    required this.pendingActions,
  });

  @override
  List<Object?> get props => [halaqaId, halaqaName, startAt, pendingActions];
}

/// Honest end-of-day status (W3 Slice 4).
///
/// A **pure presentation** of the agenda — never a new completion rule.
enum DayCloseoutStatus {
  /// No halaqa meets today — nothing to close out (idle day).
  noSession,

  /// At least one halaqa meets today and none has remaining work.
  complete,

  /// At least one of today's halaqat still has remaining work.
  incomplete,
}

/// Day-level closeout, derived **only** from [TeacherDayAgenda].
///
/// Not persisted, not a domain aggregate, and it performs **no** I/O and **no**
/// readiness math of its own — it just names what the agenda already says
/// (W3 Slice 4: closeout is presentation of existing facts).
class TeacherDayCloseout extends Equatable {
  final DayCloseoutStatus status;

  /// Halaqat meeting today (denominator). Mirrors `sessionsTodayCount`.
  final int totalHalaqat;

  /// Halaqat with no remaining work (`total - remaining`).
  final int completedHalaqat;

  const TeacherDayCloseout({
    required this.status,
    required this.totalHalaqat,
    required this.completedHalaqat,
  });

  int get remainingHalaqat => totalHalaqat - completedHalaqat;

  @override
  List<Object?> get props => [status, totalHalaqat, completedHalaqat];
}

/// Today's featured session for Teacher Home (presentation projection).
///
/// Selected live → upcoming → first among today's D7-ordered operational days
/// (same rule already used for schedule "featured" session). Room is omitted
/// until the halaqa model exposes it.
class TeacherTodaySession extends Equatable {
  final String halaqaId;
  final String halaqaName;
  final DateTime startAt;
  final int studentCount;

  const TeacherTodaySession({
    required this.halaqaId,
    required this.halaqaName,
    required this.startAt,
    required this.studentCount,
  });

  @override
  List<Object?> get props => [halaqaId, halaqaName, startAt, studentCount];
}

/// Presentation-facing **read projection** of "what should I do today?".
///
/// Not a domain entity and not persisted. Derived at read time from the
/// schedule + existing W1/W2 state (W3 D8/D10). Lives under `read_models`
/// so it is never mistaken for a business aggregate.
class TeacherDayAgenda extends Equatable {
  /// Halaqat with remaining work today, in stable execution order (D7).
  final List<TeacherAgendaItem> items;

  /// How many halaqat actually meet today (before removing finished work).
  /// Lets the UI distinguish "no session today" from "all work done".
  final int sessionsTodayCount;

  /// Current/next session for Home (null when [sessionsTodayCount] is 0).
  final TeacherTodaySession? featuredSession;

  const TeacherDayAgenda({
    required this.items,
    required this.sessionsTodayCount,
    this.featuredSession,
  });

  static const empty = TeacherDayAgenda(items: [], sessionsTodayCount: 0);

  bool get hasActionableItems => items.isNotEmpty;

  /// Day closeout — a pure function of [items] and [sessionsTodayCount].
  ///
  /// Single source of truth: readiness stays in [items] (from W1/W2), this
  /// only aggregates counts. No new reads, no duplicated readiness logic.
  TeacherDayCloseout get closeout {
    final total = sessionsTodayCount;
    final remaining = items.length;
    final completed = (total - remaining).clamp(0, total);

    final DayCloseoutStatus status;
    if (total == 0) {
      status = DayCloseoutStatus.noSession;
    } else if (remaining == 0) {
      status = DayCloseoutStatus.complete;
    } else {
      status = DayCloseoutStatus.incomplete;
    }

    return TeacherDayCloseout(
      status: status,
      totalHalaqat: total,
      completedHalaqat: completed,
    );
  }

  @override
  List<Object?> get props => [items, sessionsTodayCount, featuredSession];
}
