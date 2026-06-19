import 'package:equatable/equatable.dart';

class ComplaintEntity extends Equatable {
  final String id;
  final String senderId;
  final String senderRole;
  final String subject;
  final String message;
  final String status;
  final String? response;
  final DateTime createdAt;

  const ComplaintEntity({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.subject,
    required this.message,
    required this.status,
    this.response,
    required this.createdAt,
  });

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
  ];
}
