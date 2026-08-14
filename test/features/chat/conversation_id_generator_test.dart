import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_permission_policy.dart';

void main() {
  group('ConversationIdGenerator', () {
    test('is order-independent', () {
      expect(
        ConversationIdGenerator.generate('uidB', 'uidA'),
        ConversationIdGenerator.generate('uidA', 'uidB'),
      );
      expect(ConversationIdGenerator.generate('uidA', 'uidB'), 'uidA_uidB');
    });

    test('otherParticipant extracts the peer uid', () {
      const id = 'alice_bob';
      expect(ConversationIdGenerator.otherParticipant(id, 'alice'), 'bob');
      expect(ConversationIdGenerator.otherParticipant(id, 'bob'), 'alice');
    });

    test('otherParticipant falls back when known uid missing', () {
      expect(
        ConversationIdGenerator.otherParticipant('only_one', 'missing'),
        'only',
      );
    });
  });
}
