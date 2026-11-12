import 'package:equatable/equatable.dart';

import '../../domain/policies/chat_media_policy.dart';

abstract class ChatRoomEvent extends Equatable {
  const ChatRoomEvent();

  @override
  List<Object?> get props => [];
}

/// بدء مراقبة رسائل المحادثة - بيتطلق تلقائياً جوه الـ constructor،
/// مش محتاج الـ UI يبعته يدوي.
class WatchMessagesStartedEvent extends ChatRoomEvent {
  const WatchMessagesStartedEvent();
}

/// Grow the listener window by one page (older history).
class LoadOlderMessagesRequestedEvent extends ChatRoomEvent {
  const LoadOlderMessagesRequestedEvent();
}

/// إرسال رسالة نصية جديدة
class SendMessageRequestedEvent extends ChatRoomEvent {
  final String text;

  /// Message being quoted (server copies its preview into `replyTo`).
  final String? replyToMessageId;
  const SendMessageRequestedEvent(this.text, {this.replyToMessageId});

  @override
  List<Object?> get props => [text, replyToMessageId];
}

/// Upload [draft] then send it as an image / voice / file message.
class SendAttachmentRequestedEvent extends ChatRoomEvent {
  final ChatAttachmentDraft draft;
  const SendAttachmentRequestedEvent(this.draft);

  @override
  List<Object?> get props => [draft];
}

class RetryOutgoingRequestedEvent extends ChatRoomEvent {
  final String messageId;
  const RetryOutgoingRequestedEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

/// Cancels an in-flight upload or drops a failed message (orphan removed).
class CancelOutgoingRequestedEvent extends ChatRoomEvent {
  final String messageId;
  const CancelOutgoingRequestedEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

class EditMessageRequestedEvent extends ChatRoomEvent {
  final String messageId;
  final String text;
  const EditMessageRequestedEvent(this.messageId, this.text);

  @override
  List<Object?> get props => [messageId, text];
}

/// Soft-delete عبر CF (C9 / WA-11).
class SoftDeleteMessageRequestedEvent extends ChatRoomEvent {
  final String messageId;
  const SoftDeleteMessageRequestedEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

class ActionErrorDismissedEvent extends ChatRoomEvent {
  const ActionErrorDismissedEvent();
}

class ChatUploadProgressedEvent extends ChatRoomEvent {
  final String messageId;
  final double progress;
  const ChatUploadProgressedEvent(this.messageId, this.progress);

  @override
  List<Object?> get props => [messageId, progress];
}
