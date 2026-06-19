import 'package:equatable/equatable.dart';

class HalaqaScheduleEntity extends Equatable {
  final String day;
  final String startTime;
  final String endTime;

  const HalaqaScheduleEntity({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [day, startTime, endTime];
}

class HalaqaEntity extends Equatable {
  final String id;
  final String name;
  final String teacherId;
  final String supervisorId;
  final List<String> studentIds;
  final List<HalaqaScheduleEntity> schedule;
  final String meetingLink;
  final String status;

  const HalaqaEntity({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.supervisorId,
    required this.studentIds,
    required this.schedule,
    required this.meetingLink,
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
    meetingLink,
    status,
  ];
}
