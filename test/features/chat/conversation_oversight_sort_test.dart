import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';

/// Mirrors Admin oversight client-side sort in
/// [ChatRemoteDatasourceImpl.watchAllConversations].
List<ConversationEntity> sortConversationsForOversight(
  List<ConversationEntity> input,
) {
  final list = List<ConversationEntity>.from(input);
  list.sort((a, b) {
    final aAt = a.lastMessageAt;
    final bAt = b.lastMessageAt;
    if (aAt == null && bAt == null) return 0;
    if (aAt == null) return 1;
    if (bAt == null) return -1;
    return bAt.compareTo(aAt);
  });
  return list;
}

void main() {
  ConversationEntity conv({
    required String id,
    DateTime? at,
  }) {
    return ConversationEntity(
      id: id,
      participants: const [],
      lastMessageAt: at,
      unreadCount: 0,
    );
  }

  test('oversight sort puts null lastMessageAt last and newest first', () {
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 8, 1);
    final sorted = sortConversationsForOversight([
      conv(id: 'null', at: null),
      conv(id: 'old', at: older),
      conv(id: 'new', at: newer),
    ]);
    expect(sorted.map((c) => c.id).toList(), ['new', 'old', 'null']);
  });
}
