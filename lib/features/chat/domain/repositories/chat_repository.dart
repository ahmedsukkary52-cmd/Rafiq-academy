import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chat_entities.dart';

abstract class ChatRepository {
  /// Stream لقائمة كل محادثات المستخدم الحالي، مرتبة بآخر رسالة (الأحدث أولاً)
  Stream<Either<Failure, List<ConversationEntity>>> watchConversations(String uid);

  /// Admin oversight: all academy conversations without joining as participant.
  Stream<Either<Failure, List<ConversationEntity>>> watchAllConversations({
    required String observerUid,
  });

  /// Stream لرسائل محادثة معيّنة، بترتيب زمني تصاعدي
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(String conversationId);

  /// يجيب المحادثة لو موجودة، أو ينشئها لو دي أول رسالة بين الطرفين.
  /// الـ caller (الـ use case) هو المسؤول عن التأكد إن الدورين مسموح
  /// لهم يتواصلوا قبل ما يستدعي الدالة دي.
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  });

  /// إرسال رسالة في محادثة موجودة
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  });

  /// تصفير عداد الرسائل غير المقروءة للمستخدم الحالي في المحادثة دي
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String uid,
  });

  Future<Either<Failure, ChatParticipantEntity>> getParticipant(String uid);
}