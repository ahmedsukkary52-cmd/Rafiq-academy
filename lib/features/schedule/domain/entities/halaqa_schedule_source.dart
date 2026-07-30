import 'package:equatable/equatable.dart';

/// Raw halaqa schedule payload (no derived session times).
///
/// Domain owner for W3/W6 "meets today?" derivation — kept free of Firestore.
class HalaqaScheduleSlot extends Equatable {
  final String day;
  final String startTime;
  final String endTime;

  const HalaqaScheduleSlot({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [day, startTime, endTime];
}

class HalaqaScheduleSource extends Equatable {
  final String halaqaId;
  final String name;
  final String meetingLink;
  final List<HalaqaScheduleSlot> schedule;

  const HalaqaScheduleSource({
    required this.halaqaId,
    required this.name,
    required this.meetingLink,
    required this.schedule,
  });

  @override
  List<Object?> get props => [halaqaId, name, meetingLink, schedule];
}
