import 'package:equatable/equatable.dart';

/// بيانات مختصرة عن أحد طرفي المحادثة (denormalized داخل document
/// المحادثة نفسها، عشان نعرض الاسم والدور من غير ما نعمل قراءة إضافية
/// لـ collection الـ users في كل مرة نفتح فيها قائمة المحادثات).
class ChatParticipantEntity extends Equatable {
  final String uid;
  final String name;
  final String role;
  final String? profileImageUrl;

  const ChatParticipantEntity({
    required this.uid,
    required this.name,
    required this.role,
    this.profileImageUrl,
  });

  @override
  List<Object?> get props => [uid, name, role, profileImageUrl];
}

/// Server-written `conversations.kind` values.
abstract final class ConversationKinds {
  static const direct = 'direct';
  static const halaqaGroup = 'halaqa_group';
  static const customGroup = 'custom_group';

  /// Active Admins only; membership is synced by the backend, never edited.
  static const adminGroup = 'admin_group';
}

class ConversationEntity extends Equatable {
  final String id;
  final List<ChatParticipantEntity> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;

  /// عدد الرسائل غير المقروءة **للمستخدم الحالي تحديداً** في المحادثة دي.
  /// الـ Repository هو المسؤول عن استخراج الرقم الصح حسب uid المستخدم
  /// الحالي من الـ map المخزّن في Firestore، عشان الـ Entity تفضل بسيطة
  /// ومالهاش علاقة بمين هو "المستخدم الحالي".
  final int unreadCount;

  /// [ConversationKinds]; legacy 1:1 documents carry no kind.
  final String kind;
  final String? title;
  final String? description;

  /// Storage path under `chat_group_images/` (rules-checked, never a URL).
  final String? imagePath;
  final List<String> groupAdminIds;

  const ConversationEntity({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    required this.unreadCount,
    this.kind = ConversationKinds.direct,
    this.title,
    this.description,
    this.imagePath,
    this.groupAdminIds = const [],
  });

  bool get isGroup =>
      kind == ConversationKinds.halaqaGroup ||
      kind == ConversationKinds.customGroup ||
      kind == ConversationKinds.adminGroup;

  /// Admin-managed group (members, name, image editable by Admin).
  bool get isCustomGroup => kind == ConversationKinds.customGroup;

  /// Name shown in lists and the room header.
  String displayTitle(String viewerUid) {
    final t = title?.trim() ?? '';
    if (isGroup && t.isNotEmpty) return t;
    if (isGroup) return 'مجموعة';
    return displayTitleForObserver(viewerUid);
  }

  /// Display name of [uid] from the denormalized member list.
  String? participantName(String uid) {
    for (final p in participants) {
      if (p.uid == uid) return p.name.trim().isEmpty ? null : p.name;
    }
    return null;
  }

  /// الطرف التاني في المحادثة (مش أنا). مفيد جداً للـ UI عشان يعرض
  /// "بتكلم مين" من غير ما يدور بنفسه في الـ participants.
  ChatParticipantEntity otherParticipant(String currentUid) {
    // Do not use Iterable.firstWhere(orElse:): Firestore mapping stores
    // List<ChatParticipantModel>, and Dart list invariance makes
    // `() => ChatParticipantEntity` an invalid orElse (inbox crash).
    for (final p in participants) {
      if (p.uid != currentUid) return p;
    }
    if (participants.isEmpty) {
      return const ChatParticipantEntity(uid: '', name: 'محادثة', role: '');
    }
    return participants.first;
  }

  /// Title for Admin oversight when the viewer is not a participant.
  String displayTitleForObserver(String observerUid) {
    final groupTitle = title?.trim() ?? '';
    if (isGroup && groupTitle.isNotEmpty) return groupTitle;
    final isParticipant = participants.any((p) => p.uid == observerUid);
    if (isParticipant) return otherParticipant(observerUid).name;
    if (participants.length >= 2) {
      return '${participants[0].name} · ${participants[1].name}';
    }
    if (participants.length == 1) return participants.first.name;
    return 'محادثة';
  }

  bool includesParticipant(String uid) =>
      participants.any((p) => p.uid == uid);

  bool hasUnread() => unreadCount > 0;

  @override
  List<Object?> get props => [
    id,
    participants,
    lastMessage,
    lastMessageAt,
    lastMessageSenderId,
    unreadCount,
    kind,
    title,
    description,
    imagePath,
    groupAdminIds,
  ];
}

/// Reactions accepted by `reactToChatMessage`.
enum ChatReaction {
  like('👍'),
  heart('❤️'),
  laugh('😂'),
  sad('😢');

  final String emoji;
  const ChatReaction(this.emoji);

  static ChatReaction? fromWire(Object? raw) {
    for (final r in values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

/// Server-written quote of the message being replied to.
class ChatReplyEntity extends Equatable {
  final String messageId;
  final String senderId;
  final ChatMessageType type;
  final String preview;

  const ChatReplyEntity({
    required this.messageId,
    required this.senderId,
    required this.type,
    required this.preview,
  });

  @override
  List<Object?> get props => [messageId, senderId, type, preview];
}

enum ChatMessageType {
  text,
  image,
  voice,
  file;

  /// Wire value written by `sendChatMessage`. Legacy docs have no type.
  static ChatMessageType fromWire(Object? raw) {
    for (final t in values) {
      if (t.name == raw) return t;
    }
    return ChatMessageType.text;
  }
}

/// Server-verified media metadata (written by `sendChatMessage` only).
class ChatMediaEntity extends Equatable {
  final String storagePath;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final int? durationMs;

  const ChatMediaEntity({
    required this.storagePath,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.durationMs,
  });

  @override
  List<Object?> get props =>
      [storagePath, fileName, contentType, sizeBytes, durationMs];
}

class MessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final ChatMessageType type;
  final String text;
  final ChatMediaEntity? media;
  final DateTime sentAt;
  final DateTime? editedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final ChatReplyEntity? replyTo;

  /// uid → reaction (one per member).
  final Map<String, ChatReaction> reactions;
  final bool hasLink;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.type = ChatMessageType.text,
    required this.text,
    this.media,
    required this.sentAt,
    this.editedAt,
    this.deleted = false,
    this.deletedAt,
    this.deletedBy,
    this.replyTo,
    this.reactions = const {},
    this.hasLink = false,
  });

  /// Reaction counts in [ChatReaction] order, zero counts omitted.
  List<(ChatReaction, int)> get reactionSummary {
    if (reactions.isEmpty) return const [];
    return [
      for (final r in ChatReaction.values)
        if (reactions.values.where((v) => v == r).isNotEmpty)
          (r, reactions.values.where((v) => v == r).length),
    ];
  }

  /// هل الرسالة دي مبعوتة من المستخدم الحالي؟ بيُستخدم في الـ UI عشان
  /// يحدد محاذاة فقاعة الرسالة (يمين/شمال).
  bool isMine(String currentUid) => senderId == currentUid;

  bool get isEdited => editedAt != null && !deleted;

  /// Deleted messages never expose media, even if a stale doc still has it.
  ChatMediaEntity? get visibleMedia => deleted ? null : media;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    type,
    text,
    media,
    sentAt,
    editedAt,
    deleted,
    deletedAt,
    deletedBy,
    replyTo,
    reactions,
    hasLink,
  ];
}