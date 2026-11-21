import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/error/user_facing_error.dart';
import '../../../../shared/domain/halaqa_group_chat_contract.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_models.dart';

abstract class ChatRemoteDatasource {
  Stream<List<ConversationModel>> watchConversations(String uid, {int? limit});

  /// Academy-wide conversation stream for Admin oversight (no participant filter).
  /// Does not add the Admin to [participantIds].
  Stream<List<ConversationModel>> watchAllConversations({
    required String observerUid,
    int? limit,
  });

  Future<List<ConversationModel>> fetchConversationsAfter({
    String? participantUid,
    required String viewerUid,
    required String afterConversationId,
    required int limit,
  });

  /// Newest [limit] messages, returned in ascending time order.
  Stream<List<MessageModel>> watchMessages(
    String conversationId, {
    required int limit,
  });

  /// One page of messages older than [beforeMessageId], ascending by `sentAt`
  /// then document id. Uses a document cursor so the live listener limit stays
  /// fixed (BASMA-103).
  Future<List<MessageModel>> fetchMessagesBefore({
    required String conversationId,
    required String beforeMessageId,
    required int limit,
  });

  /// One-shot gets for known message ids (buffer revalidation outside the live
  /// window). Missing docs are omitted from the result.
  Future<List<MessageModel>> fetchMessagesByIds({
    required String conversationId,
    required List<String> messageIds,
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
    String? replyToMessageId,
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
  Stream<List<ConversationModel>> watchConversations(String uid, {int? limit}) {
    Query query = _conversationsRef
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc, currentUid: uid))
          .toList(),
    );
  }

  @override
  Future<List<ConversationModel>> fetchConversationsAfter({
    String? participantUid,
    required String viewerUid,
    required String afterConversationId,
    required int limit,
  }) async {
    try {
      final cursor = await _conversationsRef.doc(afterConversationId).get();
      if (!cursor.exists) return const [];
      Query query = _conversationsRef;
      if (participantUid != null) {
        query = query.where('participantIds', arrayContains: participantUid);
      }
      final page = await query
          .orderBy('lastMessageAt', descending: true)
          .startAfterDocument(cursor)
          .limit(limit)
          .get();
      return page.docs
          .map((d) => ConversationModel.fromFirestore(d, currentUid: viewerUid))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'تعذر تحميل المزيد من المحادثات');
    }
  }

  @override
  Stream<List<ConversationModel>> watchAllConversations({
    required String observerUid,
    int? limit,
  }) {
    // Always bound (BASMA-104 / D2). Null limit defaults to the same window
    // as role inboxes; older threads use fetchConversationsAfter.
    final page = limit ?? 40;
    return _conversationsRef
        .orderBy('lastMessageAt', descending: true)
        .limit(page)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ConversationModel.fromFirestore(
                  doc,
                  currentUid: observerUid,
                ),
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
        .handleError(
          (error, _) => throw ServerException(
            _messagesStreamError(error, conversationId),
          ),
        )
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
  Future<List<MessageModel>> fetchMessagesBefore({
    required String conversationId,
    required String beforeMessageId,
    required int limit,
  }) async {
    if (limit <= 0) return const [];
    try {
      final cursor = await _messagesRef(
        conversationId,
      ).doc(beforeMessageId).get();
      if (!cursor.exists) return const [];

      final snapshot = await _messagesRef(conversationId)
          .orderBy('sentAt', descending: true)
          .startAfterDocument(cursor)
          .limit(limit)
          .get();

      return snapshot.docs.reversed
          .map(
            (doc) =>
                MessageModel.fromFirestore(doc, conversationId: conversationId),
          )
          .toList();
    } on FirebaseException catch (error) {
      throw ServerException(_messagesStreamError(error, conversationId));
    } catch (e) {
      throw ServerException(userFacingErrorText(e.toString()));
    }
  }

  @override
  Future<List<MessageModel>> fetchMessagesByIds({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    final unique = <String>{
      for (final id in messageIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
    if (unique.isEmpty) return const [];
    try {
      final col = _messagesRef(conversationId);
      final snaps = await Future.wait(unique.map((id) => col.doc(id).get()));
      final out = <MessageModel>[];
      for (final snap in snaps) {
        if (!snap.exists) continue;
        out.add(
          MessageModel.fromFirestore(snap, conversationId: conversationId),
        );
      }
      return out;
    } on FirebaseException catch (error) {
      throw ServerException(_messagesStreamError(error, conversationId));
    } catch (e) {
      throw ServerException(userFacingErrorText(e.toString()));
    }
  }

  static String _messagesStreamError(Object error, String conversationId) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return _halaqaGroupAccessDenied(conversationId) ??
            'لم يعد لديك وصول إلى هذه المحادثة';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'تعذر تحميل الرسائل. تحقق من الاتصال.';
      }
      final msg = error.message?.trim() ?? '';
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) return msg;
    }
    return 'تعذر تحميل الرسائل. تحقق من الاتصال.';
  }

  static String? _halaqaGroupAccessDenied(String conversationId) {
    if (!HalaqaGroupChatContract.isHalaqaGroupConversationId(conversationId)) {
      return null;
    }
    return 'لست عضواً في مجموعة هذه الحلقة. تأكد من إسنادك كمشرف للحلقة؛ تتم مزامنة الأعضاء تلقائياً عند تحديث بيانات الحلقة.';
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
      final data = _callableMap(result.data);
      if (data == null) {
        throw const ServerException('تعذر إنشاء المحادثة: رد غير متوقع');
      }
      final conversationId = data['conversationId']?.toString().trim() ?? '';
      if (conversationId.isEmpty) {
        throw const ServerException('تعذر إنشاء المحادثة');
      }

      final doc = await _conversationsRef.doc(conversationId).get();
      if (doc.exists) {
        return ConversationModel.fromFirestore(
          doc,
          currentUid: currentUser.uid,
        );
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
      throw ServerException(
        _callableMessage(e, 'تعذر إنشاء المحادثة. تحقق من الاتصال.'),
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(userFacingErrorText(e.toString()));
    }
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
    String? replyToMessageId,
  }) async {
    try {
      final callable = functions.httpsCallable('sendChatMessage');
      await callable.call(<String, dynamic>{
        'conversationId': conversationId.trim(),
        'messageId': messageId,
        'type': type.name,
        if (text.trim().isNotEmpty) 'text': text.trim(),
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (media != null)
          'media': <String, dynamic>{
            'storagePath': media.storagePath,
            'fileName': media.fileName,
            if (media.durationMs != null) 'durationMs': media.durationMs,
          },
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(_sendMessageError(e, conversationId));
    } catch (e) {
      throw const ServerException('تعذر إرسال الرسالة. تحقق من الاتصال.');
    }
  }

  static String _sendMessageError(
    FirebaseFunctionsException e,
    String conversationId,
  ) {
    if (e.code == 'permission-denied') {
      final groupDenied = _halaqaGroupAccessDenied(conversationId);
      if (groupDenied != null) return groupDenied;
    }
    return _callableMessage(e, 'تعذر إرسال الرسالة');
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
    final task = storage
        .ref(path)
        .putFile(
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

  static String _callableMessage(
    FirebaseFunctionsException e,
    String fallback,
  ) {
    final message = e.message?.trim() ?? '';
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(message);
    if (isArabic) return message;
    return switch (e.code) {
      'unavailable' || 'deadline-exceeded' => '$fallback. تحقق من الاتصال.',
      'permission-denied' => 'غير مسموح بهذا الإجراء في هذه المحادثة',
      'not-found' => 'خدمة المحادثة غير متاحة حالياً',
      'failed-precondition' => message.isNotEmpty ? message : fallback,
      _ => fallback,
    };
  }

  /// Firebase callables often return `Map<Object?, Object?>` — normalize keys.
  static Map<String, dynamic>? _callableMap(Object? raw) {
    if (raw is! Map) return null;
    return <String, dynamic>{
      for (final e in raw.entries) e.key.toString(): e.value,
    };
  }

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String uid,
  }) async {
    try {
      final conversationRef = _conversationsRef.doc(conversationId);
      final snap = await conversationRef.get();
      final data = snap.data() as Map<String, dynamic>? ?? const {};
      final participantIds = List<String>.from(
        data['participantIds'] ?? const <String>[],
      );
      // Silent Admin oversight: never write unreadCounts for non-participants
      // (would leak observer presence into the conversation document).
      if (!participantIds.contains(uid)) return;

      await conversationRef.update({'unreadCounts.$uid': 0});
    } catch (e) {
      throw ServerException(userFacingErrorText('$e'));
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
      // Prefer users when phone-free; fall back to studentProfiles (WA-2 /
      // D16). teacherProfiles is HR data, readable by Admin and self only.
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

      throw const ServerException('المستخدم غير موجود');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(userFacingErrorText('$e'));
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
