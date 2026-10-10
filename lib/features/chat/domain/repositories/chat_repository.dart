import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chat_entities.dart';
import '../policies/chat_media_policy.dart';

/// In-flight Storage upload for one outgoing chat message.
abstract class ChatUploadTask {
  /// Fraction transferred, 0.0 – 1.0.
  Stream<double> get progress;

  /// Completes when the object is stored; throws on failure or cancel.
  Future<void> get completion;

  String get storagePath;

  Future<void> cancel();
}

abstract class ChatRepository {
  /// Stream لقائمة كل محادثات المستخدم الحالي، مرتبة بآخر رسالة (الأحدث أولاً)
  Stream<Either<Failure, List<ConversationEntity>>> watchConversations(
    String uid,
  );

  /// Admin oversight: all academy conversations without joining as participant.
  Stream<Either<Failure, List<ConversationEntity>>> watchAllConversations({
    required String observerUid,
  });

  /// Newest [limit] messages, in ascending time order.
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
    String conversationId, {
    required int limit,
  });

  /// يجيب المحادثة لو موجودة، أو ينشئها لو دي أول رسالة بين الطرفين.
  /// الـ caller (الـ use case) هو المسؤول عن التأكد إن الدورين مسموح
  /// لهم يتواصلوا قبل ما يستدعي الدالة دي.
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  });

  /// `sendChatMessage` — sender, timestamp, preview and unread counters are
  /// server-written. Retrying with the same [messageId] is idempotent.
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
  });

  /// Starts uploading [draft] to the message's own Storage folder.
  Future<Either<Failure, ChatUploadTask>> startAttachmentUpload({
    required String conversationId,
    required String messageId,
    required String uploaderId,
    required ChatAttachmentDraft draft,
  });

  /// Best-effort removal of an upload that never became a message.
  Future<Either<Failure, Unit>> discardUpload(String storagePath);

  /// Rules-checked download (no public URL is minted or cached).
  Future<Either<Failure, Uint8List>> downloadMedia(ChatMediaEntity media);

  /// تصفير عداد الرسائل غير المقروءة للمستخدم الحالي في المحادثة دي
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String uid,
  });

  Future<Either<Failure, ChatParticipantEntity>> getParticipant(String uid);

  /// C9 soft-delete via server callable.
  Future<Either<Failure, Unit>> softDeleteMessage({
    required String conversationId,
    required String messageId,
  });

  /// C9 edit own message via server callable.
  Future<Either<Failure, Unit>> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  });
}
