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
    super.kind,
    super.title,
    super.description,
    super.imagePath,
    super.groupAdminIds,
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
      kind: _nonEmpty(data['kind']) ?? ConversationKinds.direct,
      title: _nonEmpty(data['title']),
      description: _nonEmpty(data['description']),
      imagePath: _nonEmpty(data['imagePath']),
      groupAdminIds: data['groupAdminIds'] is List
          ? [
              for (final id in data['groupAdminIds'] as List)
                if (id is String) id,
            ]
          : const [],
    );
  }
}

String? _nonEmpty(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    super.type,
    required super.text,
    super.media,
    required super.sentAt,
    super.editedAt,
    super.deleted,
    super.deletedAt,
    super.deletedBy,
    super.replyTo,
    super.reactions,
    super.hasLink,
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
    final deleted = data['deleted'] == true;
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: data['senderId']?.toString() ?? '',
      type: ChatMessageType.fromWire(data['type']),
      text: data['text']?.toString() ?? '',
      media: deleted ? null : _mediaFrom(data['media']),
      // Server timestamps are null on the local optimistic snapshot. Using
      // now() keeps the stream alive and shows the bubble immediately.
      sentAt: dateTimeFromFirestore(data['sentAt']) ?? DateTime.now(),
      editedAt: dateTimeFromFirestore(data['editedAt']),
      deleted: deleted,
      deletedAt: dateTimeFromFirestore(data['deletedAt']),
      deletedBy: _stringFrom(data['deletedBy']),
      replyTo: _replyFrom(data['replyTo']),
      reactions: deleted ? const {} : _reactionsFrom(data['reactions']),
      hasLink: data['hasLink'] == true,
    );
  }

  static ChatReplyEntity? _replyFrom(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['messageId'];
    if (id is! String || id.isEmpty) return null;
    return ChatReplyEntity(
      messageId: id,
      senderId: raw['senderId']?.toString() ?? '',
      type: ChatMessageType.fromWire(raw['type']),
      preview: raw['preview']?.toString() ?? '',
    );
  }

  static Map<String, ChatReaction> _reactionsFrom(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, ChatReaction>{};
    raw.forEach((uid, value) {
      final r = ChatReaction.fromWire(value);
      if (uid is String && r != null) out[uid] = r;
    });
    return out;
  }

  static ChatMediaEntity? _mediaFrom(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['storagePath'];
    if (path is! String || path.isEmpty) return null;
    final duration = raw['durationMs'];
    return ChatMediaEntity(
      storagePath: path,
      fileName: raw['fileName']?.toString() ?? path.split('/').last,
      contentType: raw['contentType']?.toString() ?? '',
      sizeBytes: intFromFirestore(raw['sizeBytes']),
      durationMs: duration is num ? duration.toInt() : null,
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
