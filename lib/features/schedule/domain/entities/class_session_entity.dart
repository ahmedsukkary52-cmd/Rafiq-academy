import 'package:equatable/equatable.dart';

import '../../../../shared/domain/meeting_link_policy.dart';

enum ClassSessionStatus { live, upcoming, ended }

enum ClassSessionType { memorization, review, tajweed, other }

class ClassSessionEntity extends Equatable {
  final String id;
  final String title;
  final ClassSessionType type;
  final DateTime startAt;
  final DateTime endAt;
  final String teacherName;
  final ClassSessionStatus status;
  final String meetingLink;
  final String? topic;

  const ClassSessionEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.startAt,
    required this.endAt,
    required this.teacherName,
    required this.status,
    this.meetingLink = '',
    this.topic,
  });

  /// Same rule as the Join buttons: a valid stored link; no time window.
  bool get canJoin => joinableMeetingUri(meetingLink) != null;

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    startAt,
    endAt,
    teacherName,
    status,
    meetingLink,
    topic,
  ];
}
