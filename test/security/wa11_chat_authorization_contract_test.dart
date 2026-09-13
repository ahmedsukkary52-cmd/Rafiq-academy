import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/shared/domain/halaqa_group_chat_contract.dart';

void main() {
  group('WA-11 message soft-delete contract', () {
    test('deleted message remains structurally present with metadata', () {
      final msg = MessageEntity(
        id: 'm1',
        conversationId: 'a_b',
        senderId: 'a',
        text: '',
        sentAt: DateTime(2026, 9, 13, 10),
        deleted: true,
        deletedAt: DateTime(2026, 9, 13, 11),
        deletedBy: 'a',
      );
      expect(msg.deleted, isTrue);
      expect(msg.deletedBy, 'a');
      expect(msg.deletedAt, isNotNull);
      expect(msg.isEdited, isFalse);
    });

    test('edited message records editedAt without changing sender', () {
      final msg = MessageEntity(
        id: 'm1',
        conversationId: 'a_b',
        senderId: 'a',
        text: 'updated',
        sentAt: DateTime(2026, 9, 13, 10),
        editedAt: DateTime(2026, 9, 13, 10, 5),
      );
      expect(msg.senderId, 'a');
      expect(msg.isEdited, isTrue);
      expect(msg.deleted, isFalse);
    });
  });

  group('WA-11 / WA-10 group identity compatibility', () {
    test('halaqa group id remains deterministic', () {
      expect(
        HalaqaGroupChatContract.conversationIdForHalaqa('h1'),
        'halaqa_group_h1',
      );
      expect(
        HalaqaGroupChatContract.isHalaqaGroupConversationId('halaqa_group_h1'),
        isTrue,
      );
    });
  });
}
