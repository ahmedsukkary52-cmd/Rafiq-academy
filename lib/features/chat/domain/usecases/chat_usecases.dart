import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/chat_entities.dart';
import '../policies/chat_permission_policy.dart';
import '../repositories/chat_repository.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WatchConversationsUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class WatchConversationsUseCase
    extends StreamUseCase<List<ConversationEntity>, ChatUidParams> {
  final ChatRepository repository;
  WatchConversationsUseCase(this.repository);

  @override
  Stream<Either<Failure, List<ConversationEntity>>> call(
      ChatUidParams params,
      ) =>
      repository.watchConversations(params.uid);
}

/// Admin-only academy-wide inbox (read oversight; does not join threads).
@lazySingleton
class WatchAllConversationsUseCase
    extends StreamUseCase<List<ConversationEntity>, ChatUidParams> {
  final ChatRepository repository;
  WatchAllConversationsUseCase(this.repository);

  @override
  Stream<Either<Failure, List<ConversationEntity>>> call(
    ChatUidParams params,
  ) =>
      repository.watchAllConversations(observerUid: params.uid);
}

// ══════════════════════════════════════════════════════════════════════════════
// WatchMessagesUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class WatchMessagesUseCase
    extends StreamUseCase<List<MessageEntity>, ConversationIdParams> {
  final ChatRepository repository;
  WatchMessagesUseCase(this.repository);

  @override
  Stream<Either<Failure, List<MessageEntity>>> call(
      ConversationIdParams params,
      ) =>
      repository.watchMessages(params.conversationId);
}

// ══════════════════════════════════════════════════════════════════════════════
// GetOrCreateConversationUseCase
// ══════════════════════════════════════════════════════════════════════════════

/// هنا بالظبط بنطبّق قاعدة الصلاحيات [ChatPermissionPolicy] قبل ما نوصل
/// أصلاً لأي قراءة أو كتابة في Firestore. لو الدورين مش مسموح لهم
/// يتواصلوا، بنرجّع [ValidationFailure] فوراً من غير ما نكلّف نفسنا
/// نعمل أي network call.
@lazySingleton
class GetOrCreateConversationUseCase
    extends UseCase<ConversationEntity, GetOrCreateConversationParams> {
  final ChatRepository repository;
  GetOrCreateConversationUseCase(this.repository);

  @override
  Future<Either<Failure, ConversationEntity>> call(
      GetOrCreateConversationParams params,
      ) async {
    final isAllowed = ChatPermissionPolicy.canChat(
      params.currentUser.role,
      params.otherUser.role,
    );

    if (!isAllowed) {
      return const Left(
        ValidationFailure('غير مسموح بالتواصل بين هذين الحسابين'),
      );
    }

    return repository.getOrCreateConversation(
      currentUser: params.currentUser,
      otherUser: params.otherUser,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SendMessageUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class SendMessageUseCase extends UseCase<Unit, SendMessageParams> {
  final ChatRepository repository;
  SendMessageUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SendMessageParams params) {
    // التحقق من إن النص مش فاضي قبل ما نوصل للسيرفر خالص - validation
    // بسيطة بس بتمنع رسائل فاضية تتسجل بالغلط.
    final trimmed = params.text.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('لا يمكن إرسال رسالة فارغة')),
      );
    }

    return repository.sendMessage(
      conversationId: params.conversationId,
      senderId: params.senderId,
      text: trimmed,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MarkConversationAsReadUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class MarkConversationAsReadUseCase
    extends UseCase<Unit, MarkAsReadParams> {
  final ChatRepository repository;
  MarkConversationAsReadUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(MarkAsReadParams params) {
    return repository.markConversationAsRead(
      conversationId: params.conversationId,
      uid: params.uid,
    );
  }
}

@lazySingleton
class GetChatParticipantUseCase
    extends UseCase<ChatParticipantEntity, ChatUidParams> {
  final ChatRepository repository;

  GetChatParticipantUseCase(this.repository);

  @override
  Future<Either<Failure, ChatParticipantEntity>> call(ChatUidParams params) {
    return repository.getParticipant(params.uid);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Params
// ══════════════════════════════════════════════════════════════════════════════

class ChatUidParams extends Equatable {
  final String uid;
  const ChatUidParams(this.uid);

  @override
  List<Object?> get props => [uid];
}

class ConversationIdParams extends Equatable {
  final String conversationId;
  const ConversationIdParams(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

class GetOrCreateConversationParams extends Equatable {
  final ChatParticipantEntity currentUser;
  final ChatParticipantEntity otherUser;

  const GetOrCreateConversationParams({
    required this.currentUser,
    required this.otherUser,
  });

  @override
  List<Object?> get props => [currentUser, otherUser];
}

class SendMessageParams extends Equatable {
  final String conversationId;
  final String senderId;
  final String text;

  const SendMessageParams({
    required this.conversationId,
    required this.senderId,
    required this.text,
  });

  @override
  List<Object?> get props => [conversationId, senderId, text];
}

class MarkAsReadParams extends Equatable {
  final String conversationId;
  final String uid;

  const MarkAsReadParams({required this.conversationId, required this.uid});

  @override
  List<Object?> get props => [conversationId, uid];
}