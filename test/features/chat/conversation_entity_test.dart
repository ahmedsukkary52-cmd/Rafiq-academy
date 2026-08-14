import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';

void main() {
  group('ConversationEntity.otherParticipant', () {
    const teacher = ChatParticipantEntity(
      uid: 't1',
      name: 'معلم',
      role: 'teacher',
    );
    const student = ChatParticipantEntity(
      uid: 's1',
      name: 'طالب',
      role: 'student',
    );

    test('returns the peer that is not the current uid', () {
      const conv = ConversationEntity(
        id: 'c1',
        participants: [teacher, student],
        unreadCount: 0,
      );
      expect(conv.otherParticipant('t1'), student);
      expect(conv.otherParticipant('s1'), teacher);
    });

    test('empty participants does not throw', () {
      const conv = ConversationEntity(
        id: 'c1',
        participants: [],
        unreadCount: 0,
      );
      expect(conv.otherParticipant('t1').name, 'محادثة');
    });
  });

  group('MessageEntity.isMine', () {
    test('is true only for the sender uid', () {
      final message = MessageEntity(
        id: 'm1',
        conversationId: 'c1',
        senderId: 't1',
        text: 'hi',
        sentAt: DateTime(2026, 1, 1),
      );
      expect(message.isMine('t1'), isTrue);
      expect(message.isMine('s1'), isFalse);
    });
  });
}
