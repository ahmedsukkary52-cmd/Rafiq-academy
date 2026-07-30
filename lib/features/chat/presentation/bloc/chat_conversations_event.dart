import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_entities.dart';

abstract class ChatConversationsEvent extends Equatable {
  const ChatConversationsEvent();

  @override
  List<Object?> get props => [];
}

/// بدء مراقبة قائمة المحادثات الخاصة بالمستخدم الحالي real-time
class StartWatchingConversationsEvent extends ChatConversationsEvent {
  final String uid;
  const StartWatchingConversationsEvent(this.uid);

  @override
  List<Object?> get props => [uid];
}

/// بدء (أو استكمال) محادثة مع طرف معيّن - بيُستخدم لما المستخدم يضغط
/// "راسل المشرف" مثلاً من شاشة تانية، قبل ما ندخل شاشة المحادثة نفسها.
class StartConversationEvent extends ChatConversationsEvent {
  final ChatParticipantEntity currentUser;
  final ChatParticipantEntity otherUser;

  const StartConversationEvent({
    required this.currentUser,
    required this.otherUser,
  });

  @override
  List<Object?> get props => [currentUser, otherUser];
}

/// إعادة تصفير نتيجة بدء المحادثة بعد ما الـ UI يستخدمها (مثلاً بعد
/// ما يعمل navigate لشاشة المحادثة)
class ResetStartConversationEvent extends ChatConversationsEvent {
  const ResetStartConversationEvent();
}

/// Clear inbox projection on logout (H1 / A-H1).
class ClearChatConversationsSessionEvent extends ChatConversationsEvent {
  const ClearChatConversationsSessionEvent();
}