import 'package:equatable/equatable.dart';

/// One neutral, assistive action a teacher can still take today (W3 D9).
///
/// The agenda only carries the *type* of remaining work; the presentation
/// layer owns the Arabic wording and the deep-link route, so no business rule
/// or copy leaks into the orchestration layer.
enum TeacherAgendaAction { takeAttendance, reviewRecitations }

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

/// Read-time view model of "what should I do today?".
///
/// Derived entirely from the schedule + existing W1/W2 state on every read.
/// No persistence, no cached flags, no orchestration collections (W3 D8/D10).
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
