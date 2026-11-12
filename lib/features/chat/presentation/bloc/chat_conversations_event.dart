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

  /// Live window size; null = unbounded (no paging).
  final int? pageSize;
  const StartWatchingConversationsEvent(this.uid, {this.pageSize});

  @override
  List<Object?> get props => [uid, pageSize];
}

/// Admin oversight: watch every conversation without joining as a participant.
class StartWatchingAllConversationsEvent extends ChatConversationsEvent {
  final String observerUid;
  final int? pageSize;
  const StartWatchingAllConversationsEvent(this.observerUid, {this.pageSize});

  @override
  List<Object?> get props => [observerUid, pageSize];
}

/// Next page older than the last listed conversation (document cursor).
class LoadMoreConversationsEvent extends ChatConversationsEvent {
  const LoadMoreConversationsEvent();
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