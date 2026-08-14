import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_permission_policy.dart';
import '../models/chat_models.dart';

abstract class ChatRemoteDatasource {
  Stream<List<ConversationModel>> watchConversations(String uid);

  Stream<List<MessageModel>> watchMessages(String conversationId);

  Future<ConversationModel> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  });

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  });

  Future<void> markConversationAsRead({
    required String conversationId,
    required String uid,
  });

  /// قراءة بيانات مستخدم من `users/{uid}` لبناء طرف محادثة
  Future<ChatParticipantModel> getParticipant(String uid);
}

@LazySingleton(as: ChatRemoteDatasource)
class ChatRemoteDatasourceImpl implements ChatRemoteDatasource {
  final FirebaseFirestore firestore;

  const ChatRemoteDatasourceImpl({required this.firestore});

  CollectionReference get _conversationsRef =>
      firestore.collection(FirestoreCollections.conversations);

  CollectionReference _messagesRef(String conversationId) => _conversationsRef
      .doc(conversationId)
      .collection(FirestoreCollections.messagesSubcollection);

  @override
  Stream<List<ConversationModel>> watchConversations(String uid) {
    return _conversationsRef
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ConversationModel.fromFirestore(doc, currentUid: uid),
              )
              .toList(),
        );
  }

  @override
  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _messagesRef(conversationId)
        .orderBy('sentAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MessageModel.fromFirestore(
                  doc,
                  conversationId: conversationId,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<ConversationModel> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  }) async {
    try {
      final conversationId = ConversationIdGenerator.generate(
        currentUser.uid,
        otherUser.uid,
      );

      final docRef = _conversationsRef.doc(conversationId);
      final existingDoc = await docRef.get();

      if (existingDoc.exists) {
        return ConversationModel.fromFirestore(
          existingDoc,
          currentUid: currentUser.uid,
        );
      }

      final participants = [
        ChatParticipantModel.fromEntity(currentUser),
        ChatParticipantModel.fromEntity(otherUser),
      ];

      await docRef.set({
        'participantIds': [currentUser.uid, otherUser.uid],
        'participants': participants.map((p) => p.toMap()).toList(),
        'lastMessage': null,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': null,
        'unreadCounts': {currentUser.uid: 0, otherUser.uid: 0},
      });

      // بنرجّع الموديل مباشرة من البيانات اللي إحنا أصلاً كاتبينها،
      // بدل ما نعمل قراءة تانية فوراً لنفس الـ document (توفير قراءة
      // واحدة من Firestore في كل أول محادثة).
      return ConversationModel(
        id: conversationId,
        participants: List<ChatParticipantEntity>.from(participants),
        lastMessage: null,
        lastMessageAt: DateTime.now(),
        lastMessageSenderId: null,
        unreadCount: 0,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      final otherUid = ConversationIdGenerator.otherParticipant(
        conversationId,
        senderId,
      );

      final batch = firestore.batch();

      final messageRef = _messagesRef(conversationId).doc();
      batch.set(messageRef, {
        'senderId': senderId,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
      });

      final conversationRef = _conversationsRef.doc(conversationId);
      batch.update(conversationRef, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        // بنزوّد عداد المستلم بس، مش المرسل، لأن المرسل أصلاً شايف رسالته
        'unreadCounts.$otherUid': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String uid,
  }) async {
    try {
      await _conversationsRef.doc(conversationId).update({
        'unreadCounts.$uid': 0,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ChatParticipantModel> getParticipant(String uid) async {
    try {
      final doc = await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();
      if (!doc.exists) {
        throw const ServerException('المستخدم غير موجود');
      }
      final data = doc.data() as Map<String, dynamic>;
      return ChatParticipantModel(
        uid: doc.id,
        name: data['name'] as String? ?? '',
        role: data['role'] as String? ?? '',
        profileImageUrl: data['profileImageUrl'] as String?,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
