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
    final image = map['profileImageUrl'];
    return ChatParticipantModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      profileImageUrl: image is String ? image : null,
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

  /// [currentUid] is required so we can extract this user's unread count from
  /// the per-uid `unreadCounts` map stored on the document.
  factory ConversationModel.fromFirestore(DocumentSnapshot doc, {
    required String currentUid,
  }) {
    final raw = doc.data();
    return ConversationModel.fromMap(
      doc.id,
      raw is Map<String, dynamic> ? raw : const <String, dynamic>{},
      currentUid: currentUid,
    );
  }

  factory ConversationModel.fromMap(String id,
      Map<String, dynamic> data, {
        required String currentUid,
      }) {
    final participants = <ChatParticipantEntity>[];
    final participantsRaw = data['participants'];
    if (participantsRaw is List) {
      for (final p in participantsRaw) {
        if (p is Map) {
          participants.add(
            ChatParticipantModel.fromMap(Map<String, dynamic>.from(p)),
          );
        }
      }
    }

    final unreadRaw = data['unreadCounts'];
    final unreadCounts = unreadRaw is Map
        ? Map<String, dynamic>.from(unreadRaw)
        : <String, dynamic>{};

    return ConversationModel(
      id: id,
      participants: participants,
      lastMessage: _stringFrom(data['lastMessage']),
      lastMessageAt: dateTimeFromFirestore(data['lastMessageAt']),
      lastMessageSenderId: _stringFrom(data['lastMessageSenderId']),
      unreadCount: intFromFirestore(unreadCounts[currentUid]),
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

  factory MessageModel.fromFirestore(DocumentSnapshot doc, {
    required String conversationId,
  }) {
    final raw = doc.data();
    return MessageModel.fromMap(
      doc.id,
      raw is Map<String, dynamic> ? raw : const <String, dynamic>{},
      conversationId: conversationId,
    );
  }

  factory MessageModel.fromMap(String id,
      Map<String, dynamic> data, {
        required String conversationId,
      }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      // Server timestamps are null on the local optimistic snapshot. Using
      // now() keeps the stream alive and shows the bubble immediately.
      sentAt: dateTimeFromFirestore(data['sentAt']) ?? DateTime.now(),
    );
  }
}

DateTime? dateTimeFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int intFromFirestore(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

String? _stringFrom(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}
