import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';

void main() {
  group('ConversationEntity admin oversight helpers', () {
    const a = ChatParticipantEntity(
      uid: 'a',
      name: 'أحمد',
      role: 'teacher',
    );
    const b = ChatParticipantEntity(
      uid: 'b',
      name: 'سارة',
      role: 'parent',
    );

    test('displayTitleForObserver shows both names when not participant', () {
      const conv = ConversationEntity(
        id: 'a_b',
        participants: [a, b],
        unreadCount: 0,
      );
      expect(conv.displayTitleForObserver('admin1'), 'أحمد · سارة');
      expect(conv.includesParticipant('admin1'), isFalse);
    });

    test('displayTitleForObserver uses otherParticipant when member', () {
      const conv = ConversationEntity(
        id: 'a_b',
        participants: [a, b],
        unreadCount: 0,
      );
      expect(conv.displayTitleForObserver('a'), 'سارة');
      expect(conv.includesParticipant('a'), isTrue);
    });
  });
}
