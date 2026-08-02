import 'package:equatable/equatable.dart';

enum TeacherRecentActivityKind { evaluation, attendance, award }

/// Chronological Home feed item (read projection — not persisted).
class TeacherRecentActivity extends Equatable {
  final String id;
  final TeacherRecentActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime occurredAt;
  final String? halaqaId;

  const TeacherRecentActivity({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    this.halaqaId,
  });

  @override
  List<Object?> get props => [id, kind, title, subtitle, occurredAt, halaqaId];
}
