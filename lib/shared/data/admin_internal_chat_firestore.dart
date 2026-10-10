import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/exception.dart';
import '../../features/chat/data/models/chat_models.dart';

/// Admin-only internal group conversation — replaces standalone internal notes.
class AdminInternalChatFirestore {
  const AdminInternalChatFirestore._();

  static const String conversationId = 'admin_internal_group';
  static const String kindField = 'kind';
  static const String adminGroupKind = 'admin_group';

  /// Ensures the admin group conversation exists and includes all active admins.
  static Future<String> ensureConversation({
    required FirebaseFirestore firestore,
    required String currentAdminUid,
  }) async {
    final trimmedUid = currentAdminUid.trim();
    if (trimmedUid.isEmpty) {
      throw const ServerException('جلسة الإدارة غير صالحة');
    }

    final adminsSnap = await firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: AppRoles.admin)
        .where('isActive', isEqualTo: true)
        .get();

    final participants = <ChatParticipantModel>[];
    final participantIds = <String>[];
    for (final doc in adminsSnap.docs) {
      final data = doc.data();
      participantIds.add(doc.id);
      participants.add(
        ChatParticipantModel(
          uid: doc.id,
          name: data['name'] as String? ?? '',
          role: data['role'] as String? ?? AppRoles.admin,
          profileImageUrl: data['profileImageUrl'] as String?,
        ),
      );
    }

    if (!participantIds.contains(trimmedUid)) {
      final currentDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(trimmedUid)
          .get();
      if (currentDoc.exists) {
        final data = currentDoc.data() ?? const <String, dynamic>{};
        participantIds.add(trimmedUid);
        participants.add(
          ChatParticipantModel(
            uid: trimmedUid,
            name: data['name'] as String? ?? '',
            role: data['role'] as String? ?? AppRoles.admin,
            profileImageUrl: data['profileImageUrl'] as String?,
          ),
        );
      }
    }

    final unreadCounts = {
      for (final id in participantIds) id: 0,
    };

    final ref = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId);

    await ref.set({
      kindField: adminGroupKind,
      'participantIds': participantIds,
      'participants': participants.map((p) => p.toMap()).toList(),
      'title': 'مجموعة الإدارة',
      'lastMessage': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': null,
      'unreadCounts': unreadCounts,
    }, SetOptions(merge: true));

    return conversationId;
  }
}
