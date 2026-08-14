import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/presentation/chat_message_alignment.dart';

void main() {
  group('ChatMessageAlignment', () {
    test('RTL: mine is start/right, incoming is end/left', () {
      expect(
        ChatMessageAlignment.bubbleAlignment(
          isMine: true,
        ).resolve(TextDirection.rtl),
        Alignment.centerRight,
      );
      expect(
        ChatMessageAlignment.bubbleAlignment(
          isMine: false,
        ).resolve(TextDirection.rtl),
        Alignment.centerLeft,
      );
    });

    test('timestamp column hugs the same side as the bubble', () {
      expect(
        ChatMessageAlignment.contentCrossAxis(isMine: true),
        CrossAxisAlignment.start,
      );
      expect(
        ChatMessageAlignment.contentCrossAxis(isMine: false),
        CrossAxisAlignment.end,
      );
    });

    test('RTL: mine tail is on the start/right corner', () {
      final mine = ChatMessageAlignment.bubbleBorderRadius(
        isMine: true,
      ).resolve(TextDirection.rtl);
      expect(mine.bottomRight, const Radius.circular(4));
      expect(mine.bottomLeft, const Radius.circular(18));

      final theirs = ChatMessageAlignment.bubbleBorderRadius(
        isMine: false,
      ).resolve(TextDirection.rtl);
      expect(theirs.bottomLeft, const Radius.circular(4));
      expect(theirs.bottomRight, const Radius.circular(18));
    });

    test('max width is 78% of the screen', () {
      expect(ChatMessageAlignment.maxBubbleWidth(100), 78);
    });
  });

  group('MessageEntity.isMine', () {
    final message = MessageEntity(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'teacher-1',
      text: 'مرحبا',
      sentAt: DateTime(2026, 8, 14),
    );

    test('is true only for the sender uid', () {
      expect(message.isMine('teacher-1'), isTrue);
      expect(message.isMine('student-1'), isFalse);
    });
  });
}
