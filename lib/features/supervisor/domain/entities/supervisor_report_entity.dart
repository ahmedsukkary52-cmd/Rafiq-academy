import 'package:equatable/equatable.dart';

class SupervisorReportEntity extends Equatable {
  final String id;
  final String supervisorId;
  final String? halaqaId;
  final String? teacherId;
  final String type;
  final String content;
  final DateTime date;

  const SupervisorReportEntity({
    required this.id,
    required this.supervisorId,
    this.halaqaId,
    this.teacherId,
    required this.type,
    required this.content,
    required this.date,
  });

  @override
  List<Object?> get props => [
    id,
    supervisorId,
    halaqaId,
    teacherId,
    type,
    content,
    date,
  ];
}
