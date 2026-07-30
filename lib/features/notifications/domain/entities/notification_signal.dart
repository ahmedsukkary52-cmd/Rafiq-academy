import 'package:equatable/equatable.dart';

/// One in-app message to write for one recipient.
///
/// [id] is deterministic so the same academy event never produces a second
/// card for the same recipient, and a correction replaces the message it
/// corrects instead of contradicting it.
class NotificationSignal extends Equatable {
  final String id;
  final String audience;
  final String title;
  final String body;
  final String type;

  const NotificationSignal({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    required this.type,
  });

  @override
  List<Object?> get props => [id, audience, title, body, type];
}
