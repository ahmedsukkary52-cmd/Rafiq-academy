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

  const ConversationEntity({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    required this.unreadCount,
  });

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

  bool hasUnread() => unreadCount > 0;

  @override
  List<Object?> get props => [
    id,
    participants,
    lastMessage,
    lastMessageAt,
    lastMessageSenderId,
    unreadCount,
  ];
}

class MessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  /// هل الرسالة دي مبعوتة من المستخدم الحالي؟ بيُستخدم في الـ UI عشان
  /// يحدد محاذاة فقاعة الرسالة (يمين/شمال).
  bool isMine(String currentUid) => senderId == currentUid;

  @override
  List<Object?> get props => [id, conversationId, senderId, text, sentAt];
}