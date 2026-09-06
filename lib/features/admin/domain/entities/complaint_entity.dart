import 'package:equatable/equatable.dart';

/// Complaint workflow statuses for Admin / Teacher / Supervisor tracking.
class ComplaintStatuses {
  const ComplaintStatuses._();

  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String resolved = 'resolved';
  static const String archived = 'archived';
}

class ComplaintPriorities {
  const ComplaintPriorities._();

  static const String low = 'low';
  static const String normal = 'normal';
  static const String high = 'high';
}

class ComplaintEntity extends Equatable {
  final String id;
  final String senderId;
  final String senderRole;
  final String subject;
  final String message;
  final String status;
  final String? response;
  final DateTime createdAt;
  final String priority;
  final String? assigneeId;
  final String? assigneeRole;
  final DateTime? updatedAt;

  const ComplaintEntity({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.subject,
    required this.message,
    required this.status,
    this.response,
    required this.createdAt,
    this.priority = ComplaintPriorities.normal,
    this.assigneeId,
    this.assigneeRole,
    this.updatedAt,
  });

  bool get isOpen =>
      status != ComplaintStatuses.resolved &&
      status != ComplaintStatuses.archived;

  ComplaintEntity copyWith({
    String? status,
    String? response,
    String? priority,
    String? assigneeId,
    String? assigneeRole,
    DateTime? updatedAt,
  }) {
    return ComplaintEntity(
      id: id,
      senderId: senderId,
      senderRole: senderRole,
      subject: subject,
      message: message,
      status: status ?? this.status,
      response: response ?? this.response,
      createdAt: createdAt,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeRole: assigneeRole ?? this.assigneeRole,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderRole,
    subject,
    message,
    status,
    response,
    createdAt,
    priority,
    assigneeId,
    assigneeRole,
    updatedAt,
  ];
}
