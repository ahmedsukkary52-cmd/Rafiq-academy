import 'package:equatable/equatable.dart';

/// Raw halaqa schedule payload (no derived session times).
///
/// Domain owner for W3/W6 "meets today?" derivation — kept free of Firestore.
class HalaqaScheduleSlot extends Equatable {
  final String day;
  final String startTime;
  final String endTime;

  /// C6 / WA-7 — stable UUID on the slot object (optional until migrated).
  final String? slotId;

  const HalaqaScheduleSlot({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.slotId,
  });

  @override
  List<Object?> get props => [day, startTime, endTime, slotId];
}

class HalaqaScheduleSource extends Equatable {
  final String halaqaId;
  final String name;
  final List<HalaqaScheduleSlot> schedule;

  const HalaqaScheduleSource({
    required this.halaqaId,
    required this.name,
    required this.schedule,
  });

  @override
  List<Object?> get props => [halaqaId, name, schedule];
}
