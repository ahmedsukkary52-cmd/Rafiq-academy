import '../../domain/entities/class_session_entity.dart';

class ClassSessionModel extends ClassSessionEntity {
  const ClassSessionModel({
    required super.id,
    required super.title,
    required super.type,
    required super.startAt,
    required super.endAt,
    required super.teacherName,
    required super.status,
    super.meetingLink,
    super.topic,
  });
}
