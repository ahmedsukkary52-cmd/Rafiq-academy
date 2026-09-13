/// C8 / WA-10 — deterministic Halaqa group conversation identity.
///
/// Membership is a CF projection of halaqat.{teacherId,supervisorId,studentIds}.
/// Parent is never a member. Admin monitors without participant membership.
class HalaqaGroupChatContract {
  const HalaqaGroupChatContract._();

  static const String kind = 'halaqa_group';
  static const String idPrefix = 'halaqa_group_';

  static const String kindField = 'kind';
  static const String halaqaIdField = 'halaqaId';
  static const String participantIdsField = 'participantIds';
  static const String groupConversationIdField = 'groupConversationId';

  /// Deterministic conversation document id for [halaqaId].
  static String conversationIdForHalaqa(String halaqaId) {
    final id = halaqaId.trim();
    if (id.isEmpty) {
      throw ArgumentError('halaqaId is required for halaqa group conversation');
    }
    return '$idPrefix$id';
  }

  static bool isHalaqaGroupConversationId(String? conversationId) {
    final id = (conversationId ?? '').trim();
    return id.startsWith(idPrefix) && id.length > idPrefix.length;
  }
}
