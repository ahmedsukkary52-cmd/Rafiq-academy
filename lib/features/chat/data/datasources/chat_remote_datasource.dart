import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_models.dart';

abstract class ChatRemoteDatasource {
  Stream<List<ConversationModel>> watchConversations(String uid);

  /// Newest [limit] messages, returned in ascending time order.
  Stream<List<MessageModel>> watchMessages(
    String conversationId, {
    required int limit,
  });

  Future<ConversationModel> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  });

  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
  });

  ChatUploadTask startAttachmentUpload({
    required String conversationId,
    required String messageId,
    required String uploaderId,
    required ChatAttachmentDraft draft,
  });

  Future<void> deleteUpload(String storagePath);

  Future<Uint8List> downloadMedia(ChatMediaEntity media);

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
  final FirebaseStorage storage;

  const ChatRemoteDatasourceImpl({
    required this.firestore,
    required this.functions,
    required this.storage,
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
  Stream<List<MessageModel>> watchMessages(
    String conversationId, {
    required int limit,
  }) {
    return _messagesRef(conversationId)
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.reversed
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
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
  }) async {
    try {
      final callable = functions.httpsCallable('sendChatMessage');
      await callable.call(<String, dynamic>{
        'conversationId': conversationId.trim(),
        'messageId': messageId,
        'type': type.name,
        if (text.trim().isNotEmpty) 'text': text.trim(),
        if (media != null)
          'media': <String, dynamic>{
            'storagePath': media.storagePath,
            'fileName': media.fileName,
            if (media.durationMs != null) 'durationMs': media.durationMs,
          },
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(_callableMessage(e, 'تعذر إرسال الرسالة'));
    } catch (e) {
      throw const ServerException('تعذر إرسال الرسالة. تحقق من الاتصال.');
    }
  }

  @override
  ChatUploadTask startAttachmentUpload({
    required String conversationId,
    required String messageId,
    required String uploaderId,
    required ChatAttachmentDraft draft,
  }) {
    final path = ChatMediaPolicy.storagePath(
      conversationId: conversationId,
      messageId: messageId,
      draft: draft,
    );
    final task = storage.ref(path).putFile(
      File(draft.localPath),
      SettableMetadata(
        contentType: draft.contentType,
        customMetadata: {'uploaderId': uploaderId},
      ),
    );
    return _FirebaseChatUploadTask(task, path);
  }

  @override
  Future<void> deleteUpload(String storagePath) async {
    try {
      await storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<Uint8List> downloadMedia(ChatMediaEntity media) async {
    try {
      final limit = media.sizeBytes > 0
          ? media.sizeBytes + 1024
          : ChatMediaPolicy.voiceMaxBytes;
      final bytes = await storage.ref(media.storagePath).getData(limit);
      if (bytes == null) {
        throw const ServerException('الملف غير متاح');
      }
      return bytes;
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'object-not-found') {
        throw const ServerException('الملف لم يعد متاحاً');
      }
      throw const ServerException('تعذر تحميل الملف. تحقق من الاتصال.');
    }
  }

  static String _callableMessage(FirebaseFunctionsException e, String fallback) {
    final message = e.message?.trim() ?? '';
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(message);
    if (isArabic) return message;
    return switch (e.code) {
      'unavailable' || 'deadline-exceeded' => '$fallback. تحقق من الاتصال.',
      'permission-denied' => 'غير مسموح بهذا الإجراء في هذه المحادثة',
      _ => fallback,
    };
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
      throw ServerException(_callableMessage(e, 'تعذر حذف الرسالة'));
    } catch (e) {
      throw const ServerException('تعذر حذف الرسالة. تحقق من الاتصال.');
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
      throw ServerException(_callableMessage(e, 'تعذر تعديل الرسالة'));
    } catch (e) {
      throw const ServerException('تعذر تعديل الرسالة. تحقق من الاتصال.');
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

class _FirebaseChatUploadTask implements ChatUploadTask {
  final UploadTask _task;

  @override
  final String storagePath;

  _FirebaseChatUploadTask(this._task, this.storagePath);

  @override
  Stream<double> get progress => _task.snapshotEvents.map(
    (s) => s.totalBytes <= 0 ? 0.0 : s.bytesTransferred / s.totalBytes,
  );

  @override
  Future<void> get completion async {
    try {
      await _task;
    } on FirebaseException catch (e) {
      if (e.code == 'canceled') {
        throw const ServerException('تم إلغاء الرفع');
      }
      if (e.code == 'unauthorized') {
        throw const ServerException('غير مسموح برفع هذا الملف في المحادثة');
      }
      throw const ServerException('تعذر رفع الملف. تحقق من الاتصال.');
    }
  }

  @override
  Future<void> cancel() async {
    await _task.cancel();
  }
}
