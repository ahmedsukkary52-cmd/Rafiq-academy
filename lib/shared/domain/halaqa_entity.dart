import 'package:equatable/equatable.dart';

class HalaqaScheduleEntity extends Equatable {
  final String day;
  final String startTime;
  final String endTime;

  /// C6 / WA-7 — stable UUID (optional until B-SLOT-ID-MIGRATE completes).
  final String? slotId;

  const HalaqaScheduleEntity({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.slotId,
  });

  @override
  List<Object?> get props => [day, startTime, endTime, slotId];
}

class HalaqaEntity extends Equatable {
  final String id;
  final String name;
  final String teacherId;
  final String supervisorId;
  final List<String> studentIds;
  final List<HalaqaScheduleEntity> schedule;
  final String status;

  /// The meeting link is not part of the halaqa: read it from
  /// `halaqaMeetingLinks/{id}` via `GetHalaqaMeetingLinkUseCase` (B14).
  const HalaqaEntity({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.supervisorId,
    required this.studentIds,
    required this.schedule,
    required this.status,
  });

  bool get isActive => status == 'active';

  @override
  List<Object?> get props => [
    id,
    name,
    teacherId,
    supervisorId,
    studentIds,
    schedule,
    status,
  ];
}
