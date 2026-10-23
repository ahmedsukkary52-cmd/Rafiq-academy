import 'package:equatable/equatable.dart';

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
  final String? topic;

  /// Joinability is not a schedule property: every Join entry point reads
  /// `halaqaMeetingLinks/{halaqaId}` at tap time through the shared joiner.
  const ClassSessionEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.startAt,
    required this.endAt,
    required this.teacherName,
    required this.status,
    this.topic,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    startAt,
    endAt,
    teacherName,
    status,
    topic,
  ];
}
