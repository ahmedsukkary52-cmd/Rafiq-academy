import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/chat_entities.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class ChatConversationsState extends Equatable {
  final SectionStatus conversationsStatus;
  final List<ConversationEntity> conversations;
  final String? conversationsError;

  /// نتيجة بدء محادثة جديدة (أو جلب الموجودة) - الـ UI بيستخدمها
  /// عشان يعرف إمتى يعمل navigate لشاشة المحادثة.
  final SubmissionStatus startConversationStatus;
  final ConversationEntity? startedConversation;
  final String? startConversationError;

  const ChatConversationsState({
    this.conversationsStatus = SectionStatus.initial,
    this.conversations = const [],
    this.conversationsError,
    this.startConversationStatus = SubmissionStatus.idle,
    this.startedConversation,
    this.startConversationError,
  });

  factory ChatConversationsState.initial() => const ChatConversationsState();

  /// إجمالي عدد المحادثات اللي فيها رسائل غير مقروءة - مفيد لو حبينا
  /// نعرض badge عام على أيقونة "الرسائل" في الـ navigation.
  int get totalUnreadCount =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  ChatConversationsState copyWith({
    SectionStatus? conversationsStatus,
    List<ConversationEntity>? conversations,
    Object? conversationsError = _unset,
    SubmissionStatus? startConversationStatus,
    Object? startedConversation = _unset,
    Object? startConversationError = _unset,
  }) {
    return ChatConversationsState(
      conversationsStatus: conversationsStatus ?? this.conversationsStatus,
      conversations: conversations ?? this.conversations,
      conversationsError: identical(conversationsError, _unset)
          ? this.conversationsError
          : conversationsError as String?,
      startConversationStatus:
      startConversationStatus ?? this.startConversationStatus,
      startedConversation: identical(startedConversation, _unset)
          ? this.startedConversation
          : startedConversation as ConversationEntity?,
      startConversationError: identical(startConversationError, _unset)
          ? this.startConversationError
          : startConversationError as String?,
    );
  }

  @override
  List<Object?> get props => [
    conversationsStatus,
    conversations,
    conversationsError,
    startConversationStatus,
    startedConversation,
    startConversationError,
  ];
}