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

  const TeacherDayAgenda({
    required this.items,
    required this.sessionsTodayCount,
  });

  static const empty = TeacherDayAgenda(items: [], sessionsTodayCount: 0);

  bool get hasActionableItems => items.isNotEmpty;

  @override
  List<Object?> get props => [items, sessionsTodayCount];
}
