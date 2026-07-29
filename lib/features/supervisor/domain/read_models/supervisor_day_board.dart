import 'package:equatable/equatable.dart';

import '../../../../shared/domain/halaqa_day_readiness.dart';

/// One supervised halaqa's today session + shared readiness facts (W6 Slice 1).
///
/// Not persisted. Ordering / exception-first layout is presentation-owned (Rules
/// 3 + 5) — this list from the use case follows schedule D7 order only.
class SupervisorDayBoardItem extends Equatable {
  final String halaqaId;
  final String halaqaName;
  final String teacherId;
  final String teacherDisplayName;
  final DateTime startAt;
  final HalaqaDayReadiness readiness;

  const SupervisorDayBoardItem({
    required this.halaqaId,
    required this.halaqaName,
    required this.teacherId,
    required this.teacherDisplayName,
    required this.startAt,
    required this.readiness,
  });

  bool get needsAttention => readiness.needsAttention;

  bool get isComplete => readiness.isComplete;

  @override
  List<Object?> get props => [
    halaqaId,
    halaqaName,
    teacherId,
    teacherDisplayName,
    startAt,
    readiness,
  ];
}

/// Supervisor read projection of today's operational oversight board.
///
/// [items] includes **complete and incomplete** sessions (D-W6-2). Presentation
/// prioritizes exceptions (Rule 3); this model does not.
class SupervisorDayBoard extends Equatable {
  final List<SupervisorDayBoardItem> items;
  final int sessionsTodayCount;

  const SupervisorDayBoard({
    required this.items,
    required this.sessionsTodayCount,
  });

  static const empty = SupervisorDayBoard(items: [], sessionsTodayCount: 0);

  @override
  List<Object?> get props => [items, sessionsTodayCount];
}
