import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/chat_entities.dart';

class ChatParticipantModel extends ChatParticipantEntity {
  const ChatParticipantModel({
    required super.uid,
    required super.name,
    required super.role,
    super.profileImageUrl,
  });

  factory ChatParticipantModel.fromMap(Map<String, dynamic> map) {
    return ChatParticipantModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      profileImageUrl: map['profileImageUrl'] as String?,
    );
  }

  factory ChatParticipantModel.fromEntity(ChatParticipantEntity entity) {
    return ChatParticipantModel(
      uid: entity.uid,
      name: entity.name,
      role: entity.role,
      profileImageUrl: entity.profileImageUrl,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'role': role,
    if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
  };
}

class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.participants,
    super.lastMessage,
    super.lastMessageAt,
    super.lastMessageSenderId,
    required super.unreadCount,
  });

  /// محتاجين الـ [currentUid] هنا عشان نستخرج العدد الصح من map
  /// الـ unreadCounts المخزّن في المستند، اللي بيحتوي على عدد كل
  /// مستخدم على حدة، مش رقم واحد عام للمحادثة.
  factory ConversationModel.fromFirestore(
      DocumentSnapshot doc, {
        required String currentUid,
      }) {
    final data = doc.data() as Map<String, dynamic>;

    final participantsRaw = data['participants'] as List<dynamic>? ?? [];
    final participants = participantsRaw
        .map((p) => ChatParticipantModel.fromMap(p as Map<String, dynamic>))
        .toList();

    final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});

    return ConversationModel(
      id: doc.id,
      participants: participants,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      unreadCount: (unreadCounts[currentUid] ?? 0) as int,
    );
  }
}

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.text,
    required super.sentAt,
  });

  factory MessageModel.fromFirestore(
      DocumentSnapshot doc, {
        required String conversationId,
      }) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      conversationId: conversationId,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      sentAt: (data['sentAt'] as Timestamp).toDate(),
    );
  }
}