import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/chat_entities.dart';
import '../policies/chat_media_policy.dart';
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
      repository.watchConversations(params.uid, limit: params.limit);
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
      repository.watchAllConversations(
        observerUid: params.uid,
        limit: params.limit,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// WatchMessagesUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class WatchMessagesUseCase
    extends StreamUseCase<List<MessageEntity>, WatchMessagesParams> {
  final ChatRepository repository;
  WatchMessagesUseCase(this.repository);

  @override
  Stream<Either<Failure, List<MessageEntity>>> call(
      WatchMessagesParams params,
      ) =>
      repository.watchMessages(params.conversationId, limit: params.limit);
}

// ══════════════════════════════════════════════════════════════════════════════
// GetOrCreateConversationUseCase
// ══════════════════════════════════════════════════════════════════════════════

/// UX role-pair pre-filter only. Authoritative D14 relationship checks run
/// on the server (`createDirectConversation`). Do not treat this as security.
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
    final trimmed = params.text.trim();
    final media = params.media;
    if (media == null) {
      final invalid = validateMessageText(trimmed);
      if (invalid != null) return Future.value(Left(ValidationFailure(invalid)));
    } else if (trimmed.length > ChatMediaPolicy.textMaxChars) {
      return Future.value(
        Left(ValidationFailure(validateMessageText(trimmed)!)),
      );
    }
    if (!ChatMessageIds.isValid(params.messageId)) {
      return Future.value(const Left(ValidationFailure('معرف الرسالة غير صالح')));
    }

    return repository.sendMessage(
      conversationId: params.conversationId,
      messageId: params.messageId,
      type: params.type,
      text: trimmed,
      media: media,
      replyToMessageId: params.replyToMessageId,
    );
  }
}

/// Arabic validation message for a text body, or null when acceptable.
String? validateMessageText(String trimmed) {
  if (trimmed.isEmpty) return 'لا يمكن إرسال رسالة فارغة';
  if (trimmed.length > ChatMediaPolicy.textMaxChars) {
    return 'الرسالة أطول من ${ChatMediaPolicy.textMaxChars} حرف';
  }
  return null;
}

@lazySingleton
class StartChatUploadUseCase
    extends UseCase<ChatUploadTask, StartChatUploadParams> {
  final ChatRepository repository;
  StartChatUploadUseCase(this.repository);

  @override
  Future<Either<Failure, ChatUploadTask>> call(StartChatUploadParams params) {
    final invalid = ChatMediaPolicy.validate(params.draft);
    if (invalid != null) return Future.value(Left(ValidationFailure(invalid)));
    return repository.startAttachmentUpload(
      conversationId: params.conversationId,
      messageId: params.messageId,
      uploaderId: params.uploaderId,
      draft: params.draft,
    );
  }
}

@lazySingleton
class DiscardChatUploadUseCase extends UseCase<Unit, String> {
  final ChatRepository repository;
  DiscardChatUploadUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String storagePath) =>
      repository.discardUpload(storagePath);
}

@lazySingleton
class DownloadChatMediaUseCase extends UseCase<Uint8List, ChatMediaEntity> {
  final ChatRepository repository;
  DownloadChatMediaUseCase(this.repository);

  @override
  Future<Either<Failure, Uint8List>> call(ChatMediaEntity media) =>
      repository.downloadMedia(media);
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

@lazySingleton
class SoftDeleteChatMessageUseCase
    extends UseCase<Unit, SoftDeleteChatMessageParams> {
  final ChatRepository repository;
  SoftDeleteChatMessageUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SoftDeleteChatMessageParams params) {
    return repository.softDeleteMessage(
      conversationId: params.conversationId,
      messageId: params.messageId,
    );
  }
}

@lazySingleton
class EditChatMessageUseCase extends UseCase<Unit, EditChatMessageParams> {
  final ChatRepository repository;
  EditChatMessageUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(EditChatMessageParams params) {
    final trimmed = params.text.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('لا يمكن حفظ رسالة فارغة')),
      );
    }
    final invalid = validateMessageText(trimmed);
    if (invalid != null) return Future.value(Left(ValidationFailure(invalid)));
    return repository.editMessage(
      conversationId: params.conversationId,
      messageId: params.messageId,
      text: trimmed,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Params
// ══════════════════════════════════════════════════════════════════════════════

class ChatUidParams extends Equatable {
  final String uid;

  /// Live window size for inbox streams; null keeps the unbounded stream.
  final int? limit;
  const ChatUidParams(this.uid, {this.limit});

  @override
  List<Object?> get props => [uid, limit];
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

class WatchMessagesParams extends Equatable {
  final String conversationId;
  final int limit;

  const WatchMessagesParams({required this.conversationId, required this.limit});

  @override
  List<Object?> get props => [conversationId, limit];
}

/// Sender identity is never a client parameter (server uses the auth uid).
class SendMessageParams extends Equatable {
  final String conversationId;
  final String messageId;
  final ChatMessageType type;
  final String text;
  final ChatSendMedia? media;
  final String? replyToMessageId;

  const SendMessageParams({
    required this.conversationId,
    required this.messageId,
    this.type = ChatMessageType.text,
    required this.text,
    this.media,
    this.replyToMessageId,
  });

  @override
  List<Object?> get props =>
      [conversationId, messageId, type, text, media, replyToMessageId];
}

class StartChatUploadParams extends Equatable {
  final String conversationId;
  final String messageId;
  final String uploaderId;
  final ChatAttachmentDraft draft;

  const StartChatUploadParams({
    required this.conversationId,
    required this.messageId,
    required this.uploaderId,
    required this.draft,
  });

  @override
  List<Object?> get props => [conversationId, messageId, uploaderId, draft];
}

class MarkAsReadParams extends Equatable {
  final String conversationId;
  final String uid;

  const MarkAsReadParams({required this.conversationId, required this.uid});

  @override
  List<Object?> get props => [conversationId, uid];
}

class SoftDeleteChatMessageParams extends Equatable {
  final String conversationId;
  final String messageId;

  const SoftDeleteChatMessageParams({
    required this.conversationId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [conversationId, messageId];
}

class EditChatMessageParams extends Equatable {
  final String conversationId;
  final String messageId;
  final String text;

  const EditChatMessageParams({
    required this.conversationId,
    required this.messageId,
    required this.text,
  });

  @override
  List<Object?> get props => [conversationId, messageId, text];
}