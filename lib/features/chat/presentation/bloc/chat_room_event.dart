import 'package:equatable/equatable.dart';

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

/// إرسال رسالة جديدة
class SendMessageRequestedEvent extends ChatRoomEvent {
  final String text;
  const SendMessageRequestedEvent(this.text);

  @override
  List<Object?> get props => [text];
}

/// Soft-delete عبر CF (C9 / WA-11).
class SoftDeleteMessageRequestedEvent extends ChatRoomEvent {
  final String messageId;
  const SoftDeleteMessageRequestedEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}
