import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';
import '../../accounts/data/academy_accounts_repository.dart';
import '../domain/entities/chat_entities.dart';
import 'models/chat_models.dart';

/// Person found by the "new conversation / add member" search.
class ChatPersonHit {
  final String uid;
  final String name;
  final String role;

  const ChatPersonHit({
    required this.uid,
    required this.name,
    required this.role,
  });

  ChatParticipantEntity toParticipant() =>
      ChatParticipantEntity(uid: uid, name: name, role: role);
}

/// Group info tabs; each lists messages by reference (no file copies).
enum ChatGroupLibraryTab { media, documents, links }

/// One page of a group-info tab.
class ChatLibraryPage {
  final List<MessageModel> items;
  final DocumentSnapshot? cursor;
  final bool hasMore;

  const ChatLibraryPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

/// Admin-managed groups, reactions and people search. Every write is a
/// trusted callable (`functions/src/chat/chatGroupFunctions.ts`); reads are
/// rules-checked against `participantIds`, so removed members lose access.
class ChatGroupsRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseStorage storage;

  /// People search reuses the accounts member-prefix query (same indexes).
  final AcademyAccountsRepository accounts;

  static const libraryPageSize = 30;
  static const groupImageMaxBytes = 10 * 1024 * 1024;

  /// Roles reachable through search; students are never discoverable.
  static const searchableRoles = [
    AppRoles.teacher,
    AppRoles.supervisor,
    AppRoles.parent,
    AppRoles.admin,
  ];

  const ChatGroupsRepository({
    required this.firestore,
    required this.functions,
    required this.storage,
    required this.accounts,
  });

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
    String fallback,
  ) async {
    try {
      final result = await functions.httpsCallable(name).call(payload);
      final data = result.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim() ?? '';
      throw ServerException(
        RegExp(r'[\u0600-\u06FF]').hasMatch(message) ? message : fallback,
      );
    } catch (_) {
      throw ServerException('$fallback. تحقق من الاتصال.');
    }
  }

  Stream<ConversationModel?> watchConversation(
    String conversationId, {
    required String viewerUid,
  }) {
    return firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .snapshots()
        .map(
          (doc) => doc.exists
              ? ConversationModel.fromFirestore(doc, currentUid: viewerUid)
              : null,
        );
  }

  static const groupsLimit = 200;

  /// Groups [uid] belongs to, newest activity first (groups without messages
  /// yet are included). Rules only return conversations [uid] is in.
  Future<List<ConversationModel>> myGroups(String uid) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.conversations)
          .where('participantIds', arrayContains: uid)
          .where(
            'kind',
            whereIn: [ConversationKinds.halaqaGroup, ConversationKinds.customGroup],
          )
          .limit(groupsLimit)
          .get();
      final groups = [
        for (final doc in snap.docs)
          ConversationModel.fromFirestore(doc, currentUid: uid),
      ];
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      groups.sort(
        (a, b) => (b.lastMessageAt ?? epoch).compareTo(a.lastMessageAt ?? epoch),
      );
      return groups;
    } catch (_) {
      throw const ServerException('تعذر تحميل المجموعات. تحقق من الاتصال.');
    }
  }

  /// Bounded normalized prefix search per role (one query each, no N+1).
  Future<List<ChatPersonHit>> searchPeople(
    String query, {
    required String excludeUid,
    List<String> roles = searchableRoles,
  }) async {
    try {
      final perRole = await Future.wait([
        for (final role in roles)
          accounts
              .searchMembers(role: role, query: query)
              .then(
                (hits) => [
                  for (final h in hits)
                    ChatPersonHit(uid: h.uid, name: h.name, role: role),
                ],
              ),
      ]);
      return [
        for (final list in perRole)
          for (final hit in list)
            if (hit.uid != excludeUid) hit,
      ];
    } on FirebaseException {
      throw const ServerException('تعذر البحث الآن، أعد المحاولة');
    }
  }

  Future<String> createGroup({
    required String requestId,
    required String title,
    required String description,
    required List<String> memberIds,
  }) async {
    final data = await _call('adminCreateChatGroup', {
      'requestId': requestId,
      'title': title.trim(),
      'description': description.trim(),
      'memberIds': memberIds,
    }, 'تعذر إنشاء المجموعة');
    final id = '${data['conversationId'] ?? ''}';
    if (id.isEmpty) throw const ServerException('تعذر إنشاء المجموعة');
    return id;
  }

  Future<void> updateGroup({
    required String conversationId,
    String? title,
    String? description,
    String? imagePath,
  }) async {
    await _call('adminUpdateChatGroup', {
      'conversationId': conversationId,
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (imagePath != null) 'imagePath': imagePath,
    }, 'تعذر تحديث المجموعة');
  }

  Future<void> setMembers({
    required String conversationId,
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    await _call('adminSetChatGroupMembers', {
      'conversationId': conversationId,
      'add': add,
      'remove': remove,
    }, 'تعذر تحديث الأعضاء');
  }

  /// [reaction] null removes the caller's reaction.
  Future<void> react({
    required String conversationId,
    required String messageId,
    ChatReaction? reaction,
  }) async {
    await _call('reactToChatMessage', {
      'conversationId': conversationId,
      'messageId': messageId,
      'reaction': reaction?.name,
    }, 'تعذر إرسال التفاعل');
  }

  /// Uploads a new group image (Admin only by Storage rules) and points the
  /// group at it.
  Future<void> uploadGroupImage({
    required String conversationId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => throw const ServerException('اختر صورة JPG أو PNG أو WEBP'),
    };
    if (bytes.length > groupImageMaxBytes) {
      throw const ServerException('حجم الصورة أكبر من 10 ميجابايت');
    }
    final path =
        'chat_group_images/$conversationId/cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await storage
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: contentType));
    } on FirebaseException {
      throw const ServerException('تعذر رفع صورة المجموعة');
    }
    await updateGroup(conversationId: conversationId, imagePath: path);
  }

  Future<Uint8List?> groupImageBytes(String imagePath) async {
    try {
      return await storage.ref(imagePath).getData(groupImageMaxBytes);
    } on FirebaseException {
      return null;
    }
  }

  /// Newest-first page of a group-info tab, cursor-paged.
  Future<ChatLibraryPage> libraryPage(
    String conversationId,
    ChatGroupLibraryTab tab, {
    DocumentSnapshot? after,
  }) async {
    Query query = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.messagesSubcollection);
    query = switch (tab) {
      ChatGroupLibraryTab.media => query.where('type', isEqualTo: 'image'),
      ChatGroupLibraryTab.documents => query.where('type', isEqualTo: 'file'),
      ChatGroupLibraryTab.links => query.where('hasLink', isEqualTo: true),
    };
    query = query.orderBy('sentAt', descending: true);
    if (after != null) query = query.startAfterDocument(after);
    try {
      final snap = await query.limit(libraryPageSize).get();
      final items = [
        for (final d in snap.docs)
          MessageModel.fromFirestore(d, conversationId: conversationId),
      ].where((m) => !m.deleted).toList();
      return ChatLibraryPage(
        items: items,
        cursor: snap.docs.isEmpty ? after : snap.docs.last,
        hasMore: snap.docs.length >= libraryPageSize,
      );
    } on FirebaseException catch (e) {
      throw ServerException(
        e.code == 'permission-denied'
            ? 'لم يعد لديك وصول إلى هذه المجموعة'
            : 'تعذر تحميل المحتوى',
      );
    }
  }
}
