import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/chat_entities.dart';
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

  Future<void> softDeleteMessage({
    required String conversationId,
    required String messageId,
  });

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  });

  /// قراءة بيانات مستخدم من `users/{uid}` لبناء طرف محادثة
  Future<ChatParticipantModel> getParticipant(String uid);
}

@LazySingleton(as: ChatRemoteDatasource)
class ChatRemoteDatasourceImpl implements ChatRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const ChatRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
  });

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
      // WA-11 — relationship-checked create via CF (authoritative).
      final callable = functions.httpsCallable('createDirectConversation');
      final result = await callable.call(<String, dynamic>{
        'otherUid': otherUser.uid.trim(),
      });
      final data = result.data;
      if (data is! Map) {
        throw const ServerException('تعذر إنشاء المحادثة: رد غير متوقع');
      }
      final conversationId = data['conversationId']?.toString() ?? '';
      if (conversationId.isEmpty) {
        throw const ServerException('تعذر إنشاء المحادثة');
      }

      final doc = await _conversationsRef.doc(conversationId).get();
      if (doc.exists) {
        return ConversationModel.fromFirestore(doc, currentUid: currentUser.uid);
      }

      // Rare race: CF wrote but read missed — return local projection.
      return ConversationModel(
        id: conversationId,
        participants: [
          ChatParticipantModel.fromEntity(currentUser),
          ChatParticipantModel.fromEntity(otherUser),
        ],
        lastMessage: null,
        lastMessageAt: DateTime.now(),
        lastMessageSenderId: null,
        unreadCount: 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } on ServerException {
      rethrow;
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
      final conversationRef = _conversationsRef.doc(conversationId);
      final convSnap = await conversationRef.get();
      if (!convSnap.exists) {
        throw const ServerException('المحادثة غير موجودة');
      }
      final convData = convSnap.data() as Map<String, dynamic>? ?? {};
      final participantIds = (convData['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((id) => id.isNotEmpty)
          .toList();
      if (!participantIds.contains(senderId)) {
        throw const ServerException('لست مشاركاً في هذه المحادثة');
      }

      final batch = firestore.batch();
      final messageRef = _messagesRef(conversationId).doc();
      batch.set(messageRef, {
        'senderId': senderId,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'deleted': false,
      });

      final updates = <String, dynamic>{
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
      };

      // Increment unread for every other participant (1:1 and halaqa groups).
      for (final uid in participantIds) {
        if (uid == senderId) continue;
        updates['unreadCounts.$uid'] = FieldValue.increment(1);
      }

      batch.update(conversationRef, updates);
      await batch.commit();
    } on ServerException {
      rethrow;
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
  Future<void> softDeleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final callable = functions.httpsCallable('softDeleteChatMessage');
      await callable.call(<String, dynamic>{
        'conversationId': conversationId.trim(),
        'messageId': messageId.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) async {
    try {
      final callable = functions.httpsCallable('editChatMessage');
      await callable.call(<String, dynamic>{
        'conversationId': conversationId.trim(),
        'messageId': messageId.trim(),
        'text': text.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ChatParticipantModel> getParticipant(String uid) async {
    try {
      // Prefer users when phone-free; fall back to role profiles (WA-2 / D16).
      final userDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return ChatParticipantModel(
          uid: userDoc.id,
          name: data['name'] as String? ?? '',
          role: data['role'] as String? ?? '',
          profileImageUrl: data['profileImageUrl'] as String?,
        );
      }

      final studentDoc = await firestore
          .collection(FirestoreCollections.studentProfiles)
          .doc(uid)
          .get();
      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        return ChatParticipantModel(
          uid: studentDoc.id,
          name: data['name'] as String? ?? '',
          role: AppRoles.student,
          profileImageUrl: data['profileImageUrl'] as String?,
        );
      }

      final teacherDoc = await firestore
          .collection(FirestoreCollections.teacherProfiles)
          .doc(uid)
          .get();
      if (teacherDoc.exists) {
        final data = teacherDoc.data() as Map<String, dynamic>;
        return ChatParticipantModel(
          uid: teacherDoc.id,
          name: data['name'] as String? ?? '',
          role: AppRoles.teacher,
          profileImageUrl: data['profileImageUrl'] as String?,
        );
      }

      throw const ServerException('المستخدم غير موجود');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
